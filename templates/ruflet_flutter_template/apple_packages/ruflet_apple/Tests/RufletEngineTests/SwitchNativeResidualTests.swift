import XCTest

import RufletEngine
import RufletProtocol

@testable import RufletUI

final class SwitchNativeResidualTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "Switch", props: props)
  }

  func testSwitchLabelAcceptsOnlyStringOrResolvedVisibleControl() {
    XCTAssertEqual(SwitchPresentation(node: node(["label": .string("")]), labelNode: nil).labelText, "")
    XCTAssertNil(SwitchPresentation(node: node(["label": .int(7)]), labelNode: nil).labelText)

    let visible = ControlNode(id: 2, type: "Text")
    let hidden = ControlNode(id: 2, type: "Text", props: ["visible": .bool(false)])
    let control = node(["label": .controlRef(2)])
    XCTAssertEqual(SwitchPresentation(node: control, labelNode: visible).labelControlID, 2)
    XCTAssertNil(SwitchPresentation(node: control, labelNode: hidden).labelControlID)
    XCTAssertNil(SwitchPresentation(node: control, labelNode: nil).labelControlID)
  }

  func testSwitchKeepsPinnedLabelPositionDefault() {
    XCTAssertEqual(SwitchPresentation(node: node(), labelNode: nil).labelPosition, .right)
    XCTAssertEqual(
      SwitchPresentation(node: node(["label_position": .string("left")]), labelNode: nil)
        .labelPosition,
      .left)
  }

  func testOmittedAppearanceDoesNotOverrideNativeAppleTint() {
    XCTAssertNil(SwitchPresentation(node: node(), labelNode: nil).explicitTrackColor)
    XCTAssertNotNil(
      SwitchPresentation(
        node: node(["value": .bool(true), "active_track_color": .string("red")]),
        labelNode: nil
      ).explicitTrackColor)
  }

  func testRendererUsesNativeSwitchWithoutHandDrawnMaterialChrome() throws {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(contentsOf: package.appendingPathComponent(
      "Sources/RufletUI/Controls/InputControls.swift"))
    let start = try XCTUnwrap(source.range(of: "struct SwitchControlView"))
    let end = try XCTUnwrap(source.range(of: "/// `Checkbox`", range: start.upperBound..<source.endIndex))
    let switchSource = source[start.lowerBound..<end.lowerBound]

    XCTAssertTrue(switchSource.contains("Toggle(\"\", isOn: binding)"))
    XCTAssertTrue(switchSource.contains(".toggleStyle(.switch)"))
    XCTAssertFalse(switchSource.contains("struct MaterialSwitch"))
    XCTAssertFalse(switchSource.contains("Capsule()"))
    XCTAssertFalse(switchSource.contains("Circle()"))
  }
}
