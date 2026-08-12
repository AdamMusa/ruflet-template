import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class WindowDragAreaParityTests: XCTestCase {
  func testWindowDragAreaRequiresPinnedContentSlot() {
    let missing = WindowDragAreaPresentation(
      node: ControlNode(id: 1, type: "WindowDragArea"))
    XCTAssertNil(missing.contentID)
    XCTAssertEqual(
      WindowDragAreaPresentation.missingContentError,
      "WindowDragArea.content must be provided and visible")

    let present = WindowDragAreaPresentation(
      node: ControlNode(
        id: 2, type: "WindowDragArea", props: ["content": .controlRef(7)]))
    XCTAssertEqual(present.contentID, 7)
    XCTAssertEqual(
      present.validationError(content: ControlNode(
        id: 7, type: "Container", props: ["visible": .bool(false)])),
      WindowDragAreaPresentation.missingContentError)
    XCTAssertNil(present.validationError(content: ControlNode(id: 7, type: "Container")))
  }

  func testWindowDragAreaUsesPinnedMaximizableDefault() {
    XCTAssertTrue(WindowDragAreaPresentation(
      node: ControlNode(id: 1, type: "WindowDragArea")).maximizable)
    XCTAssertFalse(WindowDragAreaPresentation(
      node: ControlNode(
        id: 2, type: "WindowDragArea",
        props: ["maximizable": .bool(false)])).maximizable)
    XCTAssertTrue(WindowDragAreaPresentation(
      node: ControlNode(id: 3, type: "WindowDragArea")).interactionEnabled)
    XCTAssertFalse(WindowDragAreaPresentation(
      node: ControlNode(
        id: 4, type: "WindowDragArea",
        props: ["disabled": .bool(true)])).interactionEnabled)
  }

  func testWindowDragAreaDoubleTapPayloadNamesResultingAction() {
    XCTAssertEqual(
      WindowDragAreaPresentation.doubleTapPayload(wasMaximized: false),
      .string("maximize"))
    XCTAssertEqual(
      WindowDragAreaPresentation.doubleTapPayload(wasMaximized: true),
      .string("unmaximize"))
  }

  func testDoubleTapUsesPinnedTimeoutAndSlopOnSecondPointerDown() {
    XCTAssertEqual(WindowDragAreaPresentation.doubleTapTimeout, 0.3)
    XCTAssertEqual(WindowDragAreaPresentation.doubleTapSlop, 100)
    XCTAssertTrue(WindowDragAreaPresentation.isDoubleTap(
      previousUpTime: 10, previousUpPosition: CGPoint(x: 20, y: 30),
      currentDownTime: 10.299, currentDownPosition: CGPoint(x: 80, y: 110)))
    XCTAssertFalse(WindowDragAreaPresentation.isDoubleTap(
      previousUpTime: 10, previousUpPosition: CGPoint(x: 20, y: 30),
      currentDownTime: 10.301, currentDownPosition: CGPoint(x: 20, y: 30)))
    XCTAssertFalse(WindowDragAreaPresentation.isDoubleTap(
      previousUpTime: 10, previousUpPosition: CGPoint(x: 20, y: 30),
      currentDownTime: 10.1, currentDownPosition: CGPoint(x: 121, y: 30)))
    XCTAssertFalse(WindowDragAreaPresentation.isDoubleTap(
      previousUpTime: nil, previousUpPosition: nil,
      currentDownTime: 10.1, currentDownPosition: .zero))
  }

  func testDragPayloadsMatchFletDetailsMaps() {
    XCTAssertEqual(
      WindowDragAreaPresentation.dragStartPayload(
        local: CGPoint(x: 2, y: 3), global: CGPoint(x: 20, y: 30), timestamp: 1.25),
      .map([
        "k": .string("mouse"),
        "l": .map(["x": .double(2), "y": .double(3)]),
        "g": .map(["x": .double(20), "y": .double(30)]),
        "ts": .double(1_250),
      ]))
    XCTAssertEqual(
      WindowDragAreaPresentation.dragEndPayload(
        local: CGPoint(x: 4, y: 5), global: CGPoint(x: 40, y: 50),
        velocity: CGVector(dx: 120, dy: -30)),
      .map([
        "l": .map(["x": .double(4), "y": .double(5)]),
        "g": .map(["x": .double(40), "y": .double(50)]),
        "v": .map(["x": .double(120), "y": .double(-30)]),
        "pv": .null,
      ]))
  }
}
