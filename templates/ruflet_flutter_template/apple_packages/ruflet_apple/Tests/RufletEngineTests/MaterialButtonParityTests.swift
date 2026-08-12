import RufletProtocol
import XCTest

@testable import RufletEngine
@testable import RufletUI

final class MaterialButtonParityTests: XCTestCase {
  func testStylelessButtonsUseNativeFamiliesWithFlutterConstructorSemantics() {
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
      XCTAssertNotNil(presentation.color("color"), type)
      XCTAssertNotNil(presentation.color("bgcolor"), type)
      XCTAssertEqual(presentation.minimumSize.minWidth, 64, type)
      XCTAssertEqual(presentation.minimumSize.minHeight, 40, type)
      XCTAssertEqual(presentation.radius, 20, type)
    }
  }

  func testEmptyStyleStillConstructsFletDefaultButtonStyle() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let presentation = ButtonPresentation(
        node: ControlNode(id: 1, type: type, internals: ["style": .map([:])]),
        variant: ButtonVariant(wireType: type))
      XCTAssertTrue(presentation.hasExplicitStyle, type)
      XCTAssertTrue(presentation.requiresCustomStyle, type)
    }
  }

  func testButtonStyleCarriesFletSizeAndShapeProperties() {
    let presentation = ButtonPresentation(
      node: ControlNode(
        id: 1, type: "Button",
        internals: [
          "style": .map([
            "minimum_size": .map(["min_width": .double(80), "min_height": .double(44)]),
            "maximum_size": .map(["max_width": .double(180)]),
            "shape": .map(["radius": .double(7)]),
            "padding": .double(6),
          ])
        ]),
      variant: .elevated)
    XCTAssertEqual(presentation.minimumSize.minWidth, 80)
    XCTAssertEqual(presentation.minimumSize.minHeight, 44)
    XCTAssertEqual(presentation.maximumSize?.maxWidth, 180)
    XCTAssertEqual(presentation.radius, 7)
    XCTAssertEqual(presentation.padding.leading, 6)
  }

  func testButtonStyleCarriesFletIconSemantics() {
    let presentation = ButtonPresentation(
      node: ControlNode(
        id: 1, type: "Button",
        internals: [
          "style": .map([
            "icon_size": .double(22),
            "icon_color": .string("red"),
          ])
        ]),
      variant: .elevated)
    XCTAssertEqual(presentation.iconSize, 22)
    XCTAssertNotNil(presentation.iconColor)
  }

  func testStylelessIconButtonsUseNativeCircularButtonFamilies() {
    for type in ["IconButton", "FilledIconButton", "FilledTonalIconButton", "OutlinedIconButton"] {
      XCTAssertFalse(
        IconButtonPresentation(
          node: ControlNode(id: 1, type: type)
        ).requiresCustomRendering, type)
    }
    XCTAssertEqual(NativeButtonAppearance.resolve(.icon), .borderless)
    XCTAssertEqual(NativeButtonAppearance.resolve(.filledIcon), .borderedProminent)
    XCTAssertEqual(NativeButtonAppearance.resolve(.outlinedIcon), .bordered)

    let styleless = IconButtonPresentation(
      node: ControlNode(id: 2, type: "IconButton", props: ["icon": .string("add")]))
    XCTAssertEqual(styleless.padding.leading, 8)
    XCTAssertEqual(styleless.padding.top, 8)
    XCTAssertEqual(styleless.constraints.minWidth, 40)
    XCTAssertEqual(styleless.constraints.minHeight, 40)
    XCTAssertEqual(styleless.iconSize, 24)

    let styled = IconButtonPresentation(
      node: ControlNode(
        id: 3, type: "IconButton", props: ["icon": .string("add")],
        internals: ["style": .map(["icon_size": .double(19)])]))
    XCTAssertEqual(styled.iconSize, 19)
  }

  func testFloatingActionButtonRetainsFletSemanticsOnNativeProminentButton() {
    let normal = FloatingActionPresentation(node: ControlNode(id: 1, type: "FloatingActionButton"))
    let mini = FloatingActionPresentation(
      node: ControlNode(
        id: 2, type: "FloatingActionButton", props: ["mini": .bool(true)]))
    XCTAssertFalse(normal.requiresCustomRendering)
    XCTAssertFalse(mini.requiresCustomRendering)
    XCTAssertEqual(NativeButtonAppearance.resolve(.floatingAction), .borderedProminent)
    XCTAssertEqual(normal.width, 56)
    XCTAssertEqual(normal.height, 56)
    XCTAssertEqual(mini.width, 40)
    XCTAssertEqual(mini.height, 40)
    XCTAssertNotNil(normal.background)
    XCTAssertNotNil(normal.foreground)

    let shaped = FloatingActionPresentation(
      node: ControlNode(
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
      "SegmentedButton.selected must contain at least one value because allow_empty_selection=False"
    )

    XCTAssertEqual(
      SegmentedButtonPresentation.validationMessage(
        segmentCount: 2, selected: ["a", "b"],
        node: ControlNode(id: 3, type: "SegmentedButton")),
      "SegmentedButton.selected must contain exactly one value because allow_multiple_selection=False"
    )

    XCTAssertEqual(
      SegmentedButtonPresentation.validationMessage(
        segmentCount: 1, selected: ["a", "b"],
        node: ControlNode(
          id: 4, type: "SegmentedButton",
          props: [
            "allow_multiple_selection": .bool(true)
          ])),
      "The length of SegmentedButton.selected must be less than or equal to the number of visible segments"
    )
  }

  func testSegmentedButtonUsesNativeAppleRoutesUntilVisualStyleIsExplicit() {
    XCTAssertEqual(
      SegmentedButtonPresentation(
        node: ControlNode(
          id: 1, type: "SegmentedButton",
          props: [
            "selected": .array([.string("one")])
          ])
      ).route,
      .picker)

    let nativeGroupProps: [[String: RufletValue]] = [
      ["selected": .array([.string("one")]), "allow_empty_selection": .bool(true)],
      ["selected": .array([.string("one")]), "allow_multiple_selection": .bool(true)],
      ["selected": .array([.string("one")]), "direction": .string("vertical")],
    ]
    for props in nativeGroupProps {
      XCTAssertEqual(
        SegmentedButtonPresentation(
          node: ControlNode(
            id: 2, type: "SegmentedButton", props: props)
        ).route,
        .buttonGroup)
    }

    XCTAssertEqual(
      SegmentedButtonPresentation(
        node: ControlNode(
          id: 3, type: "SegmentedButton",
          props: ["selected": .array([.string("one")])],
          internals: ["style": .map(["bgcolor": .string("red")])])
      ).route,
      .buttonGroup)
  }

  func testChipResolvesRufletAndFletDeleteTooltipNames() {
    XCTAssertEqual(
      ChipPresentation.deleteTooltip(
        ControlNode(
          id: 1,
          type: "Chip",
          props: ["delete_icon_tooltip": .string("Remove")]
        )),
      "Remove"
    )
    XCTAssertEqual(
      ChipPresentation.deleteTooltip(
        ControlNode(
          id: 2,
          type: "Chip",
          props: ["delete_button_tooltip": .string("Delete")]
        )),
      "Delete"
    )
  }

  func testStylelessChipRetainsInputChipDefaultsOnNativeAppleButton() {
    let styleless = ControlNode(id: 1, type: "Chip", props: ["label": .string("A")])
    XCTAssertFalse(ChipPresentation.requiresCustomRendering(styleless))
    XCTAssertNotNil(ChipPresentation.foreground(styleless))
    XCTAssertEqual(ChipPresentation.padding(styleless).leading, 8)
    XCTAssertEqual(ChipPresentation.labelPadding(styleless).leading, 8)
    XCTAssertNil(ChipPresentation.background(styleless))

    let selected = ControlNode(
      id: 3, type: "Chip",
      props: ["label": .string("A"), "selected": .bool(true)])
    XCTAssertNotNil(ChipPresentation.background(selected))

    let disabled = ControlNode(
      id: 4, type: "Chip",
      props: ["label": .string("A"), "disabled": .bool(true)])
    XCTAssertNil(ChipPresentation.background(disabled))

    let selectedDisabled = ControlNode(
      id: 5, type: "Chip",
      props: [
        "label": .string("A"), "selected": .bool(true), "disabled": .bool(true)
      ])
    XCTAssertNotNil(ChipPresentation.background(selectedDisabled))

    let explicitChipVisuals: [(String, RufletValue)] = [
      ("bgcolor", .string("red")),
      ("shape", .map(["radius": .double(8)])),
      ("padding", .double(6)),
      ("label_text_style", .map(["size": .double(12)])),
    ]
    for (key, value) in explicitChipVisuals {
      XCTAssertTrue(
        ChipPresentation.requiresCustomRendering(
          ControlNode(
            id: 2, type: "Chip", props: ["label": .string("A"), key: value])), key)
    }
  }

  func testExplicitChipVisualsRetainFlutterMaterial3ConstructorDefaults() {
    XCTAssertEqual(ChipPresentation.defaultCornerRadius, 8)
    XCTAssertEqual(ChipPresentation.defaultPadding, 8)
    XCTAssertEqual(ChipPresentation.defaultIconSize, 18)
    XCTAssertEqual(ChipPresentation.selectedColorToken, "secondarycontainer")

    let resting = ControlNode(
      id: 1, type: "Chip", props: ["label": .string("A"), "bgcolor": .string("red")])
    XCTAssertTrue(ChipPresentation.requiresCustomRendering(resting))
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

  func testSegmentedButtonRetainsFlutterAndFletStyleDefaults() {
    XCTAssertEqual(SegmentedButtonPresentation.defaultMinimumHeight, 40)
    XCTAssertEqual(SegmentedButtonPresentation.defaultIconSize, 18)
    XCTAssertEqual(SegmentedButtonPresentation.explicitStyleDefaultPadding.leading, 8)

    let flutterDefault = SegmentedButtonPresentation(
      node: ControlNode(
        id: 1, type: "SegmentedButton",
        props: ["selected": .array([.string("one")])]))
    XCTAssertEqual(flutterDefault.route, .picker)

    let fletExplicitDefault = SegmentedButtonPresentation(
      node: ControlNode(
        id: 2, type: "SegmentedButton",
        props: ["selected": .array([.string("one")])],
        internals: ["style": .map([:])]))
    XCTAssertEqual(fletExplicitDefault.route, .buttonGroup)
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
