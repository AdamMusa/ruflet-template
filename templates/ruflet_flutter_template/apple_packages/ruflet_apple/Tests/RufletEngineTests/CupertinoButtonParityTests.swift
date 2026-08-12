import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CupertinoButtonParityTests: XCTestCase {
  private func node(
    _ type: String = "CupertinoButton",
    _ props: [String: RufletValue] = [:]
  ) -> ControlNode {
    ControlNode(id: 1, type: type, props: props)
  }

  func testEveryCupertinoButtonWireAndAdaptiveTypeKeepsItsVariant() {
    XCTAssertEqual(CupertinoButtonVariant(wireType: "CupertinoButton"), .plain)
    XCTAssertEqual(CupertinoButtonVariant(wireType: "CupertinoFilledButton"), .filled)
    XCTAssertEqual(CupertinoButtonVariant(wireType: "CupertinoTintedButton"), .tinted)

    // Flet's adaptive Material constructors are routed through this same
    // renderer and use the same two aliases in CupertinoButtonControl.
    XCTAssertEqual(CupertinoButtonVariant(wireType: "FilledButton"), .filled)
    XCTAssertEqual(CupertinoButtonVariant(wireType: "FilledTonalButton"), .tinted)
  }

  func testPinnedFletConstructorDefaultsArePreserved() {
    let presentation = CupertinoButtonPresentation(node: node())

    XCTAssertEqual(presentation.variant, .plain)
    XCTAssertEqual(presentation.appearance, .borderless)
    XCTAssertEqual(presentation.sizeStyle, .large)
    XCTAssertEqual(presentation.pressedOpacity, 0.4)
    XCTAssertFalse(presentation.autofocus)
    XCTAssertFalse(presentation.disabled)
    XCTAssertEqual(presentation.minimumSize, CGSize(width: 44, height: 44))
    XCTAssertEqual(presentation.resolvedPadding.top, 16)
    XCTAssertEqual(presentation.resolvedPadding.leading, 20)
    XCTAssertEqual(presentation.alignment, .center)
    XCTAssertEqual(presentation.borderRadius, 8)
    XCTAssertEqual(
      presentation.disabledBackgroundToken,
      CupertinoButtonPresentation.defaultDisabledBackgroundToken)
    XCTAssertEqual(CupertinoButtonPresentation.iconSize, 20)
    XCTAssertEqual(CupertinoButtonPresentation.iconContentSpacing, 8)
    XCTAssertEqual(CupertinoButtonPresentation.focusOutlineWidth, 3.5)
    XCTAssertEqual(CupertinoButtonPresentation.defaultFocusColorOpacity, 0.80)
    XCTAssertEqual(CupertinoButtonPresentation.defaultFocusColorBrightness, 0.69)
    XCTAssertEqual(CupertinoButtonPresentation.defaultFocusColorSaturation, 0.835)
  }

  func testSizeStyleCarriesFlutterPaddingAndMinimumTarget() {
    let cases: [(String, CGFloat, CGFloat, CGFloat)] = [
      ("small", 28, 6, 12),
      ("medium", 32, 10, 15),
      ("large", 44, 16, 20),
    ]

    for (size, side, verticalPadding, horizontalPadding) in cases {
      let presentation = CupertinoButtonPresentation(node: node(
        "CupertinoButton", ["size": .string(size)]))
      XCTAssertEqual(presentation.defaultMinimumSide, side, size)
      XCTAssertEqual(presentation.minimumSize, CGSize(width: side, height: side), size)
      XCTAssertEqual(presentation.resolvedPadding.top, verticalPadding, size)
      XCTAssertEqual(presentation.resolvedPadding.leading, horizontalPadding, size)
    }
  }

  func testExplicitGeometryAndFocusPropertiesOverrideDefaults() {
    let presentation = CupertinoButtonPresentation(node: node(
      "CupertinoFilledButton",
      [
        "autofocus": .bool(true),
        "opacity_on_click": .double(0.25),
        "min_size": .map(["width": .double(80), "height": .double(36)]),
        "padding": .map([
          "left": .double(2), "top": .double(3),
          "right": .double(4), "bottom": .double(5),
        ]),
        "alignment": .string("bottom_right"),
        "border_radius": .double(6),
        "bgcolor": .string("blue"),
        "color": .string("white"),
        "disabled_bgcolor": .string("grey"),
        "focus_color": .string("orange"),
      ]))

    XCTAssertEqual(presentation.variant, .filled)
    XCTAssertEqual(presentation.appearance, .borderedProminent)
    XCTAssertTrue(presentation.autofocus)
    XCTAssertEqual(presentation.pressedOpacity, 0.25)
    XCTAssertEqual(presentation.minimumSize, CGSize(width: 80, height: 36))
    XCTAssertEqual(presentation.resolvedPadding.leading, 2)
    XCTAssertEqual(presentation.resolvedPadding.top, 3)
    XCTAssertEqual(presentation.resolvedPadding.trailing, 4)
    XCTAssertEqual(presentation.resolvedPadding.bottom, 5)
    XCTAssertEqual(presentation.alignment, .bottomTrailing)
    XCTAssertEqual(presentation.borderRadius, 6)
    XCTAssertEqual(presentation.backgroundToken, "blue")
    XCTAssertEqual(presentation.foregroundToken, "white")
    XCTAssertEqual(presentation.disabledBackgroundToken, "grey")
    XCTAssertEqual(presentation.focusColorToken, "orange")
  }

  func testPlainBackgroundPromotesToNativeFilledAppearance() {
    let transparent = CupertinoButtonPresentation(node: node())
    let colored = CupertinoButtonPresentation(node: node(
      "CupertinoButton", ["bgcolor": .string("blue")]))
    let filled = CupertinoButtonPresentation(node: node("CupertinoFilledButton"))
    let tinted = CupertinoButtonPresentation(node: node("CupertinoTintedButton"))

    XCTAssertFalse(transparent.hasBackground)
    XCTAssertEqual(transparent.appearance, .borderless)
    XCTAssertTrue(colored.hasBackground)
    XCTAssertEqual(colored.appearance, .borderedProminent)
    XCTAssertTrue(filled.hasBackground)
    XCTAssertEqual(filled.appearance, .borderedProminent)
    XCTAssertTrue(tinted.hasBackground)
    XCTAssertEqual(tinted.appearance, .bordered)
  }

  func testIconAndContentAcceptEitherScalarsOrControlSlots() {
    let scalar = CupertinoButtonPresentation(node: node(
      "CupertinoButton",
      ["icon": .int(1), "content": .string("Save")]))
    XCTAssertEqual(scalar.slot("icon"), .scalar)
    XCTAssertEqual(scalar.slot("content"), .scalar)

    let controls = CupertinoButtonPresentation(node: node(
      "CupertinoButton",
      ["icon": .controlRef(21), "content": .controlRef(22)]))
    XCTAssertEqual(controls.slot("icon"), .control(21))
    XCTAssertEqual(controls.slot("content"), .control(22))

    XCTAssertEqual(CupertinoButtonPresentation(node: node()).slot("icon"), .none)
    XCTAssertEqual(CupertinoButtonPresentation(node: node()).slot("content"), .none)
  }

  func testRegistryExposesImperativeFocusAndButtonEvents() {
    for type in ["CupertinoButton", "CupertinoFilledButton", "CupertinoTintedButton"] {
      let descriptor = ControlRegistry.descriptor(for: type)
      XCTAssertEqual(descriptor?.supportedMethods, ["focus"], type)
      XCTAssertTrue(descriptor?.supportedEvents.contains("click") == true, type)
      XCTAssertTrue(descriptor?.supportedEvents.contains("long_press") == true, type)
      XCTAssertTrue(descriptor?.supportedEvents.contains("focus") == true, type)
      XCTAssertTrue(descriptor?.supportedEvents.contains("blur") == true, type)
    }
  }
}
