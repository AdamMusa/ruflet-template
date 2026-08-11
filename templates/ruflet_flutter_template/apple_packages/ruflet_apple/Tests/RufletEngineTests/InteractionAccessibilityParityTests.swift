import CoreGraphics
import RufletProtocol
@testable import RufletUI
import XCTest

final class InteractionAccessibilityParityTests: XCTestCase {
  func testGesturePayloadsUseVendoredFletCompactKeys() {
    XCTAssertEqual(
      FletInteractionParity.tap(
        kind: "touch", local: CGPoint(x: 3, y: 4), global: CGPoint(x: 13, y: 14)),
      .map([
        "k": .string("touch"),
        "l": .map(["x": .double(3), "y": .double(4)]),
        "g": .map(["x": .double(13), "y": .double(14)]),
      ]))

    let update = FletInteractionParity.dragUpdate(
      local: CGPoint(x: 8, y: 11), global: CGPoint(x: 18, y: 31),
      previousLocal: CGPoint(x: 5, y: 7), previousGlobal: CGPoint(x: 15, y: 27),
      primaryDelta: 3, timestamp: 100)
    XCTAssertEqual(update["ld"], .map(["x": .double(3), "y": .double(4)]))
    XCTAssertEqual(update["gd"], .map(["x": .double(3), "y": .double(4)]))
    XCTAssertEqual(update["pd"], .double(3))
    XCTAssertEqual(update["ts"], .double(100))
  }

  func testDismissPayloadAndDirectionMatchFlet() {
    XCTAssertEqual(
      FletInteractionParity.dismissDirection(
        translation: CGSize(width: -40, height: 2), allowed: "horizontal"),
      "endToStart")
    XCTAssertEqual(
      FletInteractionParity.dismissDirection(
        translation: CGSize(width: 40, height: 2), allowed: "end_to_start"),
      nil)
    XCTAssertEqual(
      FletInteractionParity.dismissDirection(
        translation: CGSize(width: 2, height: 40), allowed: "vertical"),
      "down")
    XCTAssertEqual(
      FletInteractionParity.dismissUpdate(
        direction: "up", progress: 0.4, previousReached: false, reached: true),
      .map([
        "direction": .string("up"), "progress": .double(0.4),
        "previous_reached": .bool(false), "reached": .bool(true),
      ]))
  }

  func testKeyboardPayloadMatchesFletLogicalKeyShape() {
    XCTAssertEqual(
      FletInteractionParity.key("Escape"),
      .map(["key": .string("Escape")]))
  }

  func testInteractionDescriptorsDeclareCompleteFletContracts() {
    let gestureEvents: Set<String> = [
      "double_tap", "double_tap_cancel", "double_tap_down", "enter", "exit",
      "force_press_end", "force_press_peak", "force_press_start", "force_press_update",
      "horizontal_drag_cancel", "horizontal_drag_down", "horizontal_drag_end",
      "horizontal_drag_start", "horizontal_drag_update", "hover", "long_press",
      "long_press_cancel", "long_press_down", "long_press_end", "long_press_move_update",
      "long_press_start", "long_press_up", "multi_long_press", "multi_tap", "pan_cancel",
      "pan_down", "pan_end", "pan_start", "pan_update", "right_pan_end",
      "right_pan_start", "right_pan_update", "scale_end", "scale_start", "scale_update",
      "scroll", "secondary_long_press", "secondary_long_press_cancel",
      "secondary_long_press_down", "secondary_long_press_end",
      "secondary_long_press_move_update", "secondary_long_press_start",
      "secondary_long_press_up", "secondary_tap", "secondary_tap_cancel",
      "secondary_tap_down", "secondary_tap_up", "tap", "tap_cancel", "tap_down",
      "tap_move", "tap_up", "tertiary_long_press", "tertiary_long_press_cancel",
      "tertiary_long_press_down", "tertiary_long_press_end",
      "tertiary_long_press_move_update", "tertiary_long_press_start",
      "tertiary_long_press_up", "tertiary_tap_cancel", "tertiary_tap_down",
      "tertiary_tap_up", "vertical_drag_cancel", "vertical_drag_down",
      "vertical_drag_end", "vertical_drag_start", "vertical_drag_update",
    ]
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "GestureDetector")?.supportedEvents,
      gestureEvents)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "KeyboardListener")?.supportedEvents,
      Set(["key_down", "key_repeat", "key_up"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "KeyboardListener")?.supportedMethods,
      Set(["focus"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Dismissible")?.supportedEvents,
      Set(["confirm_dismiss", "dismiss", "resize", "update"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Dismissible")?.supportedMethods,
      Set(["confirm_dismiss"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "SelectionArea")?.supportedEvents,
      Set(["change"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "WindowDragArea")?.supportedEvents,
      Set(["double_tap", "drag_end", "drag_start"]))
  }

  func testSemanticsDescriptorExposesEveryFletAccessibilityAction() {
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Semantics")?.supportedEvents,
      Set([
        "click", "copy", "cut", "decrease", "did_gain_accessibility_focus",
        "did_lose_accessibility_focus", "dismiss", "increase",
        "move_cursor_backward_by_character", "move_cursor_forward_by_character", "paste",
        "scroll_down", "scroll_left", "scroll_right", "scroll_up", "set_text",
      ]))
  }
}
