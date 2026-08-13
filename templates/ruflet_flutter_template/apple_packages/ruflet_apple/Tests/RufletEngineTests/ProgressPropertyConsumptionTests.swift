import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class ProgressPropertyConsumptionTests: XCTestCase {
  private let backend = ProgressPropertyTestBackend()

  func testProgressBarConsumesStopTrackAndLegacyAppearance() {
    let control = RufletControl(
      id: 101,
      type: "ProgressBar",
      properties: [
        "value": 0.5,
        "stop_indicator_color": "#ff0000",
        "stop_indicator_radius": 3,
        "track_gap": 2,
        "year_2023": true,
      ],
      backend: backend)
    let presentation = RufletProgressBarPresentation(control: control)

    XCTAssertEqual(presentation.value, 0.5)
    XCTAssertEqual(presentation.stopIndicatorRadius, 3)
    XCTAssertEqual(presentation.trackGap, 2)
    XCTAssertTrue(presentation.usesLegacy2023Appearance)
    XCTAssertNotNil(presentation.stopIndicatorColor)
  }

  func testProgressRingConsumesStrokeGeometryAndConstraints() {
    let control = RufletControl(
      id: 102,
      type: "ProgressRing",
      properties: [
        "stroke_width": 7,
        "stroke_align": -1,
        "stroke_cap": "round",
        "track_gap": 8,
        "size_constraints": [
          "min_width": 20,
          "max_width": 80,
          "min_height": 24,
          "max_height": 84,
        ],
        "year2023": true,
      ],
      backend: backend)
    let presentation = RufletProgressRingPresentation(control: control)

    XCTAssertEqual(presentation.strokeWidth, 7)
    XCTAssertEqual(presentation.strokeAlign, -1)
    XCTAssertEqual(presentation.strokeCap, .round)
    XCTAssertEqual(presentation.trackGap, 8)
    XCTAssertEqual(presentation.minWidth, 20)
    XCTAssertEqual(presentation.maxHeight, 84)
    XCTAssertTrue(presentation.usesLegacy2023Appearance)
  }
}

@MainActor
private final class ProgressPropertyTestBackend: RufletBackendProtocol {
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
