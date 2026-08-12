import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class CupertinoContextMenuResidualParityTests: XCTestCase {
  func testValidationFiltersHiddenSlotsAndPreservesPinnedErrorOrder() {
    let node = ControlNode(
      id: 1, type: "CupertinoContextMenu",
      props: [
        "content": .controlRef(10),
        "actions": .array([.controlRef(20), .controlRef(21)]),
      ])
    let visibility = [10: false, 20: false, 21: false]
    let presentation = CupertinoContextMenuPresentation(
      node: node, visibilityForID: { visibility[$0] })

    XCTAssertNil(presentation.contentID)
    XCTAssertEqual(presentation.actionIDs, [])
    XCTAssertEqual(
      presentation.validationError,
      "at least one action in CupertinoContextMenu.actions must be visible")
  }

  func testVisibleContentAndActionsRetainWireOrder() {
    let node = ControlNode(
      id: 2, type: "CupertinoContextMenu",
      props: [
        "content": .controlRef(10),
        "actions": .array([.controlRef(20), .controlRef(21), .controlRef(22)]),
        "enable_haptic_feedback": .bool(true),
      ])
    let visibility = [10: true, 20: true, 21: false, 22: true]
    let presentation = CupertinoContextMenuPresentation(
      node: node, visibilityForID: { visibility[$0] })

    XCTAssertEqual(presentation.contentID, 10)
    XCTAssertEqual(presentation.actionIDs, [20, 22])
    XCTAssertTrue(presentation.enableHapticFeedback)
    XCTAssertNil(presentation.validationError)
  }

  func testHapticFeedbackDefaultsFalseAndMissingContentHasExactError() {
    let node = ControlNode(
      id: 3, type: "CupertinoContextMenu",
      props: ["actions": .array([.controlRef(20)])])
    let presentation = CupertinoContextMenuPresentation(
      node: node, visibilityForID: { $0 == 20 ? true : nil })

    XCTAssertFalse(presentation.enableHapticFeedback)
    XCTAssertEqual(
      presentation.validationError,
      "CupertinoContextMenu.content must be visible")
  }

  func testActionContentAcceptsOnlyStringOrVisibleControl() {
    let text = CupertinoContextMenuActionPresentation(node: ControlNode(
      id: 4, type: "CupertinoContextMenuAction",
      props: ["content": .string("")]))
    XCTAssertEqual(text.text, "")
    XCTAssertNil(text.contentID)

    let hidden = CupertinoContextMenuActionPresentation(
      node: ControlNode(
        id: 5, type: "CupertinoContextMenuAction",
        props: ["content": .controlRef(30)]),
      visibilityForID: { _ in false })
    XCTAssertNil(hidden.text)
    XCTAssertNil(hidden.contentID)
    XCTAssertEqual(
      CupertinoContextMenuActionPresentation.missingContentError,
      "content (string or visible Control) must be provided")

    let dangling = CupertinoContextMenuActionPresentation(
      node: ControlNode(
        id: 9, type: "CupertinoContextMenuAction",
        props: ["content": .controlRef(31)]),
      visibilityForID: { _ in nil })
    XCTAssertNil(dangling.text)
    XCTAssertNil(dangling.contentID)

    let nonString = CupertinoContextMenuActionPresentation(node: ControlNode(
      id: 6, type: "CupertinoContextMenuAction",
      props: ["content": .int(123)]))
    XCTAssertNil(nonString.text)
    XCTAssertNil(nonString.contentID)
  }

  func testUnresolvedMenuSlotsAreAbsentLikeBuildWidgetResults() {
    let node = ControlNode(
      id: 10, type: "CupertinoContextMenu",
      props: [
        "content": .controlRef(11),
        "actions": .array([.controlRef(12)]),
      ])
    let presentation = CupertinoContextMenuPresentation(
      node: node, visibilityForID: { _ in nil })

    XCTAssertNil(presentation.contentID)
    XCTAssertEqual(presentation.actionIDs, [])
    XCTAssertEqual(
      presentation.validationError,
      "at least one action in CupertinoContextMenu.actions must be visible")
  }

  func testActionClickIsDisabledGatedAndUsesNullData() {
    var sent: [(Int, String, RufletValue)] = []
    let sink = RufletEventSink(send: { sent.append(($0, $1, $2)) })
    let enabled = ControlNode(
      id: 7, type: "CupertinoContextMenuAction",
      props: ["on_click": .bool(true)])
    let disabled = ControlNode(
      id: 8, type: "CupertinoContextMenuAction",
      props: ["on_click": .bool(true), "disabled": .bool(true)])

    CupertinoContextMenuActionPresentation.activate(enabled, through: sink)
    CupertinoContextMenuActionPresentation.activate(disabled, through: sink)

    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent.first?.0, 7)
    XCTAssertEqual(sent.first?.1, "click")
    XCTAssertEqual(sent.first?.2, .null)
  }
}
