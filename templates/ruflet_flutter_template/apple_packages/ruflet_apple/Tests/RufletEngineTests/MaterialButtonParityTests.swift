import XCTest
@testable import RufletEngine
@testable import RufletUI

final class MaterialButtonParityTests: XCTestCase {
  func testButtonVariantsUsePinnedFletStyleDefaults() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let node = ControlNode(id: 1, type: type)
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "color"), "primary")
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "bgcolor"), "surface")
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "overlay_color"), "primary,0.08")
    }
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
