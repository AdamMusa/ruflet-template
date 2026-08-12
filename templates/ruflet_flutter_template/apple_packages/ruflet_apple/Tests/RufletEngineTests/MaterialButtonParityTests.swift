import XCTest
@testable import RufletEngine
@testable import RufletUI

final class MaterialButtonParityTests: XCTestCase {
  func testStylelessButtonsUseTheirAppleNativeFamiliesWithoutInjectedColors() {
    let expected: [(String, NativeButtonAppearance)] = [
      ("Button", .automatic),
      ("FilledButton", .borderedProminent),
      ("FilledTonalButton", .bordered),
      ("OutlinedButton", .bordered),
      ("TextButton", .plain),
    ]
    for (type, appearance) in expected {
      let presentation = ButtonPresentation(
        node: ControlNode(id: 1, type: type), variant: ButtonVariant(wireType: type))
      XCTAssertFalse(presentation.hasExplicitStyle, type)
      XCTAssertFalse(presentation.requiresCustomStyle, type)
      XCTAssertEqual(NativeButtonAppearance.resolve(ButtonVariant(wireType: type)), appearance)
      XCTAssertNil(presentation.color("color"), type)
      XCTAssertNil(presentation.color("bgcolor"), type)
    }
  }

  func testEmptyStyleDoesNotReplaceAppleNativeDefaults() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let presentation = ButtonPresentation(
        node: ControlNode(id: 1, type: type, internals: ["style": .map([:])]),
        variant: ButtonVariant(wireType: type))
      XCTAssertTrue(presentation.hasExplicitStyle, type)
      XCTAssertFalse(presentation.requiresCustomStyle, type)
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

  func testStylelessIconButtonsUseNativeCircularButtonFamilies() {
    for type in ["IconButton", "FilledIconButton", "FilledTonalIconButton", "OutlinedIconButton"] {
      XCTAssertFalse(IconButtonPresentation(
        node: ControlNode(id: 1, type: type)).requiresCustomRendering, type)
    }
    XCTAssertEqual(NativeButtonAppearance.resolve(.icon), .borderless)
    XCTAssertEqual(NativeButtonAppearance.resolve(.filledIcon), .borderedProminent)
    XCTAssertEqual(NativeButtonAppearance.resolve(.outlinedIcon), .bordered)
  }

  func testFloatingActionButtonUsesNativeProminentButtonUntilVisualsAreExplicit() {
    let normal = FloatingActionPresentation(node: ControlNode(id: 1, type: "FloatingActionButton"))
    let mini = FloatingActionPresentation(node: ControlNode(
      id: 2, type: "FloatingActionButton", props: ["mini": .bool(true)]))
    XCTAssertFalse(normal.requiresCustomRendering)
    XCTAssertFalse(mini.requiresCustomRendering)
    XCTAssertEqual(NativeButtonAppearance.resolve(.floatingAction), .borderedProminent)

    let shaped = FloatingActionPresentation(node: ControlNode(
      id: 3, type: "FloatingActionButton", props: ["shape": .map(["radius": .double(6)])]))
    XCTAssertTrue(shaped.requiresCustomRendering)
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
