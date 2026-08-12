import CoreGraphics
import RufletEngine
import RufletProtocol
import SwiftUI
@testable import RufletUI
import XCTest

final class TooltipMouseRegionParityTests: XCTestCase {
  func testBareStringTooltipPinsFletWaitAndFrameworkDefaults() throws {
    let tooltip = try XCTUnwrap(RufletTooltipPresentation(.string("Native help")))

    XCTAssertEqual(tooltip.message, "Native help")
    XCTAssertFalse(tooltip.structured)
    XCTAssertEqual(tooltip.waitDurationMilliseconds, 800)
    XCTAssertTrue(tooltip.tapToDismiss)
    XCTAssertEqual(tooltip.borderRadius, 4)
    XCTAssertNil(tooltip.triggerMode)
    XCTAssertNil(tooltip.mouseCursor)
  }

  func testStructuredTooltipConsumesFletShapeAndDecorationPrecedence() throws {
    let tooltip = try XCTUnwrap(RufletTooltipPresentation(.map([
      "message": .string("Details"),
      "enable_feedback": .bool(false),
      "tap_to_dismiss": .bool(false),
      "exclude_from_semantics": .bool(true),
      "size_constraints": .map([
        "min_width": .int(24), "max_width": .int(180),
        "min_height": .int(12), "max_height": .int(80),
      ]),
      "exit_duration": .int(125),
      "prefer_below": .bool(false),
      "padding": .int(8),
      "bgcolor": .string("red"),
      "decoration": .map([
        "bgcolor": .string("blue"), "border_radius": .int(9),
      ]),
      "text_style": .map(["size": .int(13)]),
      "vertical_offset": .int(18),
      "margin": .map(["left": .int(2), "top": .int(3)]),
      "mouse_cursor": .string("ZoOmIn"),
      "text_align": .string("CENTER"),
      "show_duration": .map(["seconds": .int(2), "milliseconds": .int(25)]),
      "wait_duration": .int(350),
      "trigger_mode": .string("LONGPRESS"),
    ])))

    XCTAssertTrue(tooltip.structured)
    XCTAssertEqual(tooltip.message, "Details")
    XCTAssertEqual(tooltip.enableFeedback, false)
    XCTAssertFalse(tooltip.tapToDismiss)
    XCTAssertEqual(tooltip.excludeFromSemantics, true)
    XCTAssertEqual(tooltip.constraints?.minWidth, 24)
    XCTAssertEqual(tooltip.constraints?.maxWidth, 180)
    XCTAssertEqual(tooltip.constraints?.minHeight, 12)
    XCTAssertEqual(tooltip.constraints?.maxHeight, 80)
    XCTAssertEqual(tooltip.exitDurationMilliseconds, 125)
    XCTAssertEqual(tooltip.preferBelow, false)
    XCTAssertEqual(tooltip.padding?.top, 8)
    XCTAssertEqual(tooltip.padding?.leading, 8)
    XCTAssertEqual(tooltip.borderRadius, 9)
    XCTAssertEqual(tooltip.backgroundColor, "blue")
    XCTAssertEqual(tooltip.textStyle?["size"], .int(13))
    XCTAssertEqual(tooltip.verticalOffset, 18)
    XCTAssertEqual(tooltip.margin?.leading, 2)
    XCTAssertEqual(tooltip.margin?.top, 3)
    XCTAssertEqual(tooltip.mouseCursor, .zoomin)
    XCTAssertEqual(tooltip.textAlign, "center")
    XCTAssertEqual(tooltip.showDurationMilliseconds, 2_025)
    XCTAssertEqual(tooltip.waitDurationMilliseconds, 350)
    XCTAssertEqual(tooltip.triggerMode, .longPress)
  }

  func testTooltipDurationMatchesFletParseDurationIntegerRules() {
    XCTAssertEqual(RufletTooltipPresentation.durationMilliseconds(.int(9)), 9)
    XCTAssertEqual(RufletTooltipPresentation.durationMilliseconds(.string("12")), 12)
    XCTAssertEqual(RufletTooltipPresentation.durationMilliseconds(.double(12.5)), 0)
    XCTAssertEqual(
      RufletTooltipPresentation.durationMilliseconds(.map([
        "minutes": .int(1), "seconds": .int(2), "milliseconds": .int(3),
        "microseconds": .int(500),
      ])),
      62_003.5)
    XCTAssertNil(RufletTooltipPresentation.durationMilliseconds(nil))
  }

  func testTooltipDocumentsNativeHelpLimitsInsteadOfPaintingMaterialPopup() {
    XCTAssertEqual(
      RufletTooltipPresentation.nativeHelpLimitations,
      [
        "decoration", "enable_feedback", "exclude_from_semantics", "exit_duration",
        "margin", "padding", "prefer_below", "show_duration", "size_constraints",
        "tap_to_dismiss", "text_align", "text_style", "trigger_mode", "vertical_offset",
        "wait_duration",
      ])
  }

  func testMouseCursorParserAcceptsEveryPinnedFletNameCaseInsensitively() {
    XCTAssertEqual(RufletMouseCursorName.allCases.count, 36)
    XCTAssertEqual(RufletMouseCursorName("ClIcK"), .click)
    XCTAssertEqual(RufletMouseCursorName("resizeUpLeftDownRight"), .resizeupleftdownright)
    XCTAssertNil(RufletMouseCursorName("not-a-flet-cursor"))
  }

  func testMouseRegionOnlyInstallsRegisteredFletEvents() {
    XCTAssertEqual(
      RufletGestureParity.mouseRegionEvents(ControlNode(id: 1, type: "GestureDetector")),
      [])
    XCTAssertEqual(
      RufletGestureParity.mouseRegionEvents(ControlNode(
        id: 2, type: "GestureDetector",
        props: ["on_enter": .bool(true), "on_exit": .bool(true)])),
      ["enter", "exit"])
  }

  func testMouseRegionPayloadMatchesFletPointerEventMap() throws {
    let enter = try XCTUnwrap(RufletGestureParity.mouseRegionPayload(
      local: CGPoint(x: 3, y: 4), global: CGPoint(x: 13, y: 14), timestamp: 50
    ).mapValue)
    XCTAssertEqual(
      Set(enter.keys),
      [
        "k", "l", "g", "ts", "dev", "ps", "pMin", "pMax", "dist", "distMax",
        "size", "rMj", "rMn", "rMin", "rMax", "or", "tilt", "ld",
      ])
    XCTAssertEqual(enter["k"], .string("mouse"))
    XCTAssertEqual(enter["l"], .map(["x": .double(3), "y": .double(4)]))
    XCTAssertEqual(enter["g"], .map(["x": .double(13), "y": .double(14)]))
    XCTAssertEqual(enter["ld"], .null)

    let hover = try XCTUnwrap(RufletGestureParity.mouseRegionPayload(
      local: CGPoint(x: 8, y: 10), global: CGPoint(x: 18, y: 20),
      previousLocal: CGPoint(x: 3, y: 4), timestamp: 55
    ).mapValue)
    XCTAssertEqual(hover["ld"], .map(["x": .double(5), "y": .double(6)]))
  }
}
