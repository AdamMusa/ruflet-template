import RufletProtocol
@testable import RufletUI
import XCTest

final class CollectionParityTests: XCTestCase {
  func testReorderUsesFlutterFinalIndexWhenMovingDown() {
    XCTAssertEqual(CollectionParity.reorderDestination(from: 1, insertionSlot: 4), 3)
    XCTAssertEqual(CollectionParity.reorderDestination(from: 4, insertionSlot: 1), 1)
  }

  func testTabsResolvePythonStyleNegativeIndices() {
    XCTAssertEqual(CollectionParity.normalizedIndex(-1, count: 4), 3)
    XCTAssertEqual(CollectionParity.normalizedIndex(-2, count: 4), 2)
    XCTAssertEqual(CollectionParity.normalizedIndex(99, count: 4), 3)
  }

  func testPageCommandsClampToMountedPageRange() {
    XCTAssertEqual(CollectionParity.clampedIndex(-1, count: 3), 0)
    XCTAssertEqual(CollectionParity.clampedIndex(3, count: 3), 2)
    XCTAssertEqual(CollectionParity.pageIndex(forOffset: 1.6, count: 3), 2)
    XCTAssertEqual(CollectionParity.clampedIndex(2, count: 0), 0)
  }

  func testDataCellTapDownUsesFletPointerShape() {
    XCTAssertEqual(
      CollectionParity.tapDownPayload(x: 12, y: 24),
      .map([
        "local_x": .double(12), "local_y": .double(24),
        "global_x": .double(12), "global_y": .double(24),
        "kind": .string("touch")
      ]))
  }

  func testCollectionDescriptorsExposeImperativeAndChildEventContracts() {
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "PageView")?.supportedMethods,
      Set(["go_to_page", "jump_to", "jump_to_page", "next_page", "previous_page"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Tabs")?.supportedMethods,
      Set(["move_to"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DataCell")?.supportedEvents,
      Set(["double_tap", "long_press", "tap", "tap_cancel", "tap_down"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DataRow")?.supportedEvents,
      Set(["long_press", "select_change"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DataColumn")?.supportedEvents,
      Set(["sort"]))
  }
}
