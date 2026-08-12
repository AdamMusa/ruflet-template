import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class ReorderablePageViewParityTests: XCTestCase {
  func testReorderableListUsesPinnedFletDefaults() {
    let values = CollectionDefaults.reorderableListView(
      ControlNode(id: 1, type: "ReorderableListView"))

    XCTAssertFalse(values.horizontal)
    XCTAssertFalse(values.reverse)
    XCTAssertNil(values.itemExtent)
    XCTAssertFalse(values.firstItemPrototype)
    XCTAssertEqual(values.clipBehavior, "hardEdge")
    XCTAssertNil(values.cacheExtent)
    XCTAssertEqual(values.anchor, 0)
    XCTAssertNil(values.autoScrollerVelocityScalar)
    XCTAssertTrue(values.lazy)
    XCTAssertTrue(values.showDefaultDragHandles)
    XCTAssertTrue(values.showsIndicators)
    XCTAssertNil(values.semanticChildCount)
    XCTAssertNil(values.headerID)
    XCTAssertNil(values.footerID)
  }

  func testReorderableListPreservesEveryRendererInput() {
    let values = CollectionDefaults.reorderableListView(ControlNode(
      id: 1, type: "ReorderableListView", props: [
        "horizontal": .bool(true), "reverse": .bool(true),
        "item_extent": .double(44), "first_item_prototype": .bool(true),
        "padding": .double(8), "clip_behavior": .string("none"),
        "cache_extent": .double(320), "anchor": .double(0.4),
        "auto_scroller_velocity_scalar": .double(12),
        "build_controls_on_demand": .bool(false),
        "show_default_drag_handles": .bool(false), "scroll": .string("hidden"),
        "semantic_child_count": .int(7),
        "header": .controlRef(90), "footer": .controlRef(91),
      ]))

    XCTAssertTrue(values.horizontal)
    XCTAssertTrue(values.reverse)
    XCTAssertEqual(values.itemExtent, 44)
    XCTAssertTrue(values.firstItemPrototype)
    XCTAssertEqual(values.padding.top, 8)
    XCTAssertEqual(values.padding.leading, 8)
    XCTAssertEqual(values.padding.bottom, 8)
    XCTAssertEqual(values.padding.trailing, 8)
    XCTAssertEqual(values.clipBehavior, "none")
    XCTAssertEqual(values.cacheExtent, 320)
    XCTAssertEqual(values.anchor, 0.4)
    XCTAssertEqual(values.autoScrollerVelocityScalar, 12)
    XCTAssertFalse(values.lazy)
    XCTAssertFalse(values.showDefaultDragHandles)
    XCTAssertFalse(values.showsIndicators)
    XCTAssertEqual(values.semanticChildCount, 7)
    XCTAssertEqual(values.headerID, 90)
    XCTAssertEqual(values.footerID, 91)
  }

  func testReverseChangesDirectionWithoutReversingReorderIndices() {
    XCTAssertEqual(
      ReorderableListParity.orderedChildren([10, 20, 30], reverse: true),
      [10, 20, 30])
    XCTAssertEqual(
      ReorderableListParity.moving([10, 20, 30], from: 0, over: 2),
      [20, 30, 10])
    XCTAssertEqual(
      ReorderableListParity.moving([10, 20, 30], from: 2, over: 0),
      [30, 10, 20])
  }

  func testReorderedModelSurvivesAnUnrelatedChildPatch() {
    XCTAssertEqual(
      ReorderableListParity.reconciledOrder([20, 30, 10], with: [10, 20, 30, 40]),
      [20, 30, 10, 40])
    XCTAssertEqual(
      ReorderableListParity.reconciledOrder([20, 30, 10], with: [10, 30]),
      [30, 10])
  }

  func testReorderWirePayloadsMatchFletShapes() {
    XCTAssertEqual(
      ReorderableListParity.reorderStartPayload(oldIndex: 2),
      .map(["old_index": .int(2)]))
    XCTAssertEqual(
      ReorderableListParity.reorderPayload(oldIndex: 2, newIndex: 0),
      .map(["old_index": .int(2), "new_index": .int(0)]))
    XCTAssertEqual(
      ReorderableListParity.reorderEndPayload(newIndex: 0),
      .map(["new_index": .int(0)]))
  }

  func testPageViewSelectionUsesFletUpdatePropertiesShape() {
    XCTAssertEqual(
      PageViewParity.selectionProperties(index: 3),
      ["selected_index": .int(3)])
  }

  func testPageViewKeepsPinnedControllerAndViewportDefaults() {
    let values = CollectionDefaults.pageView(ControlNode(id: 2, type: "PageView"))

    XCTAssertTrue(values.horizontal)
    XCTAssertFalse(values.reverse)
    XCTAssertTrue(values.keepPage)
    XCTAssertTrue(values.padEnds)
    XCTAssertFalse(values.implicitScrolling)
    XCTAssertTrue(values.snap)
    XCTAssertEqual(values.viewportFraction, 1)
    XCTAssertEqual(values.selectedIndex, 0)
    XCTAssertEqual(values.clipBehavior, "hardEdge")
  }

  func testPageViewCommandsRetainWireIndicesAndByteOffsetSemantics() {
    XCTAssertEqual(
      PageViewParity.pages([11, 22, 33]),
      [.init(index: 0, id: 11), .init(index: 1, id: 22), .init(index: 2, id: 33)])
    XCTAssertEqual(
      CollectionParity.pageIndex(forOffset: 149, pageExtent: 100, count: 3), 1)
    XCTAssertEqual(
      CollectionParity.pageIndex(forOffset: 151, pageExtent: 100, count: 3), 2)
  }
}
