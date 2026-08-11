@testable import RufletUI
import XCTest

final class RufletAppControlTests: XCTestCase {
  func testRufletAppIsTheOnlyNativeApplicationWireName() {
    let canonical = ControlRegistry.descriptor(for: "RufletApp")

    XCTAssertEqual(canonical?.classification, .visible)
    XCTAssertEqual(canonical?.implementation, "RufletAppControlView")
    XCTAssertNil(ControlRegistry.descriptor(for: "FletApp"))
  }

  func testNestedAppInheritsParentEndpointWhenURLIsOmitted() {
    let parent = URL(string: "wss://example.test/custom")!
    XCTAssertEqual(RufletAppEndpoint.resolve(nil, inheriting: parent), parent)
    XCTAssertEqual(RufletAppEndpoint.resolve("", inheriting: parent), parent)
  }

  func testNestedAppNormalizesHTTPServerURLsToWebSockets() {
    XCTAssertEqual(
      RufletAppEndpoint.resolve("http://127.0.0.1:8550", inheriting: nil)?.absoluteString,
      "ws://127.0.0.1:8550/ws")
    XCTAssertEqual(
      RufletAppEndpoint.resolve("https://example.test/ruflet", inheriting: nil)?.absoluteString,
      "wss://example.test/ruflet")
  }
}
