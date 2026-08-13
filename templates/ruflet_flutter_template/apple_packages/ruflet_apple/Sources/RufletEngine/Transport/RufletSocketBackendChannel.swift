import Foundation
import Network
import RufletProtocol

@MainActor
public final class RufletSocketBackendChannel: RufletBackendChannel {
  public private(set) var isLocalConnection: Bool
  public var defaultReconnectIntervalMilliseconds: Int {
    isLocalConnection ? rufletDefaultLocalReconnectInterval : rufletDefaultPublicReconnectInterval
  }

  private let connection: NWConnection
  private let remoteHost: String?
  private let onDisconnect: () -> Void
  private let onMessage: (RufletMessage) -> Void
  private var decoder = RufletStreamingMessagePackDecoder()

  public init(
    address: URL,
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) throws {
    guard let host = address.host else { throw RufletTransportError.missingHost }
    guard let port = address.port, let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
      throw RufletTransportError.missingPort
    }
    isLocalConnection = rufletIsPrivateHost(host)
    remoteHost = host
    connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
    self.onDisconnect = onDisconnect
    self.onMessage = onMessage
  }

  public init(
    unixDomainSocketPath: String,
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) throws {
    guard !unixDomainSocketPath.isEmpty else { throw RufletTransportError.missingHost }
    isLocalConnection = true
    remoteHost = nil
    connection = NWConnection(to: .unix(path: unixDomainSocketPath), using: .tcp)
    self.onDisconnect = onDisconnect
    self.onMessage = onMessage
  }

  public func connect() async throws {
    if let remoteHost {
      isLocalConnection = try await rufletIsPrivateHostResolving(remoteHost)
    }
    try await withCheckedThrowingContinuation { continuation in
      var resumed = false
      connection.stateUpdateHandler = { [weak self] state in
        Task { @MainActor in
          guard let self else { return }
          switch state {
          case .ready:
            if !resumed { resumed = true; continuation.resume() }
            self.receive()
          case .failed(let error), .waiting(let error):
            if !resumed { resumed = true; continuation.resume(throwing: error) }
            else { self.onDisconnect() }
          case .cancelled:
            if !resumed { resumed = true; continuation.resume(throwing: RufletTransportError.disconnected) }
          default: break
          }
        }
      }
      connection.start(queue: .global(qos: .userInitiated))
    }
  }

  public func send(_ message: RufletMessage) throws {
    let data = RufletMessagePack.encode(.array(message.list))
    connection.send(content: data, completion: .contentProcessed { _ in })
  }

  public func disconnect() { connection.cancel() }

  private func receive() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, complete, error in
      Task { @MainActor in
        guard let self else { return }
        do {
          if let data {
            self.decoder.append(data)
            for value in try self.decoder.decodeAvailable() {
              guard let list = value.array else { throw RufletTransportError.invalidResponse }
              self.onMessage(try RufletMessage(list: list))
            }
          }
          if complete || error != nil { self.onDisconnect() }
          else { self.receive() }
        } catch { self.onDisconnect() }
      }
    }
  }
}
