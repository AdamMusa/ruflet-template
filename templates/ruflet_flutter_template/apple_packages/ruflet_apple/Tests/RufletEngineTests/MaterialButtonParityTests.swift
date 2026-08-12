import XCTest
@testable import RufletEngine
@testable import RufletUI

final class MaterialButtonParityTests: XCTestCase {
  func testStylelessButtonsKeepTheirFlutterConstructorDefaults() {
    let expected: [(String, String, String, Double)] = [
      ("Button", "primary", "surfacecontainerlow", 1),
      ("FilledButton", "onprimary", "primary", 0),
      ("FilledTonalButton", "onsecondarycontainer", "secondarycontainer", 0),
      ("OutlinedButton", "primary", "transparent", 0),
      ("TextButton", "primary", "transparent", 0),
    ]
    for (type, foreground, background, elevation) in expected {
      let presentation = ButtonPresentation(
        node: ControlNode(id: 1, type: type), variant: ButtonVariant(wireType: type))
      XCTAssertFalse(presentation.hasExplicitStyle, type)
      XCTAssertEqual(presentation.foregroundToken, foreground, type)
      XCTAssertEqual(presentation.backgroundToken, background, type)
      XCTAssertEqual(presentation.elevation, elevation, type)
      XCTAssertEqual(presentation.minimumSize.minWidth, 64, type)
      XCTAssertEqual(presentation.minimumSize.minHeight, 40, type)
    }
  }

  func testExplicitEmptyStyleUsesFletParseButtonStyleDefaults() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let presentation = ButtonPresentation(
        node: ControlNode(id: 1, type: type, internals: ["style": .map([:])]),
        variant: ButtonVariant(wireType: type))
      XCTAssertTrue(presentation.hasExplicitStyle, type)
      XCTAssertEqual(presentation.foregroundToken, "primary", type)
      XCTAssertEqual(presentation.backgroundToken, "surface", type)
      XCTAssertEqual(presentation.elevation, 1, type)
      XCTAssertEqual(presentation.padding.leading, 8, type)
    }
  }

  func testButtonStyleCarriesFletSizeAndShapeProperties() {
    let presentation = ButtonPresentation(
      node: ControlNode(id: 1, type: "Button", internals: ["style": .map([
        "minimum_size": .map(["min_width": .double(80), "min_height": .double(44)]),
        "maximum_size": .map(["max_width": .double(180)]),
        "shape": .map(["radius": .double(7)]),
        "padding": .double(6),
      ])]),
      variant: .elevated)
    XCTAssertEqual(presentation.minimumSize.minWidth, 80)
    XCTAssertEqual(presentation.minimumSize.minHeight, 44)
    XCTAssertEqual(presentation.maximumSize?.maxWidth, 180)
    XCTAssertEqual(presentation.radius, 7)
    XCTAssertEqual(presentation.padding.leading, 6)
  }

  func testIconButtonVariantPalettesMatchMaterial3States() {
    XCTAssertEqual(
      IconButtonPresentation.palette(for: ControlNode(id: 1, type: "FilledIconButton")),
      .init(background: "primary", foreground: "onprimary", outline: nil))
    XCTAssertEqual(
      IconButtonPresentation.palette(for: ControlNode(
        id: 2, type: "OutlinedIconButton", props: ["selected": .bool(true)])),
      .init(background: "inversesurface", foreground: "oninversesurface", outline: nil))
  }

  func testFloatingActionGeometryUsesFlutterConstructorDefaults() {
    let normal = FloatingActionPresentation(node: ControlNode(id: 1, type: "FloatingActionButton"))
    let mini = FloatingActionPresentation(node: ControlNode(
      id: 2, type: "FloatingActionButton", props: ["mini": .bool(true)]))
    XCTAssertEqual(normal.side, 56)
    XCTAssertEqual(normal.radius, 16)
    XCTAssertEqual(mini.side, 40)
    XCTAssertEqual(mini.radius, 12)
  }

  func testSegmentedButtonImplementsFletValidationOrder() {
    let empty = ControlNode(id: 1, type: "SegmentedButton")
    XCTAssertEqual(
      SegmentedButtonPresentation.validationMessage(segmentCount: 0, selected: [], node: empty),
      "SegmentedButton.segments must be contain at least one visible segment")

    XCTAssertEqual(
      SegmentedButtonPresentation.validationMessage(
        segmentCount: 2, selected: [], node: ControlNode(id: 2, type: "SegmentedButton")),
      "SegmentedButton.selected must contain at least one value because allow_empty_selection=False")

    XCTAssertEqual(
      SegmentedButtonPresentation.validationMessage(
        segmentCount: 2, selected: ["a", "b"],
        node: ControlNode(id: 3, type: "SegmentedButton")),
      "SegmentedButton.selected must contain exactly one value because allow_multiple_selection=False")

    XCTAssertEqual(
      SegmentedButtonPresentation.validationMessage(
        segmentCount: 1, selected: ["a", "b"],
        node: ControlNode(id: 4, type: "SegmentedButton", props: [
          "allow_multiple_selection": .bool(true),
        ])),
      "The length of SegmentedButton.selected must be less than or equal to the number of visible segments")
  }

  func testChipResolvesRufletAndFletDeleteTooltipNames() {
    XCTAssertEqual(
      ChipPresentation.deleteTooltip(ControlNode(
        id: 1,
        type: "Chip",
        props: ["delete_icon_tooltip": .string("Remove")]
      )),
      "Remove"
    )
    XCTAssertEqual(
      ChipPresentation.deleteTooltip(ControlNode(
        id: 2,
        type: "Chip",
        props: ["delete_button_tooltip": .string("Delete")]
      )),
      "Delete"
    )
  }

  func testChipUsesFlutterMaterial3InputChipConstructorDefaults() {
    XCTAssertEqual(ChipPresentation.defaultCornerRadius, 8)
    XCTAssertEqual(ChipPresentation.defaultPadding, 8)
    XCTAssertEqual(ChipPresentation.defaultIconSize, 18)
    XCTAssertEqual(ChipPresentation.selectedColorToken, "secondarycontainer")

    let resting = ControlNode(id: 1, type: "Chip", props: ["label": .string("A")])
    XCTAssertEqual(ChipPresentation.labelColorToken(resting), "onsurfacevariant")
    XCTAssertEqual(ChipPresentation.deleteIconColorToken(resting), "onsurfacevariant")
    XCTAssertEqual(ChipPresentation.borderColorToken(resting), "outlinevariant")

    let selected = ControlNode(
      id: 2, type: "Chip",
      props: ["label": .string("A"), "selected": .bool(true)])
    XCTAssertEqual(ChipPresentation.labelColorToken(selected), "onsecondarycontainer")
    XCTAssertEqual(ChipPresentation.checkmarkColorToken(selected), "primary")
    XCTAssertEqual(ChipPresentation.deleteIconColorToken(selected), "onsecondarycontainer")
    XCTAssertEqual(ChipPresentation.borderColorToken(selected), "transparent")
  }

  func testChipEnforcesFletInputChipValidation() {
    XCTAssertEqual(
      ChipPresentation.validationMessage(ControlNode(id: 1, type: "Chip")),
      "Chip.label must be provided and visible")

    let conflicting = ControlNode(
      id: 2, type: "Chip",
      props: [
        "label": .string("A"),
        "on_select": .bool(true),
        "on_click": .bool(true),
      ])
    XCTAssertEqual(
      ChipPresentation.validationMessage(conflicting),
      "Chip cannot have both on_select and on_click events specified")
  }
}
