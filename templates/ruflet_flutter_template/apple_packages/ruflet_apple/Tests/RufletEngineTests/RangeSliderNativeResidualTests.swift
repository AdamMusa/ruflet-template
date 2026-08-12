import XCTest

import RufletEngine
import RufletProtocol

@testable import RufletUI

final class RangeSliderNativeResidualTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "RangeSlider", props: props)
  }

  func testPresentationClampsOrderedValuesAndPreservesDivisions() {
    let presentation = RangeSliderPresentation(node: node([
      "min": .double(0), "max": .double(20), "start_value": .double(-1),
      "end_value": .double(25), "divisions": .int(4),
    ]))
    XCTAssertEqual(presentation.start, 0)
    XCTAssertEqual(presentation.end, 20)
    XCTAssertEqual(presentation.step, 5)
  }

  func testBothPinnedLabelTemplatesRemainModeled() {
    let presentation = RangeSliderPresentation(node: node([
      "start_value": .double(0.25), "end_value": .double(0.75),
      "label": .string("{value}"), "round": .int(1),
    ]))
    XCTAssertEqual(presentation.labels, ["0.2", "0.8"])
  }

  func testOmittedAppearancePreservesNativeAppleTint() {
    XCTAssertNil(RangeSliderPresentation(node: node()).explicitTint)
    XCTAssertNotNil(RangeSliderPresentation(node: node([
      "active_color": .string("red"),
    ])).explicitTint)
  }

  func testRangeUsesNativeSliderCompositionWithoutMaterialTrackPainting() throws {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(contentsOf: package.appendingPathComponent(
      "Sources/RufletUI/Controls/InputControls.swift"))
    let start = try XCTUnwrap(source.range(of: "struct RangeSliderControlView"))
    let end = try XCTUnwrap(source.range(of: "/// `TextField`", range: start.upperBound..<source.endIndex))
    let range = source[start.lowerBound..<end.lowerBound]

    XCTAssertTrue(range.contains("Slider(value: value"))
    XCTAssertFalse(range.contains("MaterialSliderTrack"))
    XCTAssertFalse(range.contains("Capsule()"))
    XCTAssertFalse(range.contains("DragGesture"))
  }
}
