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

  // MARK: - Native icon-button appearance

  func testStylelessIconButtonsLeaveAppearanceToSwiftUI() {
    for type in ["IconButton", "FilledIconButton", "FilledTonalIconButton",
                 "OutlinedIconButton"] {
      XCTAssertFalse(IconButtonPresentation(node: node(type)).requiresCustomRendering, type)
    }
    XCTAssertEqual(NativeButtonAppearance.resolve(.icon), .borderless)
    XCTAssertEqual(NativeButtonAppearance.resolve(.filledIcon), .borderedProminent)
    XCTAssertEqual(NativeButtonAppearance.resolve(.filledTonalIcon), .bordered)
    XCTAssertEqual(NativeButtonAppearance.resolve(.outlinedIcon), .bordered)
  }

  func testExplicitIconAppearanceOptsIntoCustomRendering() {
    XCTAssertTrue(IconButtonPresentation(
      node: node("IconButton", ["icon_color": .string("red")])).requiresCustomRendering)
    XCTAssertTrue(IconButtonPresentation(
      node: node("FilledIconButton", internals: [
        "style": .map(["padding": .double(4)]),
      ])).requiresCustomRendering)
  }

  // MARK: - Icon button geometry

  func testIconButtonDoesNotApplyMaterialTargetWhenUnconstrained() {
    let presentation = IconButtonPresentation(node: node("IconButton"))
    XCTAssertFalse(presentation.requiresCustomRendering)
  }

  func testSplashRadiusNamesTheTargetUntilSizeConstraintsDo() {
    let splash = IconButtonPresentation(
      node: node("IconButton", ["splash_radius": .double(15)]))
    XCTAssertTrue(splash.requiresCustomRendering)
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

  func testStylelessFloatingActionButtonUsesNativeProminentAppearance() {
    let regular = FloatingActionPresentation(
      node: node("FloatingActionButton", ["icon": .string("add")]))
    XCTAssertFalse(regular.isExtended)
    XCTAssertFalse(regular.requiresCustomRendering)
    XCTAssertEqual(regular.side, 56)
    XCTAssertEqual(regular.nativeLabelSide, 40)
    XCTAssertEqual(NativeButtonAppearance.resolve(.floatingAction), .borderedProminent)

    let mini = FloatingActionPresentation(
      node: node("FloatingActionButton", ["icon": .string("add"), "mini": .bool(true)]))
    XCTAssertTrue(mini.isMini)
    XCTAssertEqual(mini.side, 40)
    XCTAssertEqual(mini.nativeLabelSide, 24)
    XCTAssertFalse(mini.requiresCustomRendering)
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

  }

  func testExtendedFloatingActionButtonIgnoresMiniLikeFlutterConstructor() {
    let extended = FloatingActionPresentation(node: node(
      "FloatingActionButton",
      ["icon": .string("add"), "content": .string("New"), "mini": .bool(true)]))
    XCTAssertTrue(extended.isExtended)
  }

  func testFletButtonValidationMessagesArePreserved() {
    XCTAssertEqual(
      ButtonPresentation.validationMessage(node("IconButton"), variant: .icon),
      "IconButton must have either icon or a visible content specified.")
    XCTAssertEqual(
      ButtonPresentation.validationMessage(node("FloatingActionButton"), variant: .floatingAction),
      "FloatingActionButton has nothing to display. Provide at minimum one of these: icon, content")
    XCTAssertEqual(
      ButtonPresentation.validationMessage(
        node("Button", ["icon": .string("add")]), variant: .elevated),
      "Error displaying Button: \"icon\" must be specified together with \"content\"")
  }

  func testFloatingActionButtonShapeOverridesTheDefaultCorner() {
    let shaped = FloatingActionPresentation(
      node: node(
        "FloatingActionButton",
        ["icon": .string("add"), "shape": .map(["radius": .double(4)])]))
    XCTAssertEqual(shaped.radius, 4)
  }

  func testFloatingActionButtonElevationsFollowItsState() {
    let pressed = FloatingActionPresentation(
      node: node("FloatingActionButton", ["highlight_elevation": .double(12)]))
    XCTAssertTrue(pressed.requiresCustomRendering)
    XCTAssertEqual(pressed.pressedElevation, 12)

    // A disabled FAB flattens, and stays flat while it is pressed.
    let disabled = FloatingActionPresentation(
      node: node(
        "FloatingActionButton",
        ["disabled": .bool(true), "elevation": .double(9), "disabled_elevation": .double(1)]))
    XCTAssertEqual(disabled.elevation(), 1)
    XCTAssertEqual(disabled.pressedElevation, 1)
  }

  func testFloatingActionButtonColorsPreserveFletDefaultsAndExplicitOverrides() {
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
