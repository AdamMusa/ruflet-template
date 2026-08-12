import RufletEngine
@testable import RufletUI
import XCTest

final class SnackBarActionResidualTests: XCTestCase {
  func testSnackBarActionDefaultsItsLabelLikePinnedFlet() {
    XCTAssertEqual(
      SnackBarActionPresentation(node: ControlNode(id: 1, type: "SnackBarAction")).label,
      "Action")
    XCTAssertEqual(
      SnackBarActionPresentation(node: ControlNode(
        id: 2, type: "SnackBarAction", props: ["label": .string("")])).label,
      "")
  }

  func testSnackBarActionCallbackRemainsInstalledDespiteStructuralDisabledFlag() {
    XCTAssertFalse(SnackBarActionPresentation(node: ControlNode(
      id: 1, type: "SnackBarAction", props: ["disabled": .bool(true)])).isDisabled)
  }

  func testOtherDialogActionsRetainTheirDisabledContract() {
    XCTAssertTrue(SnackBarActionPresentation(node: ControlNode(
      id: 1, type: "DialogAction", props: ["disabled": .bool(true)])).isDisabled)
  }
}
