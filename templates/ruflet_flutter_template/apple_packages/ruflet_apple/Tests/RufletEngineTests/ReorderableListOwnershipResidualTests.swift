import RufletEngine
@testable import RufletUI
import XCTest

final class ReorderableListOwnershipResidualTests: XCTestCase {
  func testReorderModelUsesOnlyVisibleControlsSlot() {
    let list = ControlNode(id: 1, type: "ReorderableListView", props: [
      "controls": .array([.controlRef(10), .controlRef(11), .controlRef(12)]),
      "header": .controlRef(20),
      "footer": .controlRef(21),
    ])
    let nodes = [
      10: ControlNode(id: 10, type: "Text"),
      11: ControlNode(id: 11, type: "Text", props: ["visible": .bool(false)]),
      12: ControlNode(id: 12, type: "Text"),
      20: ControlNode(id: 20, type: "Text"),
      21: ControlNode(id: 21, type: "Text"),
    ]

    XCTAssertEqual(ReorderableListParity.visibleControlIDs(list, in: nodes), [10, 12])
    XCTAssertFalse(ReorderableListParity.visibleControlIDs(list, in: nodes).contains(20))
    XCTAssertFalse(ReorderableListParity.visibleControlIDs(list, in: nodes).contains(21))
  }

  func testReorderIndicesFollowVisibleRowsAfterHiddenRowsAreRemoved() {
    let list = ControlNode(id: 1, type: "ReorderableListView", props: [
      "controls": .array([.controlRef(10), .controlRef(11), .controlRef(12)]),
    ])
    let nodes = [
      10: ControlNode(id: 10, type: "Text", props: ["visible": .bool(false)]),
      11: ControlNode(id: 11, type: "Text"),
      12: ControlNode(id: 12, type: "Text"),
    ]
    let visible = ReorderableListParity.visibleControlIDs(list, in: nodes)

    XCTAssertEqual(visible, [11, 12])
    XCTAssertEqual(ReorderableListParity.moving(visible, from: 1, over: 0), [12, 11])
    XCTAssertEqual(
      ReorderableListParity.reorderPayload(oldIndex: 1, newIndex: 0),
      .map(["old_index": .int(1), "new_index": .int(0)]))
  }

  func testHiddenHeaderAndFooterDoNotRenderInDedicatedSlots() {
    let nodes = [
      20: ControlNode(id: 20, type: "Text", props: ["visible": .bool(false)]),
      21: ControlNode(id: 21, type: "Text"),
    ]

    XCTAssertNil(CollectionVisibleChildren.visibleID(20, in: nodes))
    XCTAssertEqual(CollectionVisibleChildren.visibleID(21, in: nodes), 21)
  }
}
