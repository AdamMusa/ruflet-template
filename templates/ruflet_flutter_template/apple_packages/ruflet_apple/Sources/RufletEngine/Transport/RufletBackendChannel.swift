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
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) throws -> RufletBackendChannel {
    switch address.scheme?.lowercased() {
    case "http", "https", "ws", "wss":
      return try RufletWebSocketBackendChannel(
        address: address,
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    case "tcp":
      return try RufletSocketBackendChannel(
        address: address,
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    case nil:
      return try RufletSocketBackendChannel(
        unixDomainSocketPath: address.path,
        onDisconnect: onDisconnect,
        onMessage: onMessage)
    default:
      throw RufletTransportError.unsupportedAddress(address.absoluteString)
    }
  }
}

public enum RufletTransportError: Error, Equatable {
  case unsupportedAddress(String)
  case missingHost
  case missingPort
  case emptyWebSocketEndpoint
  case disconnected
  case invalidResponse
  case cannotResolveHost(String)
}

func rufletWebSocketEndpoint(_ address: URL) throws -> URL {
  guard address.host != nil else { throw RufletTransportError.missingHost }
  var components = URLComponents(url: address, resolvingAgainstBaseURL: false)
  components?.scheme = address.scheme?.lowercased() == "https" || address.scheme?.lowercased() == "wss" ? "wss" : "ws"
  let path = address.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  components?.path = path.isEmpty ? "/ws" : "/\(path)/ws"
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
