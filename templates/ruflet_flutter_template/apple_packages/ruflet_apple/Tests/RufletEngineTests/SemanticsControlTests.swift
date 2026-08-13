import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

@MainActor
final class SemanticsControlTests: XCTestCase {
  func testDescriptorPreservesPinnedStateAndRufletAliases() {
    let control = makeControl(properties: [
      "label": .string("Account status"),
      "value": .string("Ready"),
      "hint_text": .string("Opens account details"),
      "on_tap_hint_text": .string("Activate account"),
      "on_long_press_hint_text": .string("Open account menu"),
      "increased_value": .string("More"),
      "decreased_value": .string("Less"),
      "checked": .bool(false),
      "mixed": .bool(true),
      "toggled": .bool(true),
      "expanded": .bool(false),
      "slider": .bool(true),
      "textfield": .bool(true),
      "obscured": .bool(true),
      "multiline": .bool(true),
      "read_only": .bool(true),
      "disabled": .bool(true),
      "current_value_length": .int(4),
      "max_value_length": .int(12),
      "container": .bool(true),
      "focusable": .bool(true),
      "focus": .bool(true),
      "heading_level": .int(2),
      "button": .bool(true),
      "link": .bool(true),
      "image": .bool(true),
      "selected": .bool(true),
      "live_region": .bool(true),
    ])

    let descriptor = RufletSemanticsDescriptor(control: control)
    XCTAssertEqual(descriptor.label, "Account status")
    XCTAssertEqual(
      descriptor.value,
      "Ready, mixed, on, collapsed, adjustable, text field, secure, multiline, read only, disabled, 4 of 12 characters")
    XCTAssertEqual(
      descriptor.hint,
      "Opens account details. Activate account. Increase: More. Decrease: Less")
    XCTAssertEqual(descriptor.longPressHint, "Open account menu")
    XCTAssertTrue(descriptor.disabled)
    XCTAssertTrue(descriptor.container)
    XCTAssertEqual(descriptor.focusable, true)
    XCTAssertEqual(descriptor.focused, true)
    XCTAssertEqual(descriptor.headingLevel, .h2)
    XCTAssertTrue(descriptor.traits.contains(.isButton))
    XCTAssertTrue(descriptor.traits.contains(.isLink))
    XCTAssertTrue(descriptor.traits.contains(.isImage))
    XCTAssertTrue(descriptor.traits.contains(.isSelected))
    XCTAssertTrue(descriptor.traits.contains(.isHeader))
    XCTAssertTrue(descriptor.traits.contains(.updatesFrequently))
    XCTAssertTrue(descriptor.traits.contains(.allowsDirectInteraction))
    XCTAssertTrue(descriptor.traits.contains(.isStaticText))
  }

  func testEventRouterEmitsEveryPinnedActionNameAndPayload() {
    let backend = SemanticsTestBackend()
    let properties = [
      "on_tap", "on_double_tap", "on_long_press", "on_increase", "on_decrease",
      "on_dismiss", "on_scroll_left", "on_scroll_right", "on_scroll_up", "on_scroll_down",
      "on_copy", "on_cut", "on_paste", "on_move_cursor_forward_by_character",
      "on_move_cursor_backward_by_character", "on_did_gain_accessibility_focus",
      "on_did_lose_accessibility_focus", "on_set_text",
    ].reduce(into: [String: RufletValue]()) { $0[$1] = .bool(true) }
    let control = makeControl(properties: properties, backend: backend)
    let router = RufletSemanticsEventRouter(control: control)

    let actions: [RufletSemanticsAction] = [
      .tap, .doubleTap, .longPress, .increase, .decrease, .dismiss,
      .scrollLeft, .scrollRight, .scrollUp, .scrollDown, .copy, .cut, .paste,
      .moveCursorForwardByCharacter(extendSelection: true),
      .moveCursorBackwardByCharacter(extendSelection: false),
      .didGainAccessibilityFocus, .didLoseAccessibilityFocus, .setText("Replacement"),
    ]
    actions.forEach(router.trigger)

    XCTAssertEqual(backend.events.map(\.name), [
      "tap", "double_tap", "long_press", "increase", "decrease", "dismiss",
      "scroll_left", "scroll_right", "scroll_up", "scroll_down", "copy", "cut", "paste",
      "move_cursor_forward_by_character", "move_cursor_backward_by_character",
      "did_gain_accessibility_focus", "did_lose_accessibility_focus", "set_text",
    ])
    XCTAssertEqual(backend.events[13].data, .bool(true))
    XCTAssertEqual(backend.events[14].data, .bool(false))
    XCTAssertEqual(backend.events[17].data, .string("Replacement"))
  }

  func testTapAcceptsPinnedClickSubscriptionAndActionsAreConditional() {
    let backend = SemanticsTestBackend()
    let control = makeControl(properties: ["on_click": .bool(true)], backend: backend)
    let router = RufletSemanticsEventRouter(control: control)

    XCTAssertTrue(router.isAvailable(.tap))
    XCTAssertFalse(router.isAvailable(.copy))
    router.trigger(.tap)
    router.trigger(.copy)

    XCTAssertEqual(backend.events.map(\.name), ["click"])
  }

  private func makeControl(
    properties: [String: RufletValue],
    backend: SemanticsTestBackend? = nil
  ) -> RufletControl {
    RufletControl(
      id: 1,
      type: "Semantics",
      properties: properties,
      backend: backend ?? SemanticsTestBackend())
  }
}

@MainActor
private final class SemanticsTestBackend: RufletBackendProtocol {
  struct Event {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var events: [Event] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ value: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
