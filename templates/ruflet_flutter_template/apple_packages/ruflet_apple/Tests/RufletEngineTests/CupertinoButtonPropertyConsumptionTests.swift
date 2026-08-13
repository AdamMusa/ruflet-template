import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class CupertinoButtonPropertyConsumptionTests: XCTestCase {
  func testPlainCupertinoButtonConsumesPinnedNativeStateProperties() {
    let fixture = makeControl(
      type: "CupertinoButton",
      properties: [
        "autofocus": true,
        "disabled_bgcolor": "red",
        "focus_color": "blue",
        "mouse_cursor": "click",
        "size": "small",
      ])
    let presentation = RufletCupertinoButtonPresentation(control: fixture.control)

    XCTAssertEqual(presentation.variant, .plain)
    XCTAssertTrue(presentation.autofocus)
    XCTAssertNotNil(presentation.disabledBackgroundColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertEqual(presentation.mouseCursor, "click")
    XCTAssertEqual(presentation.size, .small)
    XCTAssertEqual(presentation.minimumSize, CGSize(width: 28, height: 28))
    XCTAssertEqual(presentation.padding.top, 6)
    XCTAssertEqual(presentation.padding.leading, 12)
    XCTAssertEqual(presentation.borderRadius.uniform, 40)
  }

  func testFilledAndTintedVariantsPreservePinnedVariantColorsAndSizeDefaults() {
    let filledFixture = makeControl(
      type: "CupertinoFilledButton",
      properties: ["size": "large", "bgcolor": "green", "color": "white"])
    let filled = RufletCupertinoButtonPresentation(control: filledFixture.control)
    XCTAssertEqual(filled.variant, .filled)
    XCTAssertEqual(filled.size, .large)
    XCTAssertEqual(filled.minimumSize, CGSize(width: 44, height: 44))
    XCTAssertEqual(filled.padding.top, 16)
    XCTAssertEqual(filled.padding.leading, 20)
    XCTAssertEqual(filled.borderRadius.uniform, 12)

    let tintedFixture = makeControl(
      type: "CupertinoTintedButton",
      properties: ["size": "medium", "disabled_bgcolor": "grey"])
    let tinted = RufletCupertinoButtonPresentation(control: tintedFixture.control)
    XCTAssertEqual(tinted.variant, .tinted)
    XCTAssertEqual(tinted.size, .medium)
    XCTAssertEqual(tinted.minimumSize, CGSize(width: 32, height: 32))
    XCTAssertEqual(tinted.padding.top, 10)
    XCTAssertEqual(tinted.padding.leading, 15)
    XCTAssertEqual(tinted.borderRadius.uniform, 40)
  }

  func testExplicitMinimumSizePaddingAndRadiusOverrideSizeStyleDefaults() {
    let fixture = makeControl(
      type: "CupertinoButton",
      properties: [
        "size": "small",
        "min_size": ["width": 80.0, "height": 36.0],
        "padding": ["left": 1.0, "top": 2.0, "right": 3.0, "bottom": 4.0],
        "border_radius": 7.0,
      ])
    let presentation = RufletCupertinoButtonPresentation(control: fixture.control)

    XCTAssertEqual(presentation.minimumSize, CGSize(width: 80, height: 36))
    XCTAssertEqual(presentation.padding.leading, 1)
    XCTAssertEqual(presentation.padding.top, 2)
    XCTAssertEqual(presentation.padding.trailing, 3)
    XCTAssertEqual(presentation.padding.bottom, 4)
    XCTAssertEqual(presentation.borderRadius.uniform, 7)
  }

  func testDisabledButtonHasNoActivationPath() {
    let fixture = makeControl(type: "CupertinoButton", properties: ["disabled": true])
    CupertinoButtonControl(control: fixture.control).pressed()
    XCTAssertTrue(fixture.backend.events.isEmpty)

    let enabledFixture = makeControl(type: "CupertinoButton", properties: [:])
    CupertinoButtonControl(control: enabledFixture.control).pressed()
    XCTAssertEqual(enabledFixture.backend.events, ["click"])
  }

  private func makeControl(
    type: String,
    properties: [String: RufletValue]
  ) -> (control: RufletControl, backend: CupertinoButtonBackend) {
    let backend = CupertinoButtonBackend()
    return (RufletControl(id: 72, type: type, properties: properties, backend: backend), backend)
  }
}

@MainActor
private final class CupertinoButtonBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var events: [String] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(name)
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(name)
  }

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
