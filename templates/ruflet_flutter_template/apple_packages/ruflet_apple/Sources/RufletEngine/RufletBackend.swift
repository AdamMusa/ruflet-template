import Combine
import CoreGraphics
import Foundation
import RufletProtocol

@MainActor
public final class RufletBackend: ObservableObject, RufletBackendProtocol {
  public static let defaultAppErrorMessageTemplate =
    "The application encountered an error: {message}\n\n{details}"

  public let pageURI: URL?
  public let assetsDirectory: String
  public let multiView: Bool
  public let showAppStartupScreen: Bool?
  public let appStartupScreenMessage: String?
  public let appErrorMessage: String?
  public let controlID: Int?
  public let forcePyodide: Bool?
  public let arguments: [String: RufletValue]
  public let extensionRegistry: RufletExtensionRegistry
  public let errorsHandler: RufletAppErrorsHandler?

  @Published public private(set) var route = ""
  @Published public private(set) var isLoading = true
  @Published public private(set) var error = ""
  @Published public private(set) var pageSize = CGSize.zero
  @Published public private(set) var platformBrightness = "light"
  @Published public private(set) var media = RufletPageMediaData(
    padding: .zero,
    viewPadding: .zero,
    viewInsets: .zero,
    devicePixelRatio: 0,
    orientation: .portrait,
    alwaysUse24HourFormat: false)

  public let sizeBreakpoints: [String: Double] = [
    "xs": 0, "sm": 576, "md": 768, "lg": 992, "xl": 1200, "xxl": 1400,
  ]
  public private(set) var page: RufletControl!

  private weak var parentBackend: RufletBackend?
  private let reconnectIntervalMilliseconds: Int?
  private let reconnectTimeoutMilliseconds: Int?
  private let channelFactory: RufletBackendChannelFactoryClosure
  private var controlsIndex: [Int: WeakControl] = [:]
  private var scrollTargets: [String: RufletScrollTarget] = [:]
  private var pageServiceBindings: PageServiceBindings?
  private var backendChannel: RufletBackendChannel?
  private var sendQueue: [RufletMessage] = []
  private var reconnectStartedUptime: TimeInterval?
  private var reconnectDelayMilliseconds = 0
  private var reconnectTask: Task<Void, Never>?
  private var disposed = false
  private var receivedFirstPageSize = false
  private var connectionInProgress = false
  private var pageListener: UUID?
  private var errorListener: AnyCancellable?

  public typealias RufletBackendChannelFactoryClosure =
    @MainActor (
      URL,
      @escaping () -> Void,
      @escaping (RufletMessage) -> Void
    ) throws -> RufletBackendChannel

  public init(
    pageURL: URL,
    assetsDirectory: String,
    multiView: Bool = false,
    reconnectIntervalMilliseconds: Int? = nil,
    reconnectTimeoutMilliseconds: Int? = nil,
    errorsHandler: RufletAppErrorsHandler? = nil,
    showAppStartupScreen: Bool? = nil,
    appStartupScreenMessage: String? = nil,
    appErrorMessage: String? = nil,
    controlID: Int? = nil,
    forcePyodide: Bool? = nil,
    arguments: [String: RufletValue] = [:],
    extensions: [any RufletExtension] = [],
    parentBackend: RufletBackend? = nil,
    channelFactory: @escaping RufletBackendChannelFactoryClosure = {
      try RufletBackendChannelFactory.make(address: $0, onDisconnect: $1, onMessage: $2)
    }
  ) {
    self.pageURI = pageURL
    self.assetsDirectory = assetsDirectory
    self.multiView = multiView
    self.reconnectIntervalMilliseconds = reconnectIntervalMilliseconds
    self.reconnectTimeoutMilliseconds = reconnectTimeoutMilliseconds
    self.errorsHandler = errorsHandler
    self.showAppStartupScreen = showAppStartupScreen
    self.appStartupScreenMessage = appStartupScreenMessage
    self.appErrorMessage = appErrorMessage
    self.controlID = controlID
    self.forcePyodide = forcePyodide
    self.arguments = arguments
    self.parentBackend = parentBackend
    self.channelFactory = channelFactory
    self.extensionRegistry = RufletExtensionRegistry(
      extensions + [RufletCoreExtension()])

    page = RufletControl(
      id: 1,
      type: "Page",
      properties: [
        "pwa": false,
        "web": false,
        "debug": false,
        "wasm": false,
        "test": false,
        "multi_view": .bool(multiView),
        "pyodide": false,
        "platform": .string(rufletApplePlatformName),
        "window": .map(["_c": "Window", "_i": 2]),
      ],
      backend: self)
    pageListener = page.addListener { [weak self] in self?.pageDidUpdate() }
    do {
      pageServiceBindings = try PageServiceBindings(page: page, backend: self)
    } catch {
      preconditionFailure("Failed to initialize Page services: \(error)")
    }
    pageDidUpdate()

    if let errorsHandler {
      errorListener = errorsHandler.$error.dropFirst().sink { [weak self] error in
        guard let self, let error else { return }
        if let controlID, let parentBackend {
          parentBackend.triggerControlEvent(
            controlID: controlID, name: "error", data: .string(error))
        } else {
          self.triggerControlEvent(self.page, name: "error", data: .string(error))
        }
      }
    }
  }

  deinit {
    reconnectTask?.cancel()
  }

  public func connect() async {
    guard let pageURI, !disposed, receivedFirstPageSize,
      backendChannel == nil, !connectionInProgress
    else { return }
    connectionInProgress = true
    defer { connectionInProgress = false }
    do {
      let onDisconnect: () -> Void = { [weak self] in
        guard let self else { return }
        self.didDisconnect()
      }
      let onMessage: (RufletMessage) -> Void = { [weak self] message in
        guard let self else { return }
        self.receive(message)
      }
      let channel = if forcePyodide == true {
        try RufletBackendChannelFactory.make(
          address: pageURI,
          forcePyodide: true,
          onDisconnect: onDisconnect,
          onMessage: onMessage)
      } else {
        try channelFactory(pageURI, onDisconnect, onMessage)
      }
      backendChannel = channel
      try await channel.connect()
      registerClient()
    } catch {
      self.error = String(describing: error)
      didDisconnect()
    }
  }

  public func dispose() {
    guard !disposed else { return }
    disposed = true
    reconnectTask?.cancel()
    reconnectTask = nil
    if let pageListener { page.removeListener(pageListener) }
    pageListener = nil
    pageServiceBindings?.dispose()
    pageServiceBindings = nil
    scrollTargets.removeAll()
    backendChannel?.disconnect()
    backendChannel = nil
  }

  public func index(_ control: RufletControl) {
    controlsIndex[control.id] = WeakControl(control)
  }

  public func control(id: Int) -> RufletControl? {
    if controlsIndex[id]?.value == nil { controlsIndex.removeValue(forKey: id) }
    return controlsIndex[id]?.value
  }

  public func registerScrollTarget(_ target: RufletScrollTarget, for key: String) {
    scrollTargets[key] = target
  }

  public func unregisterScrollTarget(_ target: RufletScrollTarget, for key: String) {
    guard scrollTargets[key] === target else { return }
    scrollTargets.removeValue(forKey: key)
  }

  public func scrollTarget(for key: String) -> RufletScrollTarget? {
    scrollTargets[key]
  }

  public func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    guard control.hasEventHandler(name) else { return }
    triggerControlEvent(controlID: control.id, name: name, data: data)
  }

  public func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    send(
      RufletMessage(
        action: .controlEvent,
        payload: RufletControlEventBody(target: controlID, name: name, data: data).value))
  }

  public func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool = true,
    server: Bool = true,
    notify: Bool = false
  ) {
    guard let control = control(id: id) else { return }
    if client { _ = control.update(properties, notify: notify) }
    if server {
      send(
        RufletMessage(
          action: .updateControl,
          payload: RufletUpdateControlBody(id: id, properties: properties).value))
    }
  }

  public func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? {
    guard let text = source.text else { return nil }
    if text.hasPrefix("http://") || text.hasPrefix("https://") {
      return RufletAssetSource(path: text, isFile: false)
    }
    let expanded = NSString(string: text).expandingTildeInPath
    if FileManager.default.fileExists(atPath: expanded) {
      return RufletAssetSource(path: expanded, isFile: true)
    }
    if !assetsDirectory.isEmpty {
      let normalized = text.replacingOccurrences(of: "\\", with: "/")
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return RufletAssetSource(
        path: URL(fileURLWithPath: assetsDirectory).appendingPathComponent(normalized).path,
        isFile: true)
    }
    guard let pageURI else { return nil }
    if let absolute = URL(string: text), absolute.scheme != nil {
      return RufletAssetSource(path: absolute.absoluteString, isFile: false)
    }
    return RufletAssetSource(
      path: pageURI.appendingPathComponent(text).absoluteString,
      isFile: false)
  }

  public func onWindowEvent(_ name: String, state: RufletWindowState) {
    guard let window = page.child("window", visibleOnly: false) else { return }
    updateControl(window.id, properties: state.value.map ?? [:])
    triggerControlEvent(window, name: "event", data: ["type": .string(name)])
  }

  public func onRouteUpdated(_ newRoute: String) {
    if route.isEmpty && isLoading {
      route = newRoute
      page.update(["route": .string(newRoute), "platform": .string(rufletApplePlatformName)])
      connectWhenReady()
      return
    }
    guard newRoute != route else { return }
    route = newRoute
    updateControl(page.id, properties: ["route": .string(newRoute)], notify: true)
    RufletPageEventContract.routeChanged(page, route: newRoute)
  }

  public func updatePageSize(_ size: CGSize, view: RufletControl? = nil) {
    pageSize = size
    receivedFirstPageSize = true
    let values: [String: RufletValue] = [
      "width": .double(size.width),
      "height": .double(size.height),
    ]
    let control = view ?? page!
    updateControl(control.id, properties: values)
    triggerControlEvent(control, name: "resize", data: .map(values))
    connectWhenReady()
  }

  public func updateBrightness(_ brightness: String) {
    platformBrightness = brightness
    updateControl(page.id, properties: ["platform_brightness": .string(brightness)])
    RufletPageEventContract.platformBrightnessChanged(page, brightness: brightness)
  }

  public func updateMedia(_ media: RufletPageMediaData, view: RufletControl? = nil) {
    self.media = media
    let control = view ?? page!
    updateControl(control.id, properties: ["media": media.value])
    RufletPageEventContract.mediaChanged(control, media: media)
  }

  public func formatAppErrorMessage(_ rawError: String) -> String {
    guard !rawError.isEmpty else { return "" }
    var template = appErrorMessage ?? Self.defaultAppErrorMessageTemplate
    let lines = rawError.split(whereSeparator: \.isNewline).map(String.init)
    template = template.replacingOccurrences(of: "{message}", with: lines.first ?? "")
    let details = lines.dropFirst().joined(separator: "\n")
    if details.isEmpty {
      template = template.replacingOccurrences(
        of: #"(\r?\n)*\{details\}"#,
        with: "",
        options: .regularExpression)
    } else {
      template = template.replacingOccurrences(of: "{details}", with: details)
    }
    return template.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func pageDidUpdate() {
    // The wire may publish a platform value, but Apple rendering never switches engines.
    if page.string("platform") == nil {
      page.update(["platform": .string(rufletApplePlatformName)])
    }
  }

  private func registerClient() {
    guard let pageURI else { return }
    let body = RufletRegisterClientRequestBody(
      sessionID: nil,
      pageName: rufletPageName(pageURI),
      page: [
        "route": page.value("route") ?? .null,
        "pwa": page.value("pwa") ?? .null,
        "web": page.value("web") ?? .null,
        "debug": page.value("debug") ?? .null,
        "wasm": page.value("wasm") ?? .null,
        "test": page.value("test") ?? .null,
        "multi_view": page.value("multi_view") ?? .null,
        "pyodide": page.value("pyodide") ?? .null,
        "platform_brightness": page.value("platform_brightness") ?? .null,
        "width": page.value("width") ?? .null,
        "height": page.value("height") ?? .null,
        "platform": .string(rufletApplePlatformName),
        "window": page.child("window", visibleOnly: false)?.propertyMap ?? .map([:]),
        "media": page.value("media") ?? .null,
      ])
    send(RufletMessage(action: .registerClient, payload: body.value), unbuffered: true)
  }

  private func receive(_ message: RufletMessage) {
    do {
      switch message.action {
      case .registerClient:
        try clientRegistered(RufletRegisterClientResponseBody(value: message.payload))
      case .sessionCrashed:
        error = try RufletSessionCrashedBody(value: message.payload).message
      case .patchControl:
        let request = try RufletPatchControlRequestBody(value: message.payload)
        guard let target = control(id: request.id) else {
          RufletProtocolDiagnostics.timing(
            "patch_missing_target", milliseconds: 0, details: "target=\(request.id)")
          return
        }
        let started = RufletProtocolDiagnostics.now()
        try target.applyPatch(request.patch)
        RufletProtocolDiagnostics.timing(
          "apply_patch",
          milliseconds: (RufletProtocolDiagnostics.now() - started) * 1_000,
          details: "target=\(request.id) patch_items=\(request.patch.count)")
      case .invokeControlMethod:
        let request = try RufletInvokeMethodRequestBody(value: message.payload)
        Task { await invoke(request) }
      case .controlEvent, .updateControl:
        break
      }
    } catch {
      self.error = String(describing: error)
    }
  }

  private func clientRegistered(_ response: RufletRegisterClientResponseBody) throws {
    if response.error?.isEmpty ?? true {
      isLoading = false
      reconnectDelayMilliseconds = 0
      reconnectStartedUptime = nil
      error = ""
      _ = page.update(response.pagePatch, notify: true)
      let queued = sendQueue
      sendQueue.removeAll()
      for message in queued { send(message) }
    } else {
      isLoading = false
      error = response.error ?? ""
      reconnectDelayMilliseconds = 0
      reconnectStartedUptime = nil
    }
  }

  private func invoke(_ request: RufletInvokeMethodRequestBody) async {
    let result: RufletValue
    let failure: String?
    if let control = control(id: request.controlID) {
      do {
        result = try await withThrowingTaskGroup(of: RufletValue.self) { group in
          group.addTask {
            try await control.invokeMethod(request.name, arguments: request.arguments)
          }
          group.addTask {
            try await Task<Never, Never>.sleep(nanoseconds: request.timeoutNanoseconds)
            throw RufletBackendError.methodTimedOut(request.name)
          }
          let value = try await group.next()!
          group.cancelAll()
          return value
        }
        failure = nil
      } catch {
        result = .null
        failure = String(describing: error)
      }
    } else {
      result = .null
      failure = "Calling \(request.name) method of inexistent control: \(request.controlID)"
    }
    send(
      RufletMessage(
        action: .invokeControlMethod,
        payload: RufletInvokeMethodResponseBody(
          controlID: request.controlID,
          callID: request.callID,
          result: result,
          error: failure
        ).value))
  }

  private func didDisconnect() {
    guard !disposed, let channel = backendChannel else { return }
    backendChannel = nil
    if reconnectStartedUptime == nil {
      reconnectStartedUptime = ProcessInfo.processInfo.systemUptime
    }
    let nextDelay: Int
    if reconnectDelayMilliseconds == 0 || channel.isLocalConnection {
      nextDelay =
        reconnectIntervalMilliseconds
        ?? channel.defaultReconnectIntervalMilliseconds
    } else {
      nextDelay = reconnectDelayMilliseconds * 2
    }

    if let timeout = reconnectTimeoutMilliseconds,
      let started = reconnectStartedUptime,
      ProcessInfo.processInfo.systemUptime - started >= Double(timeout) / 1_000
    {
      errorsHandler?.onError(
        error.isEmpty
          ? "Error connecting to a Ruflet service in a timely manner."
          : error)
      return
    }

    isLoading = true
    error = pageURI?.scheme == nil ? "" : "Loading..."
    reconnectDelayMilliseconds = nextDelay
    reconnectTask?.cancel()
    reconnectTask = Task { [weak self] in
      try? await Task<Never, Never>.sleep(
        nanoseconds: UInt64(max(0, nextDelay)) * 1_000_000)
      guard !Task.isCancelled else { return }
      await self?.connect()
    }
  }

  private func connectWhenReady() {
    guard receivedFirstPageSize, !route.isEmpty, !disposed else { return }
    Task { await connect() }
  }

  private func send(_ message: RufletMessage, unbuffered: Bool = false) {
    if unbuffered || !isLoading {
      try? backendChannel?.send(message)
    } else {
      sendQueue.append(message)
    }
  }
}

private final class WeakControl {
  weak var value: RufletControl?
  init(_ value: RufletControl) { self.value = value }
}

public enum RufletBackendError: Error, Equatable {
  case methodTimedOut(String)
}

private var rufletApplePlatformName: String {
  #if os(iOS)
    return "ios"
  #elseif os(macOS)
    return "macos"
  #endif
}

private func rufletPageName(_ uri: URL) -> String {
  let parts = uri.path.split(separator: "/")
  return parts.prefix(2).joined(separator: "/")
}
