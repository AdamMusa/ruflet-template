import RufletEngine
@testable import RufletUI
import XCTest

final class BadgeContentResidualTests: XCTestCase {
  func testHiddenAndDanglingBadgeContentAreAbsent() {
    let badge = ControlNode(id: 1, type: "Badge", props: ["content": .controlRef(2)])
    XCTAssertNil(BadgeContentSlots.visibleControlID(badge, visibilityForID: { _ in false }))
    XCTAssertNil(BadgeContentSlots.visibleControlID(badge, visibilityForID: { _ in nil }))
  }

  func testVisibleBadgeContentKeepsItsIdentity() {
    let badge = ControlNode(id: 1, type: "Badge", props: ["content": .controlRef(2)])
    XCTAssertEqual(BadgeContentSlots.visibleControlID(badge, visibilityForID: { _ in true }), 2)
  }

  func testOnlyActualStringsBecomeStandaloneBadgeContent() {
    let text = ControlNode(id: 1, type: "Badge", props: ["content": .string("")])
    let number = ControlNode(id: 2, type: "Badge", props: ["content": .int(3)])
    if case .string? = text.props["content"] {} else { XCTFail("expected string") }
    if case .string? = number.props["content"] { XCTFail("integer must not become content") }
  }
}
