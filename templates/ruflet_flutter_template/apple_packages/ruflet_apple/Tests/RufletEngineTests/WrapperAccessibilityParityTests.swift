import XCTest

import RufletEngine
import RufletProtocol

@testable import RufletUI

final class WrapperAccessibilityParityTests: XCTestCase {
  private func node(_ type: String, _ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: type, props: props)
  }

  func testCanonicalSemanticsPropertiesWinOverCompatibilityAliases() {
    let configuration = RufletSemanticsConfiguration(
      node: node(
        "Semantics",
        [
          "hint": .string("canonical hint"),
          "hint_text": .string("legacy hint"),
          "text_field": .bool(false),
          "textfield": .bool(true),
          "slider": .bool(true),
          "disabled": .bool(true),
          "focused": .bool(false),
          "focus": .bool(true),
          "on_tap_hint": .string("canonical action"),
          "on_tap_hint_text": .string("legacy action"),
          "on_long_press_hint": .string("canonical long press"),
          "on_long_press_hint_text": .string("legacy long press"),
        ]))

    XCTAssertEqual(configuration.hint, "canonical hint")
    XCTAssertEqual(configuration.textField, false)
    XCTAssertEqual(configuration.slider, true)
    XCTAssertEqual(configuration.disabled, true)
    XCTAssertEqual(configuration.focused, false)
    XCTAssertEqual(configuration.tapHint, "canonical action")
    XCTAssertEqual(configuration.longPressHint, "canonical long press")
  }

  func testHistoricalSemanticsAliasesRemainWireCompatible() {
    let configuration = RufletSemanticsConfiguration(
      node: node(
        "Semantics",
        [
          "hint_text": .string("legacy hint"),
          "textfield": .bool(true),
          "focus": .bool(true),
          "on_tap_hint_text": .string("legacy action"),
          "on_long_press_hint_text": .string("legacy long press"),
        ]))

    XCTAssertEqual(configuration.hint, "legacy hint")
    XCTAssertEqual(configuration.textField, true)
    XCTAssertEqual(configuration.focused, true)
    XCTAssertEqual(configuration.tapHint, "legacy action")
    XCTAssertEqual(configuration.longPressHint, "legacy long press")
  }

  func testCanonicalSemanticsEventWinsOverLegacyTap() {
    var configuration = RufletSemanticsConfiguration(
      node: node(
        "Semantics",
        [
          "on_click": .bool(true),
          "on_tap": .bool(true),
        ]))
    XCTAssertEqual(configuration.handledEvent("click", compatibility: "tap"), "click")

    configuration = RufletSemanticsConfiguration(
      node: node(
        "Semantics",
        [
          "on_tap": .bool(true)
        ]))
    XCTAssertEqual(configuration.handledEvent("click", compatibility: "tap"), "tap")
  }

  func testAutofillDisposeActionMatchesFletDefaults() {
    XCTAssertEqual(
      RufletAutofillGroupSemantics.disposeAction(node("AutofillGroup")), .commit)
    XCTAssertEqual(
      RufletAutofillGroupSemantics.disposeAction(
        node(
          "AutofillGroup",
          [
            "dispose_action": .string("cancel")
          ])), .cancel)
    XCTAssertEqual(
      RufletAutofillGroupSemantics.disposeAction(
        node(
          "AutofillGroup",
          [
            "dispose_action": .string("future_value")
          ])), .commit)
  }

  func testWrapperAndBrowserContextMenuDescriptorsAreExecutable() {
    let autofill = ControlRegistry.builtInDescriptor(for: "AutofillGroup")
    XCTAssertEqual(autofill?.classification, .visible)
    XCTAssertEqual(autofill?.implementation, "AutofillGroupControlView")
    XCTAssertEqual(autofill?.rendering, .nativeView)

    let browserMenu = ControlRegistry.builtInDescriptor(for: "BrowserContextMenu")
    XCTAssertEqual(browserMenu?.classification, .service)
    XCTAssertEqual(browserMenu?.implementation, "BrowserContextMenuService")
    XCTAssertEqual(browserMenu?.rendering, .serviceOnly)
    XCTAssertEqual(browserMenu?.supportedMethods, Set(["disable_menu", "enable_menu"]))
  }

  func testAutofillGroupUnknownDisposeActionKeepsFletCommitDefault() {
    XCTAssertEqual(
      RufletAutofillGroupSemantics.disposeAction(ControlNode(
        id: 9, type: "AutofillGroup", props: ["dispose_action": .string("unknown")])),
      .commit)
  }
}
