import XCTest
@testable import RufletEngine
@testable import RufletUI

@MainActor
final class PageScreenshotParityTests: XCTestCase {
  func testMethodSpecificHandlerDoesNotClaimOtherPageMethods() {
    let bus = ControlCommandBus()
    bus.register(1, method: "take_screenshot") { _, completion in
      completion(.success(.binary([0x89, 0x50])))
    }

    let screenshot = RufletMethodCall(
      controlID: 1, callID: "a", name: "take_screenshot", args: .map([:]))
    XCTAssertTrue(bus.invoke(screenshot) { _ in })

    let route = RufletMethodCall(
      controlID: 1, callID: "b", name: "push_route", args: .map([:]))
    XCTAssertFalse(bus.invoke(route) { _ in })
  }

  func testPageCaptureUsesScreenshotDurationParsing() {
    XCTAssertEqual(RufletScreenshotSemantics.delayMilliseconds(nil), 20)
    XCTAssertEqual(
      RufletScreenshotSemantics.delayMilliseconds(.extended(type: 3, string: "125000")),
      125)
  }

  func testExternalRoutesMatchFletPathQueryFragmentNormalization() throws {
    XCTAssertEqual(
      PageRouteSemantics.normalizeExternalURL(
        try XCTUnwrap(URL(string: "ruflet://app/store/item?q=red%20blue#details"))),
      "/store/item?q=red%20blue#details")
    XCTAssertEqual(
      PageRouteSemantics.normalizeExternalURL(
        try XCTUnwrap(URL(string: "ruflet://app"))),
      "/")
  }

  func testPageDeclaresItsNativeRouteEvent() {
    XCTAssertTrue(
      ControlRegistry.descriptor(for: "Page")?.supportedEvents.contains("route_change") == true)
  }
}
