import Foundation
import XCTest

@testable import RufletEngine
@testable import RufletProtocol

@MainActor
final class InProcessTransportContractTests: XCTestCase {
  func testInProcessChannelPreservesCompleteProtocolFrames() async throws {
    let request = RufletMessage(
      action: .patchControl,
      payload: ["id": 42, "patch": ["value": "native"]])
    let box = InProcessBridgeBox(incoming: [
      RufletMessagePack.encode(.array(request.list))
    ])
    let delivered = expectation(description: "message delivered")
    var received: RufletMessage?
    let channel = RufletInProcessBackendChannel(
      operations: box.operations,
      onDisconnect: {},
      onMessage: {
        received = $0
        delivered.fulfill()
      })

    try await channel.connect()
    await fulfillment(of: [delivered], timeout: 1)
    XCTAssertEqual(received, request)

    let response = RufletMessage(
      action: .controlEvent,
      payload: ["target": 9, "name": "click"])
    try channel.send(response)
    XCTAssertEqual(try box.sentMessages(), [response])
    channel.disconnect()
  }

  func testFactoryNeverFallsBackForMissingInProcessRuntimeSymbols() {
    XCTAssertThrowsError(
      try RufletBackendChannelFactory.make(
        address: URL(string: "inprocess://embedded")!,
        onDisconnect: {},
        onMessage: { _ in })
    ) { error in
      guard case RufletTransportError.missingInProcessBridgeSymbol = error else {
        return XCTFail("unexpected error: \(error)")
      }
    }
  }
}

private final class InProcessBridgeBox: @unchecked Sendable {
  private let lock = NSLock()
  private var incoming: [Data]
  private var sent: [Data] = []
  private var closed = false

  init(incoming: [Data]) {
    self.incoming = incoming
  }

  var operations: RufletInProcessBridgeOperations {
    RufletInProcessBridgeOperations(
      sendToRuby: { [self] data in
        lock.withLock { sent.append(data) }
      },
      receiveForRenderer: { [self] in
        lock.withLock {
          if !incoming.isEmpty { return incoming.removeFirst() }
          return nil
        }
      },
      close: { [self] in
        lock.withLock { closed = true }
      })
  }

  func sentMessages() throws -> [RufletMessage] {
    try lock.withLock {
      try sent.map { data in
        guard let list = try RufletMessagePack.decode(data).array else {
          throw RufletTransportError.invalidResponse
        }
        return try RufletMessage(list: list)
      }
    }
  }
}
