import RufletEngine
@testable import RufletUI
import XCTest

final class CupertinoActionSheetSlotResidualTests: XCTestCase {
  func testHiddenAndDanglingTitleMessageCancelSlotsAreAbsent() {
    let sheet = ControlNode(
      id: 1, type: "CupertinoActionSheet",
      props: ["title": .controlRef(2), "message": .controlRef(3), "cancel": .controlRef(4)])
    XCTAssertNil(CupertinoActionSheetSlots.visibleControlID(
      sheet, key: "title", visibilityForID: { _ in false }))
    XCTAssertNil(CupertinoActionSheetSlots.visibleControlID(
      sheet, key: "message", visibilityForID: { _ in nil }))
  }

  func testVisibleActionsRetainWireOrder() {
    let sheet = ControlNode(
      id: 1, type: "CupertinoActionSheet",
      props: ["actions": .array([.controlRef(2), .controlRef(3), .controlRef(4)])])
    XCTAssertEqual(CupertinoActionSheetSlots.visibleActionIDs(
      sheet, visibilityForID: { $0 == 3 ? false : true }), [2, 4])
  }

  func testOnlyActualStringIsAcceptedAsScalarText() {
    let title = ControlNode(
      id: 1, type: "CupertinoActionSheet", props: ["title": .string("")])
    let number = ControlNode(
      id: 2, type: "CupertinoActionSheet", props: ["title": .int(1)])
    if case .string? = title.props["title"] {} else { XCTFail("expected string") }
    if case .string? = number.props["title"] { XCTFail("integer must not become sheet text") }
  }
}
