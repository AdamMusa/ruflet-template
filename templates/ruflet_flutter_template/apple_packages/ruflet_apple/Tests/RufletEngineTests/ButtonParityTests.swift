import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

/// The Material button families, checked against the widgets Flet builds.
///
/// Flet's `IconButtonControl` only reaches `parseButtonStyle` when Ruby
/// supplied a `style`; without one the button keeps Flutter's own
/// `_IconButtonDefaultsM3` container. The four icon-button wire types are
/// therefore not interchangeable, and neither are their selected and
/// unselected states, so each pairing is pinned here rather than left to a
/// single shared fallback.
final class ButtonParityTests: XCTestCase {
  private func node(
    _ type: String,
    _ props: [String: RufletValue] = [:],
    internals: [String: RufletValue] = [:]
  ) -> ControlNode {
    ControlNode(id: 1, type: type, props: props, internals: internals)
  }

  // MARK: - Wire types

  func testEveryIconButtonWireTypeKeepsItsOwnVariant() {
    XCTAssertEqual(ButtonVariant(wireType: "IconButton"), .icon)
    XCTAssertEqual(ButtonVariant(wireType: "FilledIconButton"), .filledIcon)
    XCTAssertEqual(ButtonVariant(wireType: "FilledTonalIconButton"), .filledTonalIcon)
    XCTAssertEqual(ButtonVariant(wireType: "OutlinedIconButton"), .outlinedIcon)

    for type in ["IconButton", "FilledIconButton", "FilledTonalIconButton",
                 "OutlinedIconButton"] {
      XCTAssertTrue(ButtonVariant(wireType: type).isIconButton, type)
    }
    for type in ["Button", "FilledButton", "TextButton", "FloatingActionButton"] {
      XCTAssertFalse(ButtonVariant(wireType: type).isIconButton, type)
    }
  }

  func testUnknownWireTypeFallsBackToTheElevatedButton() {
    XCTAssertEqual(ButtonVariant(wireType: "ElevatedButton"), .elevated)
    XCTAssertEqual(ButtonVariant(wireType: "Button"), .elevated)
  }

  // MARK: - Icon button palettes

  func testStandardIconButtonHasNoContainerAndMovesOnlyItsGlyph() {
    let resting = RufletThemeDefaults.iconButtonPalette(
      control: "IconButton", selected: nil, disabled: false)
    XCTAssertNil(resting.background)
    XCTAssertNil(resting.outline)
    XCTAssertEqual(resting.foreground, "onsurfacevariant")

    let on = RufletThemeDefaults.iconButtonPalette(
      control: "IconButton", selected: true, disabled: false)
    XCTAssertNil(on.background)
    XCTAssertEqual(on.foreground, "primary")
  }

  /// Flutter calls a button *toggleable* when `isSelected` was supplied at
  /// all. A filled icon button that can be toggled is a tinted surface while
  /// it is off; one that cannot is always the primary container.
  func testFilledIconButtonDistinguishesToggleableFromPlain() {
    let plain = RufletThemeDefaults.iconButtonPalette(
      control: "FilledIconButton", selected: nil, disabled: false)
    XCTAssertEqual(plain.background, "primary")
    XCTAssertEqual(plain.foreground, "onprimary")

    let off = RufletThemeDefaults.iconButtonPalette(
      control: "FilledIconButton", selected: false, disabled: false)
    XCTAssertEqual(off.background, "surfacecontainerhighest")
    XCTAssertEqual(off.foreground, "primary")

    let on = RufletThemeDefaults.iconButtonPalette(
      control: "FilledIconButton", selected: true, disabled: false)
    XCTAssertEqual(on.background, "primary")
    XCTAssertEqual(on.foreground, "onprimary")
  }

  func testFilledTonalIconButtonUsesTheSecondaryContainer() {
    let plain = RufletThemeDefaults.iconButtonPalette(
      control: "FilledTonalIconButton", selected: nil, disabled: false)
    XCTAssertEqual(plain.background, "secondarycontainer")
    XCTAssertEqual(plain.foreground, "onsecondarycontainer")

    let off = RufletThemeDefaults.iconButtonPalette(
      control: "FilledTonalIconButton", selected: false, disabled: false)
    XCTAssertEqual(off.background, "surfacecontainerhighest")
    XCTAssertEqual(off.foreground, "onsurfacevariant")
  }

  /// The outlined button is the only one whose border disappears when it is
  /// selected — the filled inverse surface takes the outline's place.
  func testOutlinedIconButtonTradesItsOutlineForAFillWhenSelected() {
    let off = RufletThemeDefaults.iconButtonPalette(
      control: "OutlinedIconButton", selected: nil, disabled: false)
    XCTAssertNil(off.background)
    XCTAssertEqual(off.outline, "outline")
    XCTAssertEqual(off.foreground, "onsurfacevariant")

    let on = RufletThemeDefaults.iconButtonPalette(
      control: "OutlinedIconButton", selected: true, disabled: false)
    XCTAssertEqual(on.background, "inversesurface")
    XCTAssertEqual(on.foreground, "oninversesurface")
    XCTAssertNil(on.outline)
  }

  func testDisabledIconButtonsShareFlutterOpacitiesOnOnSurface() {
    for type in ["IconButton", "FilledIconButton", "FilledTonalIconButton",
                 "OutlinedIconButton"] {
      let palette = RufletThemeDefaults.iconButtonPalette(
        control: type, selected: nil, disabled: true)
      XCTAssertEqual(palette.foreground, "onsurface,0.38", type)
      if type != "IconButton" && type != "OutlinedIconButton" {
        XCTAssertEqual(palette.background, "onsurface,0.12", type)
      }
    }
  }

  /// A `style` moves the button onto Flet's own `parseButtonStyle` default,
  /// which is the primary role for every icon-button variant.
  func testSuppliedStyleReplacesTheVariantForegroundWithFletsDefault() {
    let styleless = IconButtonPresentation.palette(for: node("FilledIconButton"))
    XCTAssertEqual(styleless.foreground, "onprimary")

    let styled = IconButtonPresentation.palette(
      for: node("FilledIconButton", internals: ["style": .map(["padding": .double(4)])]))
    XCTAssertEqual(styled.foreground, "primary")
    XCTAssertEqual(styled.background, "primary", "a style must not move the container")
  }

  func testDisabledStyledIconButtonKeepsTheDisabledForeground() {
    let styled = IconButtonPresentation.palette(
      for: node(
        "IconButton",
        ["disabled": .bool(true)],
        internals: ["style": .map(["padding": .double(4)])]))
    XCTAssertEqual(styled.foreground, "onsurface,0.38")
  }

  // MARK: - Icon button geometry

  func testIconButtonTargetIsMaterials40PointSquareWhenUnconstrained() {
    let presentation = IconButtonPresentation(node: node("IconButton"))
    XCTAssertEqual(presentation.constraints.minWidth, 40)
    XCTAssertEqual(presentation.constraints.minHeight, 40)
    XCTAssertNil(presentation.constraints.maxWidth)
    XCTAssertEqual(presentation.padding.leading, 8)
    XCTAssertEqual(presentation.padding.top, 8)
  }

  func testSplashRadiusNamesTheTargetUntilSizeConstraintsDo() {
    let splash = IconButtonPresentation(
      node: node("IconButton", ["splash_radius": .double(15)]))
    XCTAssertEqual(splash.constraints.minWidth, 30)
    XCTAssertEqual(splash.constraints.minHeight, 30)

    let constrained = IconButtonPresentation(
      node: node(
        "IconButton",
        [
          "splash_radius": .double(15),
          "size_constraints": .map(["min_width": .double(64), "max_width": .double(96)]),
        ]))
    XCTAssertEqual(constrained.constraints.minWidth, 64)
    XCTAssertEqual(constrained.constraints.maxWidth, 96)
    XCTAssertNil(constrained.constraints.minHeight)
  }

  func testExplicitPaddingAndAlignmentReachTheIconButton() {
    let presentation = IconButtonPresentation(
      node: node(
        "IconButton",
        [
          "padding": .double(3),
          "alignment": .map(["x": .double(-1), "y": .double(0)]),
        ]))
    XCTAssertEqual(presentation.padding.leading, 3)
    XCTAssertEqual(presentation.alignment, .leading)
  }

  // MARK: - Floating action button

  func testRoundFloatingActionButtonUsesMaterial3SizeAndCorner() {
    let regular = FloatingActionPresentation(
      node: node("FloatingActionButton", ["icon": .string("add")]))
    XCTAssertFalse(regular.isExtended)
    XCTAssertEqual(regular.width, 56)
    XCTAssertEqual(regular.height, 56)
    XCTAssertEqual(regular.radius, 16)
    XCTAssertEqual(regular.elevation(), 6)

    let mini = FloatingActionPresentation(
      node: node("FloatingActionButton", ["icon": .string("add"), "mini": .bool(true)]))
    XCTAssertEqual(mini.width, 40)
    XCTAssertEqual(mini.radius, 12)
  }

  /// Flet reaches `FloatingActionButton.extended` only when both an icon and
  /// content were given; either one alone is the round button.
  func testFloatingActionButtonIsExtendedOnlyWithBothAnIconAndContent() {
    let iconOnly = FloatingActionPresentation(
      node: node("FloatingActionButton", ["icon": .string("add")]))
    let contentOnly = FloatingActionPresentation(
      node: node("FloatingActionButton", ["content": .string("New")]))
    let both = FloatingActionPresentation(
      node: node("FloatingActionButton", ["icon": .string("add"), "content": .string("New")]))

    XCTAssertFalse(iconOnly.isExtended)
    XCTAssertFalse(contentOnly.isExtended)
    XCTAssertTrue(both.isExtended)

    XCTAssertNil(both.width, "the extended button grows with its label")
    XCTAssertEqual(both.height, 56)
    XCTAssertEqual(both.padding.leading, 16)
    XCTAssertEqual(both.padding.trailing, 20)
    XCTAssertEqual(iconOnly.padding.leading, 0)
  }

  func testFloatingActionButtonShapeOverridesTheDefaultCorner() {
    let shaped = FloatingActionPresentation(
      node: node(
        "FloatingActionButton",
        ["icon": .string("add"), "shape": .map(["radius": .double(4)])]))
    XCTAssertEqual(shaped.radius, 4)
  }

  func testFloatingActionButtonElevationsFollowItsState() {
    let resting = FloatingActionPresentation(node: node("FloatingActionButton"))
    XCTAssertEqual(resting.elevation(), 6)
    XCTAssertEqual(resting.pressedElevation, 6)

    let pressed = FloatingActionPresentation(
      node: node("FloatingActionButton", ["highlight_elevation": .double(12)]))
    XCTAssertEqual(pressed.pressedElevation, 12)

    // A disabled FAB flattens, and stays flat while it is pressed.
    let disabled = FloatingActionPresentation(
      node: node(
        "FloatingActionButton",
        ["disabled": .bool(true), "elevation": .double(9), "disabled_elevation": .double(1)]))
    XCTAssertEqual(disabled.elevation(), 1)
    XCTAssertEqual(disabled.pressedElevation, 1)
  }

  func testFloatingActionButtonColorsResolveThroughTheMaterial3Roles() {
    let omitted = node("FloatingActionButton")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "bgcolor"),
      "primarycontainer")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "foreground_color"),
      "onprimarycontainer")

    let explicit = node("FloatingActionButton", ["bgcolor": .string("red400")])
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: explicit, property: "bgcolor"), "red400")
  }
}
