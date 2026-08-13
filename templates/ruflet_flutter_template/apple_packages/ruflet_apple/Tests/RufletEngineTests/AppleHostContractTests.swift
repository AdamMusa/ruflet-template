import Foundation
import XCTest
@testable import RufletEngine
import RufletProtocol

@MainActor
final class AppleHostContractTests: XCTestCase {
  func testPageAddressRemainsTheOriginalHTTPURI() throws {
    let raw = "http://192.168.1.226:8550/gallery?source=self"
    let pageURL = try XCTUnwrap(RufletPageAddress.parse(raw))
    XCTAssertEqual(pageURL.absoluteString, raw)

    let channel = try RufletWebSocketBackendChannel(
      address: pageURL,
      onDisconnect: {},
      onMessage: { _ in })
    XCTAssertEqual(channel.endpoint.absoluteString, "ws://192.168.1.226:8550/gallery/ws")
    XCTAssertFalse(channel.endpoint.path.contains("/ws/ws"))
  }

  func testPageAddressRejectsMalformedOrUnsupportedValues() {
    XCTAssertNil(RufletPageAddress.parse(""))
    XCTAssertNil(RufletPageAddress.parse(" https://example.com"))
    XCTAssertNil(RufletPageAddress.parse("ws://example.com/ws"))
    XCTAssertNil(RufletPageAddress.parse("wss://example.com/ws"))
    XCTAssertNil(RufletPageAddress.parse("file:///tmp/page"))
    XCTAssertNil(RufletPageAddress.parse("tcp://localhost"))
  }

  func testInitialSceneDataPreservesWireValueKinds() {
    let value: [String: Any] = [
      "enabled": true,
      "count": 7,
      "ratio": 2.5,
      "name": "secondary",
      "items": [1, "two", false] as [Any],
      "metadata": ["nested": "value"],
    ]
    XCTAssertEqual(
      RufletSceneInitialData.convert(value),
      .map([
        "enabled": .bool(true),
        "count": .int(7),
        "ratio": .double(2.5),
        "name": .string("secondary"),
        "items": .array([.int(1), .string("two"), .bool(false)]),
        "metadata": .map(["nested": .string("value")]),
      ]))
  }

  func testMultiViewApplicationUsesOneBackendAndStableSceneIDs() async throws {
    let pageURL = try XCTUnwrap(URL(string: "http://127.0.0.1:8550"))
    let application = RufletMultiViewApplication(pageURL: pageURL)

    let first = application.connect(
      sessionIdentifier: "first",
      initialData: ["source": .string("primary")])
    let repeated = application.connect(sessionIdentifier: "first")
    let second = application.connect(sessionIdentifier: "second")

    XCTAssertTrue(application.backend.multiView)
    XCTAssertEqual(application.backend.pageURI, pageURL)
    XCTAssertEqual(first, repeated)
    XCTAssertEqual(first.viewID, 1)
    XCTAssertEqual(second.viewID, 2)
    XCTAssertEqual(application.scenes, [first, second])
    XCTAssertEqual(application.pageLifecycleOwnerID, first.viewID)

    await Task.yield()
    XCTAssertEqual(application.backend.route, "/")

    application.disconnect(sessionIdentifier: "first")
    XCTAssertEqual(application.scenes, [second])
    XCTAssertEqual(application.pageLifecycleOwnerID, second.viewID)
    application.dispose()
  }
}
