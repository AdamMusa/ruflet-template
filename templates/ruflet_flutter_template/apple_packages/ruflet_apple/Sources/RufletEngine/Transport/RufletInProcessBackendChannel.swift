import Foundation
import RufletProtocol

#if canImport(Darwin)
  import Darwin
#endif

private let rufletBridgeClosed: Int32 = 0
private let rufletBridgeMessage: Int32 = 1

private typealias RufletBridgeSendFunction =
  @convention(c) (
    UnsafePointer<UInt8>?, Int
  ) -> Int32
private typealias RufletBridgeReceiveFunction =
  @convention(c) (
    UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    UnsafeMutablePointer<Int>?
  ) -> Int32
private typealias RufletBridgeCloseFunction = @convention(c) () -> Void
private typealias RufletBridgeFreeFunction =
  @convention(c) (
    UnsafeMutablePointer<UInt8>?
  ) -> Void

public struct RufletInProcessBridgeOperations: @unchecked Sendable {
  public let sendToRuby: @Sendable (Data) throws -> Void
  public let receiveForRenderer: @Sendable () throws -> Data?
  public let close: @Sendable () -> Void

  public init(
    sendToRuby: @escaping @Sendable (Data) throws -> Void,
    receiveForRenderer: @escaping @Sendable () throws -> Data?,
    close: @escaping @Sendable () -> Void
  ) {
    self.sendToRuby = sendToRuby
    self.receiveForRenderer = receiveForRenderer
    self.close = close
  }

  public static func resolve() throws -> Self {
    #if canImport(Darwin)
      guard let process = dlopen(nil, RTLD_NOW) else {
        throw RufletTransportError.missingInProcessBridgeSymbol("current process")
      }

      let send: RufletBridgeSendFunction = try resolveSymbol(
        "ruflet_bridge_send_to_ruby", from: process)
      let receive: RufletBridgeReceiveFunction = try resolveSymbol(
        "ruflet_bridge_receive_for_renderer", from: process)
      let closeFunction: RufletBridgeCloseFunction = try resolveSymbol(
        "ruflet_bridge_close", from: process)
      let freeMessage: RufletBridgeFreeFunction = try resolveSymbol(
        "ruflet_bridge_free_message", from: process)

      return Self(
        sendToRuby: { data in
          let status = data.withUnsafeBytes { buffer in
            send(buffer.bindMemory(to: UInt8.self).baseAddress, data.count)
          }
          guard status == rufletBridgeMessage else {
            throw RufletTransportError.inProcessBridgeFailure(
              status == rufletBridgeClosed ? "bridge is closed" : "send failed")
          }
        },
        receiveForRenderer: {
          var bytes: UnsafeMutablePointer<UInt8>?
          var length = 0
          let status = receive(&bytes, &length)
          guard status == rufletBridgeMessage else {
            if status == rufletBridgeClosed { return nil }
            throw RufletTransportError.inProcessBridgeFailure("receive failed")
          }
          guard let bytes else {
            if length == 0 { return Data() }
            throw RufletTransportError.inProcessBridgeFailure(
              "receive returned no bytes")
          }
          defer { freeMessage(bytes) }
          return Data(bytes: bytes, count: length)
        },
        close: closeFunction)
    #else
      throw RufletTransportError.missingInProcessBridgeSymbol("Darwin runtime")
    #endif
  }

  #if canImport(Darwin)
    private static func resolveSymbol<T>(
      _ name: String,
      from process: UnsafeMutableRawPointer
    ) throws -> T {
      guard let symbol = dlsym(process, name) else {
        throw RufletTransportError.missingInProcessBridgeSymbol(name)
      }
      return unsafeBitCast(symbol, to: T.self)
    }
  #endif
}

@MainActor
public final class RufletInProcessBackendChannel: RufletBackendChannel {
  public let isLocalConnection = true
  public let defaultReconnectIntervalMilliseconds = rufletDefaultLocalReconnectInterval

  private let operations: RufletInProcessBridgeOperations
  private let onDisconnect: () -> Void
  private let onMessage: (RufletMessage) -> Void
  private var receiveTask: Task<Void, Never>?
  private var connected = false

  public convenience init(
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) throws {
    try self.init(
      operations: .resolve(),
      onDisconnect: onDisconnect,
      onMessage: onMessage)
  }

  public init(
    operations: RufletInProcessBridgeOperations,
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void
  ) {
    self.operations = operations
    self.onDisconnect = onDisconnect
    self.onMessage = onMessage
  }

  public func connect() async throws {
    guard !connected else {
      throw RufletTransportError.inProcessBridgeFailure(
        "channel is already connected")
    }
    connected = true
    let operations = operations
    receiveTask = Task.detached(priority: .userInitiated) { [weak self] in
      while !Task.isCancelled {
        do {
          guard let data = try operations.receiveForRenderer() else {
            await self?.bridgeDidClose()
            return
          }
          let decodeStarted = RufletProtocolDiagnostics.now()
          let value = try RufletMessagePack.decode(data)
          guard let list = value.array else {
            throw RufletTransportError.invalidResponse
          }
          let message = try RufletMessage(list: list)
          RufletProtocolDiagnostics.frame(
            "ruby->native-in-process",
            bytes: data.count,
            message: message,
            decodeMilliseconds: (RufletProtocolDiagnostics.now() - decodeStarted) * 1_000)
          await self?.deliver(message)
        } catch {
          if !Task.isCancelled {
            await self?.bridgeDidClose()
          }
          return
        }
      }
    }
  }

  public func send(_ message: RufletMessage) throws {
    guard connected else { throw RufletTransportError.disconnected }
    let data = RufletMessagePack.encode(.array(message.list))
    RufletProtocolDiagnostics.frame(
      "native->ruby-in-process",
      bytes: data.count,
      message: message)
    try operations.sendToRuby(data)
  }

  public func disconnect() {
    guard connected else { return }
    connected = false
    receiveTask?.cancel()
    receiveTask = nil
    operations.close()
  }

  private func deliver(_ message: RufletMessage) {
    guard connected else { return }
    onMessage(message)
  }

  private func bridgeDidClose() {
    guard connected else { return }
    connected = false
    receiveTask = nil
    onDisconnect()
  }
}
