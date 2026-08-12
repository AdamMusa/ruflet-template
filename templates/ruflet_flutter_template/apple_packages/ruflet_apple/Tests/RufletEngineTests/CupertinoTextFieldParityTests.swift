import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest
@testable import RufletUI

final class CupertinoTextFieldParityTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 41, type: "CupertinoTextField", props: props)
  }

  func testPinnedFletCupertinoConstructorDefaults() {
    let presentation = RufletCupertinoTextFieldPresentation(
      node: node(), focused: false, revealedPassword: false)

    XCTAssertEqual(presentation.value, "")
    XCTAssertEqual(presentation.placeholder, "")
    XCTAssertFalse(presentation.autofocus)
    XCTAssertFalse(presentation.shiftEnter)
    XCTAssertFalse(presentation.isMultiline)
    XCTAssertEqual(presentation.minLines, 1)
    XCTAssertEqual(presentation.maxLines, 1)
    XCTAssertFalse(presentation.fitsParent)
    XCTAssertEqual(presentation.clipBehavior, "hardEdge")
    XCTAssertEqual(presentation.defaultWidth, 300)
    XCTAssertEqual(presentation.padding.top, 7)
    XCTAssertEqual(presentation.padding.leading, 7)
    XCTAssertEqual(presentation.scrollPadding.top, 20)
    XCTAssertEqual(presentation.cornerRadii, RufletCornerRadii(uniform: 5))
    XCTAssertEqual(presentation.traits.cursorWidth, 2)
    XCTAssertEqual(presentation.traits.cursorRadius, 2)
    XCTAssertEqual(presentation.traits.obscuringCharacter, "•")
    XCTAssertEqual(presentation.clearButtonSemanticsLabel, "Clear")
    XCTAssertEqual(presentation.prefixMode, .always)
    XCTAssertEqual(presentation.suffixMode, .always)
    XCTAssertEqual(presentation.clearMode, .never)
    XCTAssertEqual(presentation.suffixAttachment, .none)
    XCTAssertEqual(presentation.initialSelection, NSRange(location: 0, length: 0))

    guard let border = presentation.border else { return XCTFail("expected outline") }
    XCTAssertEqual(border.top?.width, 1)
    XCTAssertEqual(border.right?.width, 1)
    XCTAssertEqual(border.bottom?.width, 1)
    XCTAssertEqual(border.left?.width, 1)
  }

  func testOverlayVisibilityDependsOnTextRatherThanFocus() {
    XCTAssertFalse(RufletCupertinoOverlayVisibility.editing.shows(hasText: false))
    XCTAssertTrue(RufletCupertinoOverlayVisibility.editing.shows(hasText: true))
    XCTAssertTrue(RufletCupertinoOverlayVisibility.notEditing.shows(hasText: false))
    XCTAssertFalse(RufletCupertinoOverlayVisibility.notEditing.shows(hasText: true))

    let emptyFocused = RufletCupertinoTextFieldPresentation(
      node: node([
        "prefix": .string("$"),
        "prefix_visibility_mode": .string("editing"),
      ]), focused: true, revealedPassword: false)
    XCTAssertFalse(emptyFocused.showsPrefix)

    let populatedBlurred = RufletCupertinoTextFieldPresentation(
      node: node([
        "value": .string("42"),
        "prefix": .string("$"),
        "prefix_visibility_mode": .string("editing"),
      ]), focused: false, revealedPassword: false)
    XCTAssertTrue(populatedBlurred.showsPrefix)
  }

  func testSuffixWinsAndClearButtonIsItsTextDependentFallback() {
    let suffix = RufletCupertinoTextFieldPresentation(
      node: node([
        "value": .string("query"),
        "suffix": .string("kg"),
        "suffix_visibility_mode": .string("editing"),
        "clear_button_visibility_mode": .string("always"),
      ]), focused: false, revealedPassword: false)
    XCTAssertEqual(suffix.suffixAttachment, .suffix)

    let hiddenSuffix = RufletCupertinoTextFieldPresentation(
      node: node([
        "suffix": .string("kg"),
        "suffix_visibility_mode": .string("editing"),
        "clear_button_visibility_mode": .string("always"),
      ]), focused: true, revealedPassword: false)
    XCTAssertEqual(hiddenSuffix.suffixAttachment, .clear)

    let reveal = RufletCupertinoTextFieldPresentation(
      node: node([
        "value": .string("secret"),
        "password": .bool(true),
        "can_reveal_password": .bool(true),
        "suffix": .string("ignored by Flet"),
        "clear_button_visibility_mode": .string("always"),
      ]), focused: false, revealedPassword: false)
    XCTAssertTrue(reveal.hasRevealSuffix)
    XCTAssertTrue(reveal.obscuresText)
    XCTAssertEqual(reveal.suffixAttachment, .suffix)

    let revealed = RufletCupertinoTextFieldPresentation(
      node: reveal.node, focused: false, revealedPassword: true)
    XCTAssertFalse(revealed.obscuresText)
  }

  func testMultilineSizingWidthRTLAndExternalSelectionMatchFlet() {
    let presentation = RufletCupertinoTextFieldPresentation(
      node: node([
        "value": .string("Ruflet"),
        "shift_enter": .bool(true),
        "min_lines": .int(2),
        "rtl": .bool(true),
      ]), focused: false, revealedPassword: false)

    XCTAssertTrue(presentation.isMultiline)
    XCTAssertTrue(presentation.shiftEnter)
    XCTAssertNil(presentation.maxLines)
    XCTAssertEqual(presentation.minimumHeight, 40)
    XCTAssertNil(presentation.maximumHeight)
    XCTAssertEqual(presentation.traits.keyboardType, "multiline")
    XCTAssertEqual(presentation.traits.textAlign, "right")
    XCTAssertEqual(presentation.initialSelection, NSRange(location: 6, length: 0))

    XCTAssertNil(RufletCupertinoTextFieldPresentation(
      node: node(["expand": .int(1)]), focused: false, revealedPassword: false).defaultWidth)
    XCTAssertNil(RufletCupertinoTextFieldPresentation(
      node: node(["width": .double(180)]), focused: false, revealedPassword: false).defaultWidth)

    let selected = RufletCupertinoTextFieldPresentation(
      node: node([
        "value": .string("Ruflet"),
        "selection": .map([
          "base_offset": .int(1), "extent_offset": .int(4),
        ]),
      ]), focused: false, revealedPassword: false)
    XCTAssertEqual(selected.initialSelection, NSRange(location: 1, length: 3))
  }

  func testUserEditUpdatesValueBeforeOptionalChangeEvent() {
    let field = node(["on_change": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, data in calls.append("event:\(name):\(data.stringValue ?? "")") },
      setLocal: { _, key, value in calls.append("local:\(key):\(value.stringValue ?? "")") },
      update: { _, props in calls.append("update:value:\(props["value"]?.stringValue ?? "")") })

    RufletCupertinoTextFieldEvents.change("native", on: field, to: sink)
    XCTAssertEqual(calls, [
      "local:value:native", "update:value:native", "event:change:native",
    ])

    calls.removeAll()
    RufletCupertinoTextFieldEvents.change("silent", on: node(), to: sink)
    XCTAssertEqual(calls, ["local:value:silent", "update:value:silent"])
  }

  func testSelectionUpdatesOnlyWhenFletListenerIsEnabled() {
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, _ in calls.append("event:\(name)") },
      setLocal: { _, key, _ in calls.append("local:\(key)") },
      update: { _, props in calls.append("update:\(props.keys.sorted().joined(separator: ","))") })

    RufletCupertinoTextFieldEvents.selection(
      NSRange(location: 1, length: 2),
      on: node(["value": .string("Ruflet")]), to: sink)
    XCTAssertTrue(calls.isEmpty)

    RufletCupertinoTextFieldEvents.selection(
      NSRange(location: 1, length: 2),
      on: node([
        "value": .string("Ruflet"),
        "on_selection_change": .bool(true),
      ]), to: sink)
    XCTAssertEqual(calls, [
      "local:selection", "update:selection", "event:selection_change",
    ])
  }

  func testRegistryExposesOnlyPinnedImperativeMethod() {
    let descriptor = ControlRegistry.descriptor(for: "CupertinoTextField")
    XCTAssertEqual(descriptor?.supportedMethods, ["focus"])
    XCTAssertEqual(
      descriptor?.supportedEvents,
      ["blur", "change", "click", "focus", "selection_change", "submit", "tap_outside"])
  }
}
