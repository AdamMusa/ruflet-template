import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CircleAvatarContentResidualTests: XCTestCase {
  func testHiddenAndDanglingControlContentAreAbsent() {
    let avatar = ControlNode(
      id: 1, type: "CircleAvatar", props: ["content": .controlRef(2)])
    XCTAssertEqual(RufletCircleAvatarContent(
      node: avatar, visibilityForID: { _ in false }), .empty)
    XCTAssertEqual(RufletCircleAvatarContent(
      node: avatar, visibilityForID: { _ in nil }), .empty)
  }

  func testVisibleControlAndEmptyStringRemainValid() {
    let avatar = ControlNode(
      id: 1, type: "CircleAvatar", props: ["content": .controlRef(2)])
    XCTAssertEqual(RufletCircleAvatarContent(
      node: avatar, visibilityForID: { _ in true }), .control(2))
    XCTAssertEqual(RufletCircleAvatarContent(node: ControlNode(
      id: 2, type: "CircleAvatar", props: ["content": .string("")])), .text(""))
  }

  func testNonStringScalarsDoNotBecomeAvatarText() {
    for value: RufletValue in [.int(1), .double(1.5), .bool(true)] {
      XCTAssertEqual(RufletCircleAvatarContent(node: ControlNode(
        id: 1, type: "CircleAvatar", props: ["content": value])), .empty)
    }
  }
}
