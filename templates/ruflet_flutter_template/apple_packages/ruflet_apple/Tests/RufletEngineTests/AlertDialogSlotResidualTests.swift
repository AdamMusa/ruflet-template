import RufletEngine
@testable import RufletUI
import XCTest

final class AlertDialogSlotResidualTests: XCTestCase {
  func testIconAloneDoesNotSatisfyPinnedAlertValidation() {
    let dialog = ControlNode(
      id: 1, type: "AlertDialog", props: ["icon": .controlRef(2)])
    XCTAssertFalse(RufletAlertDialogSlots.hasDisplayContract(dialog) { _ in true })
    XCTAssertEqual(
      RufletAlertDialogSlots.validationError(dialog) { _ in true },
      "AlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions.")

    let cupertino = ControlNode(id: 3, type: "CupertinoAlertDialog")
    XCTAssertEqual(
      RufletAlertDialogSlots.validationError(cupertino) { _ in true },
      "CupertinoAlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions.")
  }

  func testValidationCountsWireTitleButOnlyVisibleActions() {
    let title = ControlNode(
      id: 1, type: "AlertDialog", props: ["title": .controlRef(2)])
    XCTAssertTrue(RufletAlertDialogSlots.hasDisplayContract(title) { _ in false })

    let actions = ControlNode(
      id: 3, type: "AlertDialog", props: ["actions": .array([.controlRef(4)])])
    XCTAssertFalse(RufletAlertDialogSlots.hasDisplayContract(actions) { _ in false })
    XCTAssertTrue(RufletAlertDialogSlots.hasDisplayContract(actions) { _ in true })
  }

  func testRenderedSlotsFilterHiddenControlsWithoutReorderingActions() {
    let dialog = ControlNode(
      id: 1, type: "AlertDialog",
      props: [
        "title": .controlRef(2),
        "actions": .array([.controlRef(3), .controlRef(4), .controlRef(5)]),
      ])
    let visibility = { (id: Int) -> Bool? in id == 4 ? false : true }
    XCTAssertEqual(
      RufletAlertDialogSlots.visibleControlID(dialog, key: "title", visibilityForID: visibility), 2)
    XCTAssertEqual(
      RufletAlertDialogSlots.visibleActionIDs(dialog, visibilityForID: visibility), [3, 5])
  }

  func testRenderedSlotsAlsoFilterDanglingControlReferences() {
    let dialog = ControlNode(
      id: 1, type: "AlertDialog",
      props: [
        "content": .controlRef(2),
        "actions": .array([.controlRef(3), .controlRef(4)]),
      ])

    XCTAssertNil(
      RufletAlertDialogSlots.visibleControlID(
        dialog, key: "content", visibilityForID: { _ in nil }))
    XCTAssertEqual(
      RufletAlertDialogSlots.visibleActionIDs(
        dialog, visibilityForID: { $0 == 3 ? true : nil }),
      [3])
  }
}
