import Foundation
import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

private final class PageRecordingTransport: RufletTransport {
  weak var delegate: RufletTransportDelegate?
  private(set) var sent: [Data] = []

  func connect() { delegate?.transportDidOpen(self) }
  func send(_ data: Data) { sent.append(data) }
  func disconnect() { delegate?.transport(self, didCloseWith: nil) }
}

final class PageHostParityTests: XCTestCase {
  func testRegistrationAdvertisesMultiViewOnlyForMultiSceneHost() throws {
    var single = ClientCapabilities()
    XCTAssertEqual(single.registerPayload()["page"]?["multi_view"], .bool(false))

    single.multiView = true
    XCTAssertEqual(single.registerPayload()["page"]?["multi_view"], .bool(true))
  }

  @MainActor
  func testNativeSceneRegistryEmitsFletAddAndRemovePayloadsWithoutSubscribers() throws {
    let transport = PageRecordingTransport()
    let session = RufletSession(transport: transport)
    let registry = RufletNativeSceneRegistry()

    let first = registry.connect(
      sessionIdentifier: "primary", initialData: ["route": .string("/first")])
    registry.bind(to: session)
    let second = registry.connect(sessionIdentifier: "secondary")
    registry.disconnect(sessionIdentifier: "primary")

    let messages = try transport.sent.map(RufletMessage.decode)
    XCTAssertEqual(messages.map(\.action), [.controlEvent, .controlEvent, .controlEvent])

    XCTAssertEqual(messages[0].payload["name"], .string("multi_view_add"))
    XCTAssertEqual(messages[0].payload["data"]?["view_id"], .int(Int64(first.id)))
    XCTAssertEqual(messages[0].payload["data"]?["initial_data"]?["route"], .string("/first"))

    XCTAssertEqual(messages[1].payload["name"], .string("multi_view_add"))
    XCTAssertEqual(messages[1].payload["data"]?["view_id"], .int(Int64(second.id)))

    XCTAssertEqual(messages[2].payload["name"], .string("multi_view_remove"))
    XCTAssertEqual(messages[2].payload["data"], .int(Int64(first.id)))
  }

  @MainActor
  func testReconnectOfSamePlatformSceneDoesNotEmitDuplicateAdd() throws {
    let transport = PageRecordingTransport()
    let session = RufletSession(transport: transport)
    let registry = RufletNativeSceneRegistry()
    registry.bind(to: session)

    let first = registry.connect(sessionIdentifier: "primary")
    let same = registry.connect(sessionIdentifier: "primary")

    XCTAssertEqual(first, same)
    XCTAssertEqual(transport.sent.count, 1)
  }

  func testSceneInitialDataUsesOnlyWireSafePropertyListValues() {
    let converted = RufletSceneInitialData.convert([
      "name": "details",
      "count": 2,
      "active": true,
      "nested": ["route": "/settings"],
    ])
    XCTAssertEqual(converted?["name"], .string("details"))
    XCTAssertEqual(converted?["count"], .int(2))
    XCTAssertEqual(converted?["active"], .bool(true))
    XCTAssertEqual(converted?["nested"]?["route"], .string("/settings"))
  }
}
