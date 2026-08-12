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
  }

  func testWindowDragAreaDoubleTapPayloadNamesResultingAction() {
    XCTAssertEqual(
      WindowDragAreaPresentation.doubleTapPayload(wasMaximized: false),
      .string("maximize"))
    XCTAssertEqual(
      WindowDragAreaPresentation.doubleTapPayload(wasMaximized: true),
      .string("unmaximize"))
  }
}
