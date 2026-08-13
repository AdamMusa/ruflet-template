import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class SliderPropertyConsumptionTests: XCTestCase {
  func testPresentationConsumesPinnedAppearanceAndInteractionContract() {
    let control = RufletControl(
      id: 1,
      type: "Slider",
      properties: [
        "min": -10,
        "max": 30,
        "value": 8,
        "divisions": 8,
        "round": 1,
        "label": "Value {value}",
        "autofocus": true,
        "active_color": "red",
        "inactive_color": "blue",
        "secondary_active_color": "green",
        "secondary_track_value": 22,
        "thumb_color": "purple",
        "overlay_color": ["dragged": "orange", "focused": "yellow"],
        "interaction": "slide_thumb",
        "padding": 12,
        "mouse_cursor": "click",
        "year_2023": false,
      ],
      backend: SliderTestBackend())

    let presentation = RufletSliderPresentation(control: control)
    XCTAssertEqual(presentation.minimum, -10)
    XCTAssertEqual(presentation.maximum, 30)
    XCTAssertEqual(presentation.value, 8)
    XCTAssertEqual(presentation.divisions, 8)
    XCTAssertEqual(presentation.label, "Value 8.0")
    XCTAssertTrue(presentation.autofocus)
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.inactiveColor)
    XCTAssertNotNil(presentation.secondaryActiveColor)
    XCTAssertEqual(presentation.secondaryTrackValue, 22)
    XCTAssertNotNil(presentation.thumbColor)
    XCTAssertNotNil(presentation.resolvedOverlay(focused: false, hovered: false, pressed: true))
    XCTAssertEqual(presentation.interaction, .slideThumb)
    XCTAssertEqual(presentation.padding.top, 12)
    XCTAssertEqual(presentation.mouseCursor, "click")
    XCTAssertFalse(presentation.usesLegacy2023Appearance)
    XCTAssertEqual(presentation.trackHeight, 16)
    XCTAssertEqual(presentation.thumbSize([]), CGSize(width: 4, height: 44))
    XCTAssertEqual(presentation.thumbSize([.pressed]), CGSize(width: 2, height: 44))
  }

  func testInteractionNamesAndDivisionSnappingMatchPinnedSlider() {
    XCTAssertEqual(RufletSliderInteraction(nil), .tapAndSlide)
    XCTAssertEqual(RufletSliderInteraction("tap_and_slide"), .tapAndSlide)
    XCTAssertEqual(RufletSliderInteraction("tap_only"), .tapOnly)
    XCTAssertEqual(RufletSliderInteraction("slide_only"), .slideOnly)
    XCTAssertEqual(RufletSliderInteraction("slide_thumb"), .slideThumb)

    XCTAssertEqual(
      rufletSliderSnap(13.9, minimum: -10, maximum: 30, divisions: 8),
      15)
    XCTAssertEqual(
      rufletSliderSnap(-100, minimum: -10, maximum: 30, divisions: 8),
      -10)
    XCTAssertEqual(
      rufletSliderSnap(100, minimum: -10, maximum: 30, divisions: nil),
      30)
  }

  func testSourceCarriesPinnedOriginalValueStartAndAllPropertyReads() throws {
    let source = try String(
      contentsOf: packageRoot.appendingPathComponent("Sources/RufletEngine/Controls/slider.swift"),
      encoding: .utf8)

    for property in [
      "autofocus", "inactive_color", "interaction", "mouse_cursor", "overlay_color",
      "secondary_active_color", "secondary_track_value", "thumb_color", "year_2023",
    ] {
      XCTAssertTrue(source.contains("\"\(property)\""), property)
    }
    XCTAssertTrue(source.contains("onChangeStart(presentation.value)"))
    XCTAssertTrue(source.contains("case .tapOnly:"))
    XCTAssertTrue(source.contains("case .slideOnly, .slideThumb:"))
  }

  private var packageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }
}

@MainActor
private final class SliderTestBackend: RufletBackendProtocol {
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
