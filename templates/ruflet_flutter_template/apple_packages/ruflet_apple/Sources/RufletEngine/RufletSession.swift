import Combine
import Foundation
import RufletProtocol

/// One connection to a Ruflet runtime.
///
/// The engine is a peer of the Flutter client, not a layer under it: it speaks
/// the same five actions over the same socket, so the Ruby application cannot
/// tell which renderer attached and needs no renderer-specific code.
@MainActor
public final class RufletSession: ObservableObject {
  public enum Status: Equatable {
    case idle
    case connecting
    case connected
    case disconnected
    /// The runtime reported an unhandled Ruby exception (`session_crashed`).
    case crashed(String)
    case failed(String)
  }

  @Published public private(set) var status: Status = .idle
  /// Lines the runtime wrote to stdout, forwarded as `python_output`.
  @Published public private(set) var runtimeOutput: [String] = []

  public let store: ControlStore
  public let services: ServiceRegistry
  /// Where mounted controls register their imperative methods.
  public let commands = ControlCommandBus()

  public private(set) var capabilities: ClientCapabilities
  public private(set) var sessionID: String = ""

  /// Called for events the renderer does not own, so a host can observe them.
  public var onEvent: ((_ target: Int, _ name: String) -> Void)?

  private let transport: RufletTransport
  private var reconnectAttempts = 0
  private let maxReconnectAttempts: Int
  private var isStopping = false

  public init(
    transport: RufletTransport,
    capabilities: ClientCapabilities = .current(),
    store: ControlStore = ControlStore(),
    maxReconnectAttempts: Int = 5
  ) {
    self.transport = transport
    self.capabilities = capabilities
    self.store = store
    self.services = ServiceRegistry()
    self.maxReconnectAttempts = maxReconnectAttempts
    transport.delegate = self

    services.registerDefaults()
  }

  /// What a service is allowed to reach back into. Built once so a streaming
  /// service registered at patch time can emit events immediately.
  private func makeServiceContext() -> RufletServiceContext {
    RufletServiceContext(store: store) { [weak self] target, name, data in
      Task { @MainActor in self?.dispatchEvent(target: target, name: name, data: data) }
    }
  }

  public convenience init(
    serverURL: URL,
    capabilities: ClientCapabilities = .current(),
    store: ControlStore = ControlStore()
  ) {
    self.init(transport: WebSocketTransport(url: serverURL), capabilities: capabilities, store: store)
  }

  // MARK: - Lifecycle

  public func start() {
    guard status == .idle || status == .disconnected else { return }
    isStopping = false
    status = .connecting
    transport.connect()
  }

  public func stop() {
    isStopping = true
    transport.disconnect()
    status = .disconnected
  }

  // MARK: - Outbound

  /// Reports a control event, the way the Flutter client does.
  ///
  /// `Page#dispatch_event` also writes the value back onto the control for
  /// `change`, `select` and `select_change`, so a plain scalar in `data` is
  /// enough to keep the Ruby-side model in step — no companion
  /// `update_control` is required.
  public func dispatchEvent(target: Int, name: String, data: RufletValue = .null) {
    send(
      .controlEvent,
      .map([
        "target": .int(Int64(target)),
        "name": .string(name),
        "data": data
      ]))
    onEvent?(target, name)
  }

  /// Pushes client-side property changes back without firing a handler, for
  /// state Ruby must know about but did not ask to be notified of (a dialog
  /// that dismissed itself, a scroll offset).
  public func updateControl(id: Int, props: [String: RufletValue]) {
    send(
      .updateControl,
      .map([
        "id": .int(Int64(id)),
        "props": .map(props)
      ]))
  }

  private func send(_ action: RufletAction, _ payload: RufletValue) {
    transport.send(RufletMessage(action: action, payload: payload).encoded())
  }

  // MARK: - Inbound

  private func handle(_ message: RufletMessage) {
    switch message.action {
    case .registerClient:
      handleRegisterAcknowledgement(message.payload)
    case .patchControl:
      handlePatch(message.payload)
    case .invokeControlMethod:
      handleMethodCall(message.payload)
    case .sessionCrashed:
      status = .crashed(message.payload["message"]?.stringValue ?? "Unknown runtime error")
    case .runtimeOutput:
      if let line = message.payload["output"]?.stringValue ?? message.payload.stringValue {
        runtimeOutput.append(line)
      }
    case .controlEvent, .updateControl:
      // Client-to-runtime actions; nothing sends these to us.
      break
    }
  }

  private func handleRegisterAcknowledgement(_ payload: RufletValue) {
    sessionID = payload["session_id"]?.stringValue ?? sessionID
    capabilities.sessionID = sessionID
    reconnectAttempts = 0
    status = .connected

    if let error = payload["error"]?.stringValue, !error.isEmpty {
      status = .failed(error)
      return
    }
    if let patch = payload["page_patch"]?.mapValue, !patch.isEmpty {
      store.applyPageProperties(patch)
    }
  }

  private func handlePatch(_ payload: RufletValue) {
    do {
      store.apply(try ControlPatch.decode(payload: payload))
      services.prune(liveIDs: Set(store.nodes.keys))
      services.activateStreamingServices(in: store, context: makeServiceContext())
    } catch {
      RufletLog.error("Discarded malformed patch: \(error)")
    }
  }

  private func handleMethodCall(_ payload: RufletValue) {
    guard let callID = payload["call_id"]?.stringValue else { return }
    let call = RufletMethodCall(
      controlID: payload["control_id"]?.intValue ?? RufletWireID.page,
      callID: callID,
      name: payload["name"]?.stringValue ?? "",
      args: payload["args"] ?? .null
    )

    guard let node = store.node(call.controlID) else {
      reply(callID: callID, result: .failure(RufletServiceError.unknownTarget(call.controlID)))
      return
    }

    // A mounted visual control gets first refusal because camera/video/canvas
    // methods need the live view model. Non-visual services then answer for
    // their whole type.
    let dispatched = commands.invoke(call) { [weak self] result in
      Task { @MainActor in self?.reply(callID: callID, result: result) }
    }
    guard !dispatched else { return }

    if let service = services.service(for: node) {
      service.invoke(call, node: node, context: makeServiceContext()) { [weak self] result in
        Task { @MainActor in self?.reply(callID: callID, result: result) }
      }
      return
    }

    // Naming the module turns "it failed" into "link RufletMedia", which is
    // the actual fix whenever an optional service is missing.
    if let bundle = ServiceRegistry.bundleProviding(node.type) {
      reply(
        callID: callID,
        result: .failure(RufletServiceError.moduleNotLinked(type: node.type, bundle: bundle)))
      return
    }
    reply(
      callID: callID,
      result: .failure(
        RufletServiceError.unsupportedMethod(type: node.type, method: call.name)))
  }

  private func reply(callID: String, result: Result<RufletValue, Error>) {
    var payload: [String: RufletValue] = ["call_id": .string(callID)]
    switch result {
    case .success(let value):
      payload["result"] = value
      // Ruby treats an empty String as truthy. Successful callbacks must
      // therefore carry nil, not "", or `if error` takes the failure path.
      payload["error"] = .null
    case .failure(let error):
      payload["result"] = .null
      payload["error"] = .string(error.localizedDescription)
    }
    send(.invokeControlMethod, .map(payload))
  }
}

// MARK: - Transport delegate

extension RufletSession: RufletTransportDelegate {
  nonisolated public func transportDidOpen(_ transport: RufletTransport) {
    Task { @MainActor in
      self.send(.registerClient, self.capabilities.registerPayload())
    }
  }

  nonisolated public func transport(_ transport: RufletTransport, didReceive data: Data) {
    do {
      let message = try RufletMessage.decode(data)
      Task { @MainActor in self.handle(message) }
    } catch {
      RufletLog.error("Discarded undecodable frame (\(data.count) bytes): \(error)")
    }
  }

  nonisolated public func transport(_ transport: RufletTransport, didCloseWith error: Error?) {
    Task { @MainActor in
      guard !self.isStopping else { return }
      if let error {
        self.status = .failed(error.localizedDescription)
      } else {
        self.status = .disconnected
      }
    }
  }
}
