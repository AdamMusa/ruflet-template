import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletUI

final class ContainerPrimitiveParityTests: XCTestCase {
  private func node(_ type: String, _ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: type, props: props)
  }

  func testSafeAreaUsesPinnedFletDefaultsAndMaxesMinimumInsets() {
    let safeArea = node("SafeArea")
    XCTAssertTrue(safeArea.rufletBool("avoid_intrusions_left"))
    XCTAssertTrue(safeArea.rufletBool("avoid_intrusions_top"))
    XCTAssertTrue(safeArea.rufletBool("avoid_intrusions_right"))
    XCTAssertTrue(safeArea.rufletBool("avoid_intrusions_bottom"))
    XCTAssertFalse(safeArea.rufletBool("maintain_bottom_view_padding"))
    XCTAssertEqual(
      SafeAreaInsetMath.missingContentError,
      "SafeArea.content must be provided and visible")
    XCTAssertEqual(
      RufletRequiredContent.validationError(
        contentID: 2,
        content: ControlNode(
          id: 2, type: "Container", props: ["visible": .bool(false)]),
        message: SafeAreaInsetMath.missingContentError),
      SafeAreaInsetMath.missingContentError)
    XCTAssertNil(
      RufletRequiredContent.validationError(
        contentID: 2, content: ControlNode(id: 2, type: "Container"),
        message: SafeAreaInsetMath.missingContentError))

    let result = SafeAreaInsetMath.resolved(
      safeArea: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0),
      minimum: EdgeInsets(top: 8, leading: 12, bottom: 40, trailing: 16),
      left: true, top: false, right: true, bottom: true)
    XCTAssertEqual(result, EdgeInsets(top: 8, leading: 12, bottom: 40, trailing: 16))
  }

  func testDividerUsesFlutter338Material3Defaults() {
    let horizontal = DividerGeometry.metrics(
      node: node("Divider"), isVertical: false, displayScale: 3)
    XCTAssertEqual(horizontal.extent, 16)
    XCTAssertEqual(horizontal.thickness, 1)
    XCTAssertEqual(horizontal.leadingIndent, 0)
    XCTAssertEqual(horizontal.trailingIndent, 0)
    XCTAssertEqual(horizontal.colorToken, "outlinevariant")

    let vertical = DividerGeometry.metrics(
      node: node("VerticalDivider"), isVertical: true, displayScale: 3)
    XCTAssertEqual(vertical.extent, 16)
    XCTAssertEqual(vertical.thickness, 1)
    XCTAssertEqual(vertical.colorToken, "outlinevariant")
  }

  func testExplicitZeroDividerThicknessIsADevicePixel() {
    let metrics = DividerGeometry.metrics(
      node: node(
        "VerticalDivider",
        [
          "width": .double(28),
          "thickness": .double(0),
          "leading_indent": .double(3),
          "trailing_indent": .double(5),
          "color": .string("red"),
        ]),
      isVertical: true,
      displayScale: 3)
    XCTAssertEqual(metrics.extent, 28)
    XCTAssertEqual(metrics.thickness, 1.0 / 3.0, accuracy: 0.000_001)
    XCTAssertEqual(metrics.leadingIndent, 3)
    XCTAssertEqual(metrics.trailingIndent, 5)
    XCTAssertEqual(metrics.colorToken, "red")
  }

  func testPlaceholderUsesFlutterConstructorDefaults() {
    let defaults = PlaceholderGeometry.metrics(node("Placeholder"))
    XCTAssertEqual(defaults.fallbackWidth, 400)
    XCTAssertEqual(defaults.fallbackHeight, 400)
    XCTAssertEqual(defaults.strokeWidth, 2)
    XCTAssertEqual(defaults.colorToken, "#ff455a64")

    let explicit = PlaceholderGeometry.metrics(
      node(
        "Placeholder",
        [
          "fallback_width": .double(120),
          "fallback_height": .double(80),
          "stroke_width": .double(4),
          "color": .string("blue"),
        ]))
    XCTAssertEqual(explicit.fallbackWidth, 120)
    XCTAssertEqual(explicit.fallbackHeight, 80)
    XCTAssertEqual(explicit.strokeWidth, 4)
    XCTAssertEqual(explicit.colorToken, "blue")
  }

  func testRotatedBoxDefaultsAndQuarterTurnLayoutMatchFlutter() {
    XCTAssertEqual(RotatedQuarterTurnMath.quarterTurns(node("RotatedBox")), 0)
    XCTAssertEqual(
      RotatedQuarterTurnMath.quarterTurns(
        node("RotatedBox", ["quarter_turns": .int(-1)])),
      -1)
    XCTAssertEqual(RotatedQuarterTurnMath.normalized(-1), 3)
    XCTAssertTrue(RotatedQuarterTurnMath.swapsAxes(-1))
    XCTAssertFalse(RotatedQuarterTurnMath.swapsAxes(2))
    XCTAssertEqual(
      RotatedQuarterTurnMath.outputSize(
        CGSize(width: 120, height: 40), quarterTurns: 1),
      CGSize(width: 40, height: 120))
  }
}
