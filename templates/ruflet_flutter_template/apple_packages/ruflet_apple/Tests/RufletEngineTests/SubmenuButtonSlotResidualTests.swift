import RufletEngine
@testable import RufletUI
import XCTest

final class SubmenuButtonSlotResidualTests: XCTestCase {
  func testHiddenAndUnresolvedControlSlotsAreNotRendered() {
    let submenu = ControlNode(
      id: 1, type: "SubmenuButton",
      props: ["leading": .controlRef(2), "content": .controlRef(3), "trailing": .controlRef(4)])
    XCTAssertNil(SubmenuButtonSlots.visibleControlID(
      submenu, key: "leading", visibilityForID: { _ in false }))
    XCTAssertNil(SubmenuButtonSlots.visibleControlID(
      submenu, key: "content", visibilityForID: { _ in nil }))
  }

  func testVisibleSlotIdentityIsPreserved() {
    let submenu = ControlNode(
      id: 1, type: "SubmenuButton", props: ["trailing": .controlRef(4)])
    XCTAssertEqual(SubmenuButtonSlots.visibleControlID(
      submenu, key: "trailing", visibilityForID: { _ in true }), 4)
  }

  func testScalarContentMustBeAnActualString() {
    let string = ControlNode(
      id: 1, type: "SubmenuButton", props: ["content": .string("")])
    let number = ControlNode(
      id: 2, type: "SubmenuButton", props: ["content": .int(4)])
    if case .string? = string.props["content"] {} else { XCTFail("expected string") }
    if case .string? = number.props["content"] { XCTFail("integer must not become menu text") }
  }
}
