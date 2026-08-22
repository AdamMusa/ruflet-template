import Foundation
import Network
import RufletProtocol
#if canImport(Darwin)
import Darwin
#endif

public let rufletDefaultLocalReconnectInterval = 200
public let rufletDefaultPublicReconnectInterval = 500

@MainActor
public protocol RufletBackendChannel: AnyObject {
  var isLocalConnection: Bool { get }
  var defaultReconnectIntervalMilliseconds: Int { get }
  func connect() async throws
  func send(_ message: RufletMessage) throws
  func disconnect()
}

@MainActor
public enum RufletBackendChannelFactory {
  public static func make(
    address: URL,
    forcePyodide: Bool = false,
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) throws -> RufletBackendChannel {
    // Pinned Flet selects its JavaScript channel before inspecting the
    // address. The Dart IO implementation is intentionally a no-op channel;
    // preserving it matters for nested FletApp controls which explicitly set
    // force_pyodide even when the Apple host itself cannot run Pyodide.
    if forcePyodide {
      return RufletJavaScriptBackendChannel(
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    }
    switch address.scheme?.lowercased() {
    case "inprocess":
      return try RufletInProcessBackendChannel(
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    case "http", "https":
      return try RufletWebSocketBackendChannel(
        address: address,
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    case "tcp":
      return try RufletSocketBackendChannel(
        address: address,
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    case nil where address.absoluteString == "mock":
      return RufletMockBackendChannel(
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    default:
      // Pinned Flet treats every remaining address as a Unix-domain socket
      // path. Preserve the original text; schemes such as `ws://` and
      // `ftp://` are not special cases in its non-web factory.
      return try RufletSocketBackendChannel(
        unixDomainSocketPath: address.absoluteString,
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    }
  }
}

/// Exact Apple counterpart of pinned Flet's
/// `flet_backend_channel_javascript_io.dart`.
///
/// The IO stub connects and sends successfully without delivering frames. It
/// reports a local connection and Flet's 10 ms reconnect default.
@MainActor
public final class RufletJavaScriptBackendChannel: RufletBackendChannel {
  public let isLocalConnection = true
  public let defaultReconnectIntervalMilliseconds = 10

  private let onDisconnect: () -> Void
  private let onMessage: (RufletMessage) -> Void

  public init(
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) {
    self.onDisconnect = onDisconnect
    self.onMessage = onMessage
  }

  public func connect() async throws {}
  public func send(_: RufletMessage) throws {}
  public func disconnect() {}
}

/// Apple/non-web counterpart of pinned Flet's deterministic mock channel.
/// Its deliberately legacy-shaped payloads are copied from the upstream mock;
/// this channel exists for transport parity and is not used by release hosts.
@MainActor
public final class RufletMockBackendChannel: RufletBackendChannel {
  public let isLocalConnection = true
  public let defaultReconnectIntervalMilliseconds = 500

  private let onDisconnect: () -> Void
  private let onMessage: (RufletMessage) -> Void
  private var scenarioTask: Task<Void, Never>?

  public init(
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) {
    self.onDisconnect = onDisconnect
    self.onMessage = onMessage
  }

  public func connect() async throws {
    try await Task<Never, Never>.sleep(nanoseconds: 1_000_000_000)
    onMessage(RufletMessage(action: .registerClient, payload: Self.registrationPayload))
    scenarioTask = Task { [weak self] in
      try? await Task<Never, Never>.sleep(nanoseconds: 3_000_000_000)
      guard !Task.isCancelled, let self else { return }
      self.onMessage(RufletMessage(
        action: .patchControl,
        payload: ["id": 2, "patch": ["width": 300, "height": 300]]))
    }
  }

  public func send(_: RufletMessage) throws {}

  public func disconnect() {
    scenarioTask?.cancel()
    scenarioTask = nil
  }

  private static let registrationPayload: RufletValue = [
    "id": 1,
    "patch": [
      "show_semantics_debugger": false,
      "theme_mode": "system",
      "fonts": [
        "Kanit": "https://raw.githubusercontent.com/google/fonts/master/ofl/kanit/Kanit-Bold.ttf",
        "Open Sans": "/fonts/OpenSans-Regular.ttf",
      ],
      "offstage": [
        "_c": "Offstage", "_i": 8,
        "controls": [["_c": "Text", "_i": 20, "text": "OFF1"]],
      ],
      "_services": ["_c": "ServiceRegistry", "_i": 10, "services": []],
      "views": [[
        "_c": "View", "_i": 20, "route": "/",
        "controls": [
          ["_c": "Text", "_i": 3, "text": "Hello, world"],
          ["_c": "Text", "_i": 4, "text": "Second line"],
          [
            "_c": "Row", "_i": 5,
            "controls": [
              ["_c": "Text", "_i": 6, "text": "1st in Row"],
              ["_c": "Text", "_i": 7, "text": "2nd in Row"],
            ],
          ],
        ],
      ]],
    ],
  ]
}

public enum RufletTransportError: Error, Equatable {
  case unsupportedAddress(String)
  case missingHost
  case missingPort
  case emptyWebSocketEndpoint
  case disconnected
  case invalidResponse
  case cannotResolveHost(String)
  case missingInProcessBridgeSymbol(String)
  case inProcessBridgeFailure(String)
}

func rufletWebSocketEndpoint(_ address: URL) throws -> URL {
  guard address.host != nil else { throw RufletTransportError.missingHost }
  var components = URLComponents(url: address, resolvingAgainstBaseURL: false)
  components?.scheme = address.scheme?.lowercased() == "https" || address.scheme?.lowercased() == "wss" ? "wss" : "ws"
  components?.path = "/\(rufletWebSocketEndpointPath(address.path))"
  components?.query = nil
  components?.fragment = nil
  guard let url = components?.url else { throw RufletTransportError.emptyWebSocketEndpoint }
  return url
}

func rufletIsPrivateHost(_ host: String) -> Bool {
  if host.lowercased() == "localhost" { return true }
  guard let address = rufletIPAddress(host) else { return false }
  return address.isPrivate
}

func rufletIsPrivateHostResolving(_ host: String) async throws -> Bool {
  if host.lowercased() == "localhost" { return true }
  if let address = rufletIPAddress(host) { return address.isPrivate }
  let address = try await Task.detached(priority: .userInitiated) {
    try rufletResolveFirstIPAddress(host)
  }.value
  return address.isPrivate
}

private enum RufletIPAddress: Sendable {
  case v4([UInt8])
  case v6([UInt8])

  var isPrivate: Bool {
    switch self {
    case .v4(let bytes):
      guard bytes.count == 4 else { return false }
      return bytes[0] == 10
        || bytes[0] == 127
        || (bytes[0] == 172 && (16...31).contains(bytes[1]))
        || (bytes[0] == 192 && bytes[1] == 168)
    case .v6(let bytes):
      guard bytes.count == 16 else { return false }
      let loopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
      let linkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
      return loopback || linkLocal
    }
  }
}

private func rufletIPAddress(_ host: String) -> RufletIPAddress? {
  var v4 = in_addr()
  if host.withCString({ inet_pton(AF_INET, $0, &v4) }) == 1 {
    return withUnsafeBytes(of: &v4) { .v4(Array($0)) }
  }
  var v6 = in6_addr()
  if host.withCString({ inet_pton(AF_INET6, $0, &v6) }) == 1 {
    return withUnsafeBytes(of: &v6) { .v6(Array($0)) }
  }
  return nil
}

private func rufletResolveFirstIPAddress(_ host: String) throws -> RufletIPAddress {
  var hints = addrinfo()
  hints.ai_family = AF_UNSPEC
  hints.ai_socktype = SOCK_STREAM
  hints.ai_protocol = IPPROTO_TCP
  var result: UnsafeMutablePointer<addrinfo>?
  let status = host.withCString { getaddrinfo($0, nil, &hints, &result) }
  guard status == 0, let result else {
    throw RufletTransportError.cannotResolveHost(host)
  }
  defer { freeaddrinfo(result) }

  var cursor: UnsafeMutablePointer<addrinfo>? = result
  while let entry = cursor?.pointee {
    if entry.ai_family == AF_INET,
       let pointer = entry.ai_addr?.withMemoryRebound(
         to: sockaddr_in.self,
         capacity: 1,
         { $0 }) {
      var address = pointer.pointee.sin_addr
      return withUnsafeBytes(of: &address) { .v4(Array($0)) }
    }
    if entry.ai_family == AF_INET6,
       let pointer = entry.ai_addr?.withMemoryRebound(
         to: sockaddr_in6.self,
         capacity: 1,
         { $0 }) {
      var address = pointer.pointee.sin6_addr
      return withUnsafeBytes(of: &address) { .v6(Array($0)) }
    }
    cursor = entry.ai_next
  }
  throw RufletTransportError.cannotResolveHost(host)
}
