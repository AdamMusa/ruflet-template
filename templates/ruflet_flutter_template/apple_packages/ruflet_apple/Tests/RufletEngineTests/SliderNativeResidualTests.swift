import XCTest

import RufletEngine
import RufletProtocol

@testable import RufletUI

final class SliderNativeResidualTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "Slider", props: props)
  }

  func testNativeSliderPresentationPreservesRangeAndDivisions() {
    let presentation = SliderPresentation(node: node([
      "min": .double(-10), "max": .double(10), "value": .double(12),
      "divisions": .int(5),
    ]))
    XCTAssertEqual(presentation.minimum, -10)
    XCTAssertEqual(presentation.maximum, 10)
    XCTAssertEqual(presentation.value, 10)
    XCTAssertEqual(presentation.step, 4)
  }

  func testPinnedLabelTemplateRemainsModeled() {
    let presentation = SliderPresentation(node: node([
      "label": .string("Value {value}"), "round": .int(2),
    ]))
    XCTAssertEqual(presentation.label(for: 0.125), "Value 0.12")
  }

  func testOmittedAppearancePreservesNativeAppleTint() {
    XCTAssertNil(SliderPresentation(node: node()).explicitTint)
    XCTAssertNotNil(SliderPresentation(node: node([
      "active_color": .string("red"),
    ])).explicitTint)
  }

  func testSingleSliderUsesNativePrimitiveInsteadOfMaterialTrack() throws {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(contentsOf: package.appendingPathComponent(
      "Sources/RufletUI/Controls/InputControls.swift"))
    let start = try XCTUnwrap(source.range(of: "struct SliderControlView"))
    let end = try XCTUnwrap(source.range(of: "/// `RangeSlider`", range: start.upperBound..<source.endIndex))
    let slider = source[start.lowerBound..<end.lowerBound]

    XCTAssertTrue(slider.contains("Slider("))
    XCTAssertFalse(slider.contains("MaterialSliderTrack("))
    XCTAssertFalse(slider.contains("Capsule()"))
  }
}
