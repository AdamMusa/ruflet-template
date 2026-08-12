import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletUI

final class StackLayoutSemanticsParityTests: XCTestCase {
  func testRowOmittedValuesMatchPinnedFletDefaults() {
    let semantics = RufletLinearLayoutSemantics.row(ControlNode(id: 1, type: "Row"))

    XCTAssertEqual(semantics.mainAlignment, .start)
    XCTAssertEqual(semantics.crossAlignment, .center)
    XCTAssertEqual(semantics.wrapCrossAlignment, .center)
    XCTAssertEqual(semantics.runAlignment, .start)
    XCTAssertEqual(semantics.spacing, 10)
    XCTAssertEqual(semantics.runSpacing, 10)
    XCTAssertFalse(semantics.tight)
    XCTAssertFalse(semantics.wrap)
    XCTAssertFalse(semantics.intrinsic)
  }

  func testColumnOmittedValuesMatchPinnedFletDefaults() {
    let semantics = RufletLinearLayoutSemantics.column(ControlNode(id: 1, type: "Column"))

    XCTAssertEqual(semantics.mainAlignment, .start)
    XCTAssertEqual(semantics.crossAlignment, .start)
    XCTAssertEqual(semantics.wrapCrossAlignment, .start)
    XCTAssertEqual(semantics.runAlignment, .start)
    XCTAssertEqual(semantics.spacing, 10)
    XCTAssertEqual(semantics.runSpacing, 10)
    XCTAssertFalse(semantics.tight)
    XCTAssertFalse(semantics.wrap)
    XCTAssertFalse(semantics.intrinsic)
  }

  func testLinearLayoutExplicitWireValuesWin() {
    let row = ControlNode(
      id: 1, type: "Row",
      props: [
        "alignment": .string("spaceEvenly"),
        "vertical_alignment": .string("end"),
        "run_alignment": .string("center"),
        "spacing": .double(24),
        "run_spacing": .double(17),
        "tight": .bool(true),
        "wrap": .bool(true),
        "intrinsic_height": .bool(true),
      ])
    let semantics = RufletLinearLayoutSemantics.row(row)

    XCTAssertEqual(semantics.mainAlignment, .spaceEvenly)
    XCTAssertEqual(semantics.crossAlignment, .end)
    XCTAssertEqual(semantics.wrapCrossAlignment, .end)
    XCTAssertEqual(semantics.runAlignment, .center)
    XCTAssertEqual(semantics.spacing, 24)
    XCTAssertEqual(semantics.runSpacing, 17)
    XCTAssertTrue(semantics.tight)
    XCTAssertTrue(semantics.wrap)
    XCTAssertTrue(semantics.intrinsic)
  }

  func testStackOmittedAlignmentIsDirectionalTopStart() {
    let node = ControlNode(id: 1, type: "Stack")
    let leftToRight = RufletStackSemantics(node: node, layoutDirection: .leftToRight)
    let rightToLeft = RufletStackSemantics(node: node, layoutDirection: .rightToLeft)

    XCTAssertEqual(leftToRight.alignment, .topLeft)
    XCTAssertEqual(rightToLeft.alignment, .topRight)
    XCTAssertEqual(leftToRight.fit, .loose)
    XCTAssertEqual(leftToRight.clipBehavior, .hardEdge)
  }

  func testExplicitStackAlignmentRemainsAbsoluteInRTL() {
    let node = ControlNode(
      id: 1, type: "Stack",
      props: [
        "alignment": .map(["x": .double(-0.25), "y": .double(0.75)]),
        "fit": .string("expand"),
        "clip_behavior": .string("antiAliasWithSaveLayer"),
      ])
    let semantics = RufletStackSemantics(node: node, layoutDirection: .rightToLeft)

    XCTAssertEqual(semantics.alignment, RufletAlignment(x: -0.25, y: 0.75))
    XCTAssertEqual(semantics.fit, .expand)
    XCTAssertEqual(semantics.clipBehavior, .antiAliasWithSaveLayer)
  }

  func testStackClipBehaviorAcceptsFletSpellings() {
    XCTAssertEqual(RufletStackClipBehavior("none"), .none)
    XCTAssertEqual(RufletStackClipBehavior("hardEdge"), .hardEdge)
    XCTAssertEqual(RufletStackClipBehavior("anti_alias"), .antiAlias)
    XCTAssertEqual(
      RufletStackClipBehavior("anti_alias_with_save_layer"), .antiAliasWithSaveLayer)
    XCTAssertEqual(RufletStackClipBehavior("invalid"), .hardEdge)
  }

  func testResponsiveRowOmittedValuesMatchPinnedFletDefaults() {
    let semantics = RufletResponsiveRowSemantics(ControlNode(id: 1, type: "ResponsiveRow"))

    XCTAssertEqual(semantics.columns?.doubleValue, 12)
    XCTAssertEqual(semantics.spacing?.doubleValue, 10)
    XCTAssertEqual(semantics.runSpacing?.doubleValue, 10)
    XCTAssertEqual(semantics.breakpoints, ResponsiveGridMath.defaultBreakpoints)
    XCTAssertEqual(semantics.alignment, "start")
    XCTAssertEqual(semantics.verticalAlignment, "start")
  }

  func testExplicitEmptyBreakpointMapDoesNotBecomePageDefaults() {
    XCTAssertEqual(ResponsiveGridMath.breakpoints(.map([:])), [:])
  }

  func testBreakpointResolverStartsAtZeroLikeFlet() {
    let source: RufletValue = .map([
      "": .double(12),
      "negative": .double(6),
      "phone": .double(4),
    ])
    let breakpoints = ["negative": -100.0, "phone": 300.0]

    XCTAssertEqual(
      ResponsiveGridMath.value(source, default: 99, width: 100, breakpoints: breakpoints),
      12)
    XCTAssertEqual(
      ResponsiveGridMath.value(source, default: 99, width: 390, breakpoints: breakpoints),
      4)
  }

  func testInvalidResponsiveMapValueParsesAsZero() {
    let source: RufletValue = .map([
      "": .double(12),
      "sm": .string("not-a-number"),
    ])

    XCTAssertEqual(
      ResponsiveGridMath.value(
        source, default: 12, width: 700,
        breakpoints: ResponsiveGridMath.defaultBreakpoints),
      0)
  }
}
