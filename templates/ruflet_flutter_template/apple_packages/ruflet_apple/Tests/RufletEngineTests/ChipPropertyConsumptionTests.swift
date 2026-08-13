import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class ChipPropertyConsumptionTests: XCTestCase {
  private let backend = ChipPropertyTestBackend()

  func testChipStateColorAndSelectedShadowFollowPinnedPrecedence() {
    let control = RufletControl(
      id: 91,
      type: "Chip",
      properties: [
        "color": [
          "default": "#111111",
          "selected": "#222222",
        ],
        "shadow_color": "#333333",
        "selected_shadow_color": "#444444",
        "selected": true,
      ],
      backend: backend)

    let selected = RufletChipPresentation(
      control: control, selected: true, focused: false, hovered: false)
    let ordinary = RufletChipPresentation(
      control: control, selected: false, focused: false, hovered: false)

    XCTAssertNotNil(selected.backgroundColor)
    XCTAssertNotNil(selected.shadowColor)
    XCTAssertNotNil(ordinary.backgroundColor)
    XCTAssertNotNil(ordinary.shadowColor)
  }

  func testChipAnimationAndDensityContractsAreParsed() {
    let control = RufletControl(
      id: 92,
      type: "Chip",
      properties: [
        "enable_animation_style": ["duration": 100, "curve": "linear"],
        "leading_drawer_animation_style": ["duration": 120, "curve": "easeout"],
        "delete_drawer_animation_style": ["duration": 140, "curve": "easein"],
        "elevation_on_click": 7,
        "visual_density": "compact",
        "delete_icon_tooltip": "Remove item",
      ],
      backend: backend)
    let presentation = RufletChipPresentation(
      control: control, selected: false, focused: false, hovered: false)

    XCTAssertEqual(presentation.pressElevation, 7)
    XCTAssertEqual(presentation.densityPadding.leading, -4)
    XCTAssertEqual(presentation.deleteTooltip, "Remove item")
  }
}

@MainActor
private final class ChipPropertyTestBackend: RufletBackendProtocol {
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
