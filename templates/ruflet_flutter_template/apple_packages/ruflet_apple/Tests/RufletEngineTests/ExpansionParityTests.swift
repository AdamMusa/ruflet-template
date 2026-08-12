import XCTest
import SwiftUI
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

    let reference = ControlNode(
      id: 4, type: "ExpansionTile", props: ["title": .controlRef(40)])
    XCTAssertEqual(
      ExpansionTilePresentation.validationMessage(
        reference, title: ControlNode(
          id: 40, type: "Text", props: ["visible": .bool(false)])),
      "ExpansionTile.title must be provided and visible")
    XCTAssertNil(ExpansionTilePresentation.validationMessage(
      reference, title: ControlNode(id: 40, type: "Text")))
    XCTAssertNil(ExpansionTilePresentation.validationMessage(ControlNode(
      id: 5, type: "ExpansionTile", props: ["title": .string("")])))
  }

  func testExpansionTileKeepsPinnedFlutterConstructorAndMaterial3ThemeDefaults() {
    let presentation = ExpansionTilePresentation(node: ControlNode(
      id: 1, type: "ExpansionTile", props: ["title": .string("Details")]))

    XCTAssertEqual(presentation.textColorToken, "onsurface")
    XCTAssertEqual(presentation.iconColorToken, "primary")
    XCTAssertEqual(presentation.collapsedTextColorToken, "onsurface")
    XCTAssertEqual(presentation.collapsedIconColorToken, "onsurfacevariant")
    XCTAssertEqual(presentation.backgroundColorToken, "transparent")
    XCTAssertEqual(presentation.collapsedBackgroundColorToken, "transparent")
    XCTAssertEqual(presentation.iconAffinityToken, "trailing")
    XCTAssertTrue(presentation.showsTrailingIcon)
    XCTAssertFalse(presentation.maintainState)
    XCTAssertTrue(presentation.enableFeedback)
    XCTAssertNil(presentation.dense)
    XCTAssertEqual(presentation.expandedAlignmentToken, "center")
    XCTAssertEqual(presentation.expandedCrossAxisAlignmentToken, "center")
    XCTAssertEqual(presentation.tilePadding.leading, 16)
    XCTAssertEqual(presentation.tilePadding.trailing, 16)
    XCTAssertEqual(presentation.controlsPadding, EdgeInsets())
    XCTAssertEqual(presentation.clipBehaviorToken, "antiAlias")
    XCTAssertNil(presentation.minTileHeight)
    XCTAssertEqual(presentation.effectiveMinimumTileHeight, 56)
    XCTAssertEqual(presentation.animationDuration, 0.2)
    XCTAssertEqual(presentation.animationCurveToken, "easein")
    XCTAssertEqual(presentation.reverseAnimationCurveToken, "easein")
    XCTAssertEqual(presentation.expandedShapeSemantic, "border.vertical(theme.dividerColor)")
    XCTAssertEqual(presentation.collapsedShapeSemantic, "border.vertical(transparent)")
  }

  func testExpansionTileListTileHeightDefaultsFollowSubtitleAndDenseSemantics() {
    XCTAssertEqual(ExpansionTilePresentation(node: ControlNode(
      id: 1, type: "ExpansionTile", props: [
        "title": .string("Details"), "subtitle": .string("More"),
      ])).effectiveMinimumTileHeight, 72)

    XCTAssertEqual(ExpansionTilePresentation(node: ControlNode(
      id: 2, type: "ExpansionTile", props: [
        "title": .string("Details"), "dense": .bool(true),
      ])).effectiveMinimumTileHeight, 48)

    XCTAssertEqual(ExpansionTilePresentation(node: ControlNode(
      id: 3, type: "ExpansionTile", props: [
        "title": .string("Details"), "subtitle": .string("More"), "dense": .bool(true),
      ])).effectiveMinimumTileHeight, 64)
  }

  func testExpansionTileExplicitPropertiesOverrideSemanticDefaults() {
    let presentation = ExpansionTilePresentation(node: ControlNode(
      id: 1, type: "ExpansionTile", props: [
        "title": .string("Details"),
        "expanded": .bool(true),
        "text_color": .string("red"),
        "icon_color": .string("blue"),
        "collapsed_text_color": .string("green"),
        "collapsed_icon_color": .string("orange"),
        "bgcolor": .string("white"),
        "collapsed_bgcolor": .string("black"),
        "affinity": .string("platform"),
        "show_trailing_icon": .bool(false),
        "maintain_state": .bool(true),
        "enable_feedback": .bool(false),
        "expanded_alignment": .string("bottomRight"),
        "expanded_cross_axis_alignment": .string("stretch"),
        "min_tile_height": .double(61),
        "clip_behavior": .string("hardEdge"),
        "tile_padding": .map(["left": .double(1), "right": .double(2)]),
        "controls_padding": .double(7),
        "shape": .map(["type": .string("roundedRectangle")]),
        "collapsed_shape": .map(["type": .string("stadium")]),
        "animation_style": .map([
          "duration": .double(450),
          "curve": .string("easeOut"),
          "reverse_curve": .string("linear"),
        ]),
      ]))

    XCTAssertEqual(presentation.textColorToken, "red")
    XCTAssertEqual(presentation.iconColorToken, "blue")
    XCTAssertEqual(presentation.collapsedTextColorToken, "green")
    XCTAssertEqual(presentation.collapsedIconColorToken, "orange")
    XCTAssertEqual(presentation.currentTextColorToken, "red")
    XCTAssertEqual(presentation.currentIconColorToken, "blue")
    XCTAssertEqual(presentation.currentBackgroundColorToken, "white")
    XCTAssertEqual(presentation.iconAffinityToken, "platform")
    XCTAssertFalse(presentation.showsTrailingIcon)
    XCTAssertTrue(presentation.maintainState)
    XCTAssertFalse(presentation.enableFeedback)
    XCTAssertEqual(presentation.expandedAlignmentToken, "bottomright")
    XCTAssertEqual(presentation.expandedCrossAxisAlignmentToken, "stretch")
    XCTAssertEqual(presentation.minTileHeight, 61)
    XCTAssertEqual(presentation.effectiveMinimumTileHeight, 61)
    XCTAssertEqual(presentation.clipBehaviorToken, "hardEdge")
    XCTAssertEqual(presentation.tilePadding.leading, 1)
    XCTAssertEqual(presentation.tilePadding.trailing, 2)
    XCTAssertEqual(presentation.controlsPadding.top, 7)
    XCTAssertEqual(presentation.animationDuration, 0.45)
    XCTAssertEqual(presentation.animationCurveToken, "easeout")
    XCTAssertEqual(presentation.reverseAnimationCurveToken, "linear")
    XCTAssertEqual(presentation.expandedShapeSemantic, "explicit")
    XCTAssertEqual(presentation.collapsedShapeSemantic, "explicit")
  }

  func testExpansionPanelKeepsFlutterConstructorDefaultsAndSlots() {
    let defaults = ExpansionPanelPresentation(node: ControlNode(id: 1, type: "ExpansionPanel"))
    XCTAssertFalse(defaults.expanded)
    XCTAssertFalse(defaults.canTapHeader)
    XCTAssertEqual(defaults.backgroundColorToken, "surface")
    XCTAssertNil(defaults.splashColorToken)
    XCTAssertNil(defaults.highlightColorToken)
    XCTAssertFalse(defaults.hasHeader)
    XCTAssertFalse(defaults.hasContent)

    let explicit = ExpansionPanelPresentation(node: ControlNode(
      id: 2, type: "ExpansionPanel", props: [
        "expanded": .bool(true),
        "can_tap_header": .bool(true),
        "bgcolor": .string("red"),
        "splash_color": .string("blue"),
        "highlight_color": .string("green"),
        "header": .controlRef(3),
        "content": .controlRef(4),
      ]))
    XCTAssertTrue(explicit.expanded)
    XCTAssertTrue(explicit.canTapHeader)
    XCTAssertEqual(explicit.backgroundColorToken, "red")
    XCTAssertEqual(explicit.splashColorToken, "blue")
    XCTAssertEqual(explicit.highlightColorToken, "green")
    XCTAssertTrue(explicit.hasHeader)
    XCTAssertTrue(explicit.hasContent)
  }

  func testExpansionPanelListKeepsFlutterConstructorAndThemeDefaults() {
    let presentation = ExpansionPanelListPresentation(node: ControlNode(
      id: 1, type: "ExpansionPanelList"))

    XCTAssertNil(presentation.validationMessage)
    XCTAssertEqual(presentation.elevation, 2)
    XCTAssertEqual(presentation.spacing, 16)
    XCTAssertEqual(presentation.expandedHeaderPadding.top, 16)
    XCTAssertEqual(presentation.expandedHeaderPadding.leading, 0)
    XCTAssertEqual(presentation.expandedHeaderPadding.bottom, 16)
    XCTAssertEqual(presentation.expandedHeaderPadding.trailing, 0)
    XCTAssertEqual(presentation.animationDuration, 0.2)
    XCTAssertEqual(presentation.dividerColorToken, "outline")
    XCTAssertNil(presentation.expandIconColorToken)
    XCTAssertEqual(
      presentation.defaultExpandIconColorSemantic,
      "black54(light)/white60(dark)")
  }

  func testExpansionPanelListMaterialGapMatchesFlutterAdjacencyRules() {
    let presentation = ExpansionPanelListPresentation(node: ControlNode(
      id: 1, type: "ExpansionPanelList"))

    XCTAssertFalse(presentation.hasGap(afterExpanded: false, beforeExpanded: false))
    XCTAssertTrue(presentation.hasGap(afterExpanded: true, beforeExpanded: false))
    XCTAssertTrue(presentation.hasGap(afterExpanded: false, beforeExpanded: true))
    XCTAssertTrue(presentation.hasGap(afterExpanded: true, beforeExpanded: true))
  }

  func testExpansionPanelListExplicitMetricsAndPublicIconKeyOverrideDefaults() {
    let presentation = ExpansionPanelListPresentation(node: ControlNode(
      id: 1, type: "ExpansionPanelList", props: [
        "elevation": .double(6),
        "spacing": .double(9),
        "divider_color": .string("red"),
        "expand_icon_color": .string("blue"),
        "expanded_header_padding": .map([
          "top": .double(1), "right": .double(2),
          "bottom": .double(3), "left": .double(4),
        ]),
      ]))

    XCTAssertEqual(presentation.elevation, 6)
    XCTAssertEqual(presentation.spacing, 9)
    XCTAssertEqual(presentation.dividerColorToken, "red")
    XCTAssertEqual(presentation.expandIconColorToken, "blue")
    XCTAssertEqual(presentation.expandedHeaderPadding.top, 1)
    XCTAssertEqual(presentation.expandedHeaderPadding.leading, 4)
    XCTAssertEqual(presentation.expandedHeaderPadding.bottom, 3)
    XCTAssertEqual(presentation.expandedHeaderPadding.trailing, 2)
  }

  func testExpansionPanelListAcceptsLegacyDartIconKeyAndRejectsNegativeElevation() {
    let legacy = ExpansionPanelListPresentation(node: ControlNode(
      id: 1, type: "ExpansionPanelList", props: [
        "expanded_icon_color": .string("orange"),
      ]))
    XCTAssertEqual(legacy.expandIconColorToken, "orange")

    let invalid = ExpansionPanelListPresentation(node: ControlNode(
      id: 2, type: "ExpansionPanelList", props: ["elevation": .double(-1)]))
    XCTAssertEqual(
      invalid.validationMessage,
      "ExpansionPanelList.elevation must be greater than or equal to zero")
  }
}
