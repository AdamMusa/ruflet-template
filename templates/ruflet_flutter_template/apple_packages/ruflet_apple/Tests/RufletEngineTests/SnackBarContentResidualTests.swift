import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class SnackBarContentResidualTests: XCTestCase {
  func testStringContentSatisfiesPinnedBuildTextOrWidgetContract() {
    for content: RufletValue in [.string("Saved"), .string("")] {
      let snack = ControlNode(id: 1, type: "SnackBar", props: ["content": content])
      XCTAssertNil(OverlayDefaults.snackBarValidation(snack, content: nil))
    }
  }

  func testNonStringScalarsDoNotBecomeInventedSnackBarText() {
    for content: RufletValue in [.int(1), .double(1.5), .bool(true)] {
      let snack = ControlNode(id: 1, type: "SnackBar", props: ["content": content])
      XCTAssertEqual(
        OverlayDefaults.snackBarValidation(snack, content: nil),
        "SnackBar.content must be provided and visible")
    }
  }

  func testControlContentMustResolveAndRemainVisible() {
    let snack = ControlNode(
      id: 1, type: "SnackBar", props: ["content": .controlRef(2)])
    XCTAssertEqual(
      OverlayDefaults.snackBarValidation(snack, content: nil),
      "SnackBar.content must be provided and visible")
    XCTAssertEqual(
      OverlayDefaults.snackBarValidation(
        snack, content: ControlNode(id: 2, type: "Text", props: ["visible": .bool(false)])),
      "SnackBar.content must be provided and visible")
    XCTAssertNil(OverlayDefaults.snackBarValidation(
      snack, content: ControlNode(id: 2, type: "Text")))
  }
}
