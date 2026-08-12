import XCTest
@testable import RufletEngine
@testable import RufletUI

final class ExpansionParityTests: XCTestCase {
  func testExpansionTileImplementsFletValidationOrderAndMessages() {
    XCTAssertEqual(
      ExpansionTilePresentation.validationMessage(ControlNode(id: 1, type: "ExpansionTile")),
      "ExpansionTile.title must be provided and visible")

    let baseline = ControlNode(id: 2, type: "ExpansionTile", props: [
      "title": .string("Details"),
      "expanded_cross_axis_alignment": .string("baseline"),
    ])
    XCTAssertEqual(
      ExpansionTilePresentation.validationMessage(baseline),
      "CrossAxisAlignment.BASELINE is not supported since the expanded controls are aligned in a column, not a row. Try aligning the controls differently.")

    XCTAssertNil(ExpansionTilePresentation.validationMessage(ControlNode(
      id: 3, type: "ExpansionTile", props: ["title": .string("Details")])))
  }

  func testStylelessExpansionTileUsesAppleNativeDisclosureDefaults() {
    let presentation = ExpansionTilePresentation(node: ControlNode(
      id: 1, type: "ExpansionTile", props: ["title": .string("Details")]))

    XCTAssertFalse(presentation.requiresCustomRendering)
    XCTAssertNil(presentation.textColorToken)
    XCTAssertNil(presentation.iconColorToken)
    XCTAssertNil(presentation.collapsedTextColorToken)
    XCTAssertNil(presentation.collapsedIconColorToken)
    XCTAssertEqual(presentation.iconAffinityToken, "trailing")
    XCTAssertTrue(presentation.showsTrailingIcon)
    XCTAssertFalse(presentation.maintainState)
    XCTAssertTrue(presentation.enableFeedback)
    XCTAssertEqual(presentation.expandedAlignmentToken, "center")
    XCTAssertEqual(presentation.expandedCrossAxisAlignmentToken, "center")
    XCTAssertNil(presentation.minTileHeight)
    XCTAssertEqual(presentation.animationDuration, 0.2)
  }

  func testExpansionTileExplicitPropertiesOverrideConstructorDefaults() {
    let presentation = ExpansionTilePresentation(node: ControlNode(
      id: 1, type: "ExpansionTile", props: [
        "title": .string("Details"),
        "text_color": .string("red"),
        "icon_color": .string("blue"),
        "collapsed_text_color": .string("green"),
        "collapsed_icon_color": .string("orange"),
        "affinity": .string("leading"),
        "show_trailing_icon": .bool(false),
        "maintain_state": .bool(true),
        "enable_feedback": .bool(false),
        "expanded_alignment": .string("bottomRight"),
        "expanded_cross_axis_alignment": .string("stretch"),
        "min_tile_height": .double(61),
      ]))

    XCTAssertEqual(presentation.textColorToken, "red")
    XCTAssertEqual(presentation.iconColorToken, "blue")
    XCTAssertEqual(presentation.collapsedTextColorToken, "green")
    XCTAssertEqual(presentation.collapsedIconColorToken, "orange")
    XCTAssertEqual(presentation.iconAffinityToken, "leading")
    XCTAssertFalse(presentation.showsTrailingIcon)
    XCTAssertTrue(presentation.maintainState)
    XCTAssertFalse(presentation.enableFeedback)
    XCTAssertEqual(presentation.expandedAlignmentToken, "bottomright")
    XCTAssertEqual(presentation.expandedCrossAxisAlignmentToken, "stretch")
    XCTAssertEqual(presentation.minTileHeight, 61)
    XCTAssertTrue(presentation.requiresCustomRendering)
  }

  func testStylelessExpansionPanelListUsesAppleNativeDisclosureDefaults() {
    let presentation = ExpansionPanelListPresentation(node: ControlNode(
      id: 1, type: "ExpansionPanelList"))

    XCTAssertFalse(presentation.requiresCustomRendering)
    XCTAssertFalse(ExpansionPanelListPresentation.panelRequiresCustomRendering(
      ControlNode(id: 2, type: "ExpansionPanel")))
  }

  func testExpansionPanelListOnlyCreatesMaterialGapNextToExpandedPanel() {
    let presentation = ExpansionPanelListPresentation(node: ControlNode(
      id: 1, type: "ExpansionPanelList"))

    XCTAssertFalse(presentation.hasGap(afterExpanded: false, beforeExpanded: false))
    XCTAssertTrue(presentation.hasGap(afterExpanded: true, beforeExpanded: false))
    XCTAssertFalse(presentation.hasGap(afterExpanded: false, beforeExpanded: true))
    XCTAssertTrue(presentation.hasGap(afterExpanded: true, beforeExpanded: true))
  }

  func testExpansionPanelListExplicitMetricsOverrideFlutterDefaults() {
    let presentation = ExpansionPanelListPresentation(node: ControlNode(
      id: 1, type: "ExpansionPanelList", props: [
        "elevation": .double(6),
        "spacing": .double(9),
        "expanded_header_padding": .map([
          "top": .double(1), "right": .double(2),
          "bottom": .double(3), "left": .double(4),
        ]),
      ]))

    XCTAssertEqual(presentation.elevation, 6)
    XCTAssertEqual(presentation.spacing, 9)
    XCTAssertEqual(presentation.expandedHeaderPadding.top, 1)
    XCTAssertEqual(presentation.expandedHeaderPadding.leading, 4)
    XCTAssertEqual(presentation.expandedHeaderPadding.bottom, 3)
    XCTAssertEqual(presentation.expandedHeaderPadding.trailing, 2)
    XCTAssertTrue(presentation.requiresCustomRendering)
  }
}
