import XCTest

import RufletEngine
import RufletProtocol

@testable import RufletUI

final class CheckboxNativeResidualTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "Checkbox", props: props)
  }

  func testNativeSymbolsPreserveAllThreeFletStates() {
    XCTAssertEqual(CheckboxPresentation(node: node()).systemImageName, "square")
    XCTAssertEqual(
      CheckboxPresentation(node: node(["value": .bool(true)])).systemImageName,
      "checkmark.square.fill")
    XCTAssertEqual(
      CheckboxPresentation(node: node(["tristate": .bool(true)])).systemImageName,
      "minus.square.fill")
  }

  func testOmittedAppearancePreservesNativeAppleTint() {
    XCTAssertNil(CheckboxPresentation(node: node()).explicitTint)
    XCTAssertNotNil(CheckboxPresentation(node: node([
      "value": .bool(true), "active_color": .string("red"),
    ])).explicitTint)
  }

  func testRendererUsesNativeButtonAndSymbolsWithoutMaterialBoxPainting() throws {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(contentsOf: package.appendingPathComponent(
      "Sources/RufletUI/Controls/InputControls.swift"))
    let start = try XCTUnwrap(source.range(of: "struct CheckboxControlView"))
    let end = try XCTUnwrap(source.range(of: "/// The checkbox's `bool?`", range: start.upperBound..<source.endIndex))
    let checkbox = source[start.lowerBound..<end.lowerBound]

    XCTAssertTrue(checkbox.contains("Button(action: advance)"))
    XCTAssertTrue(checkbox.contains("Image(systemName: presentation.systemImageName)"))
    XCTAssertFalse(checkbox.contains("MaterialStateLayer"))
    XCTAssertFalse(checkbox.contains("ChipShape"))
    XCTAssertFalse(checkbox.contains("strokeBorder"))
  }
}
