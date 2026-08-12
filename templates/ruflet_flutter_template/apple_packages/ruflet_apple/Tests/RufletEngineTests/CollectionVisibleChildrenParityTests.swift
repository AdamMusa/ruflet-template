import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CollectionVisibleChildrenParityTests: XCTestCase {
  func testListAndGridFilterInvisibleControlsBeforeReversalAndSpacing() {
    let nodes = [
      1: ControlNode(id: 1, type: "Text"),
      2: ControlNode(id: 2, type: "Text", props: ["visible": .bool(false)]),
      3: ControlNode(id: 3, type: "Text"),
    ]

    XCTAssertEqual(CollectionVisibleChildren.ids([1, 2, 3], in: nodes), [1, 3])
    XCTAssertEqual(
      CollectionVisibleChildren.ids([1, 2, 3], in: nodes, reverse: true), [3, 1])
  }

  func testInvisiblePrototypeIsAbsentLikeFletBuildWidget() {
    let nodes = [
      8: ControlNode(id: 8, type: "Text", props: ["visible": .bool(false)]),
      9: ControlNode(id: 9, type: "Text"),
    ]

    XCTAssertNil(CollectionVisibleChildren.visibleID(8, in: nodes))
    XCTAssertEqual(CollectionVisibleChildren.visibleID(9, in: nodes), 9)
    XCTAssertNil(CollectionVisibleChildren.visibleID(nil, in: nodes))
  }
}
