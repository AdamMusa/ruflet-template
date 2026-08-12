import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class CupertinoDialogActionResidualParityTests: XCTestCase {
  func testDialogActionRequiresStringOrVisibleControlWithExactError() {
    let hidden = CupertinoDialogActionPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoDialogAction",
        props: ["content": .controlRef(10)]),
      visibilityForID: { _ in false })

    XCTAssertNil(hidden.contentID)
    XCTAssertNil(hidden.text)
    XCTAssertEqual(
      hidden.validationError,
      "CupertinoDialogAction.content must be a string or visible Control")
  }

  func testStringContentMustStayAStringRatherThanCoercingOtherWireTypes() {
    let empty = CupertinoDialogActionPresentation(node: ControlNode(
      id: 2, type: "CupertinoDialogAction",
      props: ["content": .string("")]))
    XCTAssertEqual(empty.text, "")
    XCTAssertNil(empty.validationError)

    let number = CupertinoDialogActionPresentation(node: ControlNode(
      id: 3, type: "CupertinoDialogAction",
      props: ["content": .int(123)]))
    XCTAssertNil(number.text)
    XCTAssertEqual(
      number.validationError,
      CupertinoDialogActionPresentation.dialogMissingContentError)
  }

  func testVisibleControlAndActionFlagsUsePinnedWireNames() {
    let presentation = CupertinoDialogActionPresentation(
      node: ControlNode(
        id: 4, type: "CupertinoDialogAction",
        props: [
          "content": .controlRef(11),
          "default": .bool(true), "destructive": .bool(true),
          "disabled": .bool(true),
        ]),
      visibilityForID: { _ in true })

    XCTAssertEqual(presentation.contentID, 11)
    XCTAssertTrue(presentation.isDefault)
    XCTAssertTrue(presentation.isDestructive)
    XCTAssertTrue(presentation.disabled)
    XCTAssertNil(presentation.validationError)
  }

  func testAliasesDoNotBecomeCupertinoActionRoles() {
    let presentation = CupertinoDialogActionPresentation(node: ControlNode(
      id: 5, type: "CupertinoDialogAction",
      props: [
        "content": .string("Continue"),
        "is_default_action": .bool(true),
        "is_destructive_action": .bool(true),
      ]))

    XCTAssertFalse(presentation.isDefault)
    XCTAssertFalse(presentation.isDestructive)
  }

  func testClickUsesNullDataAndInheritedDisabledGating() {
    var sent: [(Int, String, RufletValue)] = []
    let sink = RufletEventSink(send: { sent.append(($0, $1, $2)) })
    let enabled = ControlNode(
      id: 6, type: "CupertinoDialogAction",
      props: ["on_click": .bool(true)])
    let inheritedDisabled = ControlNode(
      id: 7, type: "CupertinoDialogAction",
      props: ["on_click": .bool(true)],
      internals: ["_flet_resolved_disabled": .bool(true)])

    CupertinoDialogActionPresentation.activate(enabled, through: sink)
    CupertinoDialogActionPresentation.activate(inheritedDisabled, through: sink)

    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent.first?.0, 6)
    XCTAssertEqual(sent.first?.1, "click")
    XCTAssertEqual(sent.first?.2, .null)
  }

  func testSiblingCupertinoActionsKeepTheirSourceSpecificErrors() {
    let sheet = CupertinoDialogActionPresentation(node: ControlNode(
      id: 8, type: "CupertinoActionSheetAction"))
    let menu = CupertinoDialogActionPresentation(node: ControlNode(
      id: 9, type: "CupertinoContextMenuAction"))

    XCTAssertEqual(
      sheet.validationError,
      "CupertinoActionSheetAction.content must be a string or visible Control")
    XCTAssertEqual(
      menu.validationError,
      "content (string or visible Control) must be provided")
  }
}
