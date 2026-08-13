import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class CupertinoSliderPropertyConsumptionTests: XCTestCase {
  func testPresentationConsumesPinnedThumbAndRangeProperties() {
    let presentation = RufletCupertinoSliderPresentation(
      control: control(properties: [
        "min": .double(-10),
        "max": .double(30),
        "value": .double(8),
        "divisions": .int(8),
        "active_color": .string("blue"),
        "thumb_color": .string("purple"),
      ]))

    XCTAssertEqual(presentation.minimum, -10)
    XCTAssertEqual(presentation.maximum, 30)
    XCTAssertEqual(presentation.value, 8)
    XCTAssertEqual(presentation.divisions, 8)
    XCTAssertEqual(presentation.step, 5)
    XCTAssertEqual(presentation.snap(11.9), 10)
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.thumbColor)
    XCTAssertFalse(presentation.disabled)
  }

  func testValueClampsAndInvalidRangeDisablesNativeInteraction() {
    let presentation = RufletCupertinoSliderPresentation(
      control: control(properties: [
        "min": .double(10),
        "max": .double(2),
        "value": .double(40),
      ]))

    XCTAssertEqual(presentation.minimum, 2)
    XCTAssertEqual(presentation.maximum, 10)
    XCTAssertEqual(presentation.value, 10)
    XCTAssertNil(presentation.divisions)
    XCTAssertEqual(presentation.snap(7.123), 7.123)
    XCTAssertFalse(presentation.disabled)

    let collapsed = RufletCupertinoSliderPresentation(
      control: control(properties: [
        "min": .double(4),
        "max": .double(4),
      ]))
    XCTAssertTrue(collapsed.disabled)
    XCTAssertGreaterThan(collapsed.step, 0)
  }

  func testPinnedDefaultThumbIsNativeCupertinoWhite() {
    let presentation = RufletCupertinoSliderPresentation(control: control(properties: [:]))
    XCTAssertEqual(presentation.minimum, 0)
    XCTAssertEqual(presentation.maximum, 1)
    XCTAssertEqual(presentation.value, 0)
    XCTAssertNil(presentation.divisions)
    XCTAssertEqual(presentation.step, 0.1)
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.thumbColor)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "CupertinoSlider",
      properties: properties,
      backend: CupertinoSliderTestBackend())
  }
}

@MainActor
private final class CupertinoSliderTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
