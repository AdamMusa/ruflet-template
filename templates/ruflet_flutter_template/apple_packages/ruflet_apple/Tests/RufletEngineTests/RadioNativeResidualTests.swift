import XCTest

import RufletEngine
import RufletProtocol

@testable import RufletUI

final class RadioNativeResidualTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "Radio", props: props)
  }

  func testNativeSymbolsPreserveSelectedAndUnselectedStates() {
    XCTAssertEqual(RadioPresentation(node: node(), selected: false).systemImageName, "circle")
    XCTAssertEqual(
      RadioPresentation(node: node(), selected: true).systemImageName,
      "circle.inset.filled")
  }

  func testOmittedAppearancePreservesNativeAppleTint() {
    XCTAssertNil(RadioPresentation(node: node(), selected: false).explicitTint)
    XCTAssertNil(RadioPresentation(node: node(), selected: true).explicitTint)
    XCTAssertNotNil(RadioPresentation(
      node: node(["active_color": .string("red")]), selected: true).explicitTint)
  }

  func testPinnedLabelPositionDefaultsToTheRight() {
    XCTAssertEqual(RadioPresentation(node: node(), selected: false).labelPosition, .right)
    XCTAssertEqual(RadioPresentation(
      node: node(["label_position": .string("left")]), selected: false).labelPosition, .left)
  }

  func testRendererUsesNativeButtonAndSymbolsWithoutMaterialCirclePainting() throws {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(contentsOf: package.appendingPathComponent(
      "Sources/RufletUI/Controls/InputControls.swift"))
    let start = try XCTUnwrap(source.range(of: "struct RadioControlView"))
    let end = try XCTUnwrap(source.range(of: "/// Resolves the inherited `RadioGroup`", range: start.upperBound..<source.endIndex))
    let radio = source[start.lowerBound..<end.lowerBound]

    XCTAssertTrue(radio.contains("Button { select(toggleIfSelected: true) }"))
    XCTAssertTrue(radio.contains("Image(systemName: presentation.systemImageName)"))
    XCTAssertFalse(radio.contains("MaterialStateLayer"))
    XCTAssertFalse(radio.contains("Circle().strokeBorder"))
    XCTAssertFalse(radio.contains("Circle()"))
  }
}
