import Foundation
import RufletProtocol

@MainActor
public final class RufletWebSocketBackendChannel: RufletBackendChannel {
  public let endpoint: URL
  public private(set) var isLocalConnection: Bool
  public let defaultReconnectIntervalMilliseconds = rufletDefaultPublicReconnectInterval

  private let session: URLSession
  private let onDisconnect: () -> Void
  private let onMessage: (RufletMessage) -> Void
  private var task: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?

  public init(
    address: URL,
    session: URLSession = .shared,
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) throws {
    self.endpoint = try rufletWebSocketEndpoint(address)
    self.isLocalConnection = address.host.map(rufletIsPrivateHost) ?? false
    self.session = session
    self.onDisconnect = onDisconnect
    self.onMessage = onMessage
  }

  public func connect() async throws {
    if let host = endpoint.host {
      isLocalConnection = try await rufletIsPrivateHostResolving(host)
    }
    let task = session.webSocketTask(with: endpoint)
    self.task = task
    task.resume()
    receiveTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        do {
          let frame = try await task.receive()
          let data: Data
          switch frame {
          case .data(let value): data = value
          case .string(let value): data = Data(value.utf8)
          @unknown default: throw RufletTransportError.invalidResponse
          }
          let decodeStarted = RufletProtocolDiagnostics.now()
          let value = try RufletMessagePack.decode(data)
          guard let list = value.array else { throw RufletTransportError.invalidResponse }
          let message = try RufletMessage(list: list)
          RufletProtocolDiagnostics.frame(
            "ruby->native",
            bytes: data.count,
            message: message,
            decodeMilliseconds: (RufletProtocolDiagnostics.now() - decodeStarted) * 1_000)
          self.onMessage(message)
        } catch {
          if !Task.isCancelled { self.onDisconnect() }
          return
        }
      }
    }
  }

  public func send(_ message: RufletMessage) throws {
    guard let task else { throw RufletTransportError.disconnected }
    let data = RufletMessagePack.encode(.array(message.list))
    RufletProtocolDiagnostics.frame("native->ruby", bytes: data.count, message: message)
    task.send(.data(data)) { _ in }
  }

  public func disconnect() {
    receiveTask?.cancel()
    receiveTask = nil
    task?.cancel(with: .normalClosure, reason: nil)
    task = nil
  }
}
