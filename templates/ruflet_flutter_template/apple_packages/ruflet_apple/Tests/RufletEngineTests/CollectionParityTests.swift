import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CollectionParityTests: XCTestCase {
  func testPinnedFletCollectionDefaultsAreResolvedWithoutScreenLiterals() {
    let list = CollectionDefaults.listView(ControlNode(id: 1, type: "ListView"))
    XCTAssertFalse(list.horizontal)
    XCTAssertEqual(list.spacing, 0)
    XCTAssertTrue(list.lazy)
    XCTAssertEqual(list.clipBehavior, "hardEdge")

    let grid = CollectionDefaults.gridView(ControlNode(id: 2, type: "GridView"))
    XCTAssertFalse(grid.horizontal)
    XCTAssertEqual(grid.spacing, 10)
    XCTAssertEqual(grid.runSpacing, 10)

    let page = CollectionDefaults.pageView(ControlNode(id: 3, type: "PageView"))
    XCTAssertTrue(page.horizontal)
    XCTAssertTrue(page.keepPage)
    XCTAssertTrue(page.padEnds)
    XCTAssertTrue(page.snap)
    XCTAssertEqual(page.viewportFraction, 1)

    let tabs = CollectionDefaults.tabBar(ControlNode(id: 4, type: "TabBar"))
    XCTAssertTrue(tabs.scrollable)
    XCTAssertEqual(tabs.indicatorThickness, 2)

    let table = CollectionDefaults.dataTable(ControlNode(id: 5, type: "DataTable"))
    XCTAssertEqual(table.columnSpacing, 56)
    XCTAssertEqual(table.horizontalMargin, 24)
    XCTAssertEqual(table.headingRowHeight, 56)
    XCTAssertEqual(table.dataRowMinHeight, 48)
    XCTAssertEqual(table.dataRowMaxHeight, 48)
    XCTAssertFalse(table.showBottomBorder)
    XCTAssertFalse(table.showCheckboxColumn)
  }

  func testExplicitCollectionPropertiesOverrideEveryFoundationalDefault() {
    let list = CollectionDefaults.listView(ControlNode(
      id: 1, type: "ListView", props: [
        "horizontal": .bool(true), "spacing": .double(7),
        "build_controls_on_demand": .bool(false), "scroll": .string("hidden"),
        "clip_behavior": .string("none")
      ]))
    XCTAssertTrue(list.horizontal)
    XCTAssertEqual(list.spacing, 7)
    XCTAssertFalse(list.lazy)
    XCTAssertFalse(list.showsIndicators)
    XCTAssertEqual(list.clipBehavior, "none")

    let grid = CollectionDefaults.gridView(ControlNode(
      id: 2, type: "GridView", props: [
        "horizontal": .bool(true), "spacing": .double(3), "run_spacing": .double(9)
      ]))
    XCTAssertTrue(grid.horizontal)
    XCTAssertEqual(grid.spacing, 3)
    XCTAssertEqual(grid.runSpacing, 9)

    let tile = CollectionDefaults.listTile(ControlNode(
      id: 3, type: "ListTile", props: [
        "horizontal_spacing": .double(5), "min_leading_width": .double(31),
        "min_vertical_padding": .double(2), "min_height": .double(64)
      ]))
    XCTAssertEqual(tile.horizontalTitleGap, 5)
    XCTAssertEqual(tile.minLeadingWidth, 31)
    XCTAssertEqual(tile.minVerticalPadding, 2)
    XCTAssertEqual(tile.minHeight, 64)

    let tab = CollectionDefaults.tabBar(ControlNode(
      id: 4, type: "TabBar", props: [
        "scrollable": .bool(false), "indicator_thickness": .double(5),
        "divider_height": .double(3)
      ]))
    XCTAssertFalse(tab.scrollable)
    XCTAssertEqual(tab.indicatorThickness, 5)
    XCTAssertEqual(tab.dividerHeight, 3)

    let table = CollectionDefaults.dataTable(ControlNode(
      id: 5, type: "DataTable", props: [
        "column_spacing": .double(13), "horizontal_margin": .double(17),
        "heading_row_height": .double(31), "data_row_min_height": .double(33),
        "data_row_max_height": .double(61), "divider_thickness": .double(4),
        "show_bottom_border": .bool(true), "show_checkbox_column": .bool(true)
      ]))
    XCTAssertEqual(table.columnSpacing, 13)
    XCTAssertEqual(table.horizontalMargin, 17)
    XCTAssertEqual(table.headingRowHeight, 31)
    XCTAssertEqual(table.dataRowMinHeight, 33)
    XCTAssertEqual(table.dataRowMaxHeight, 61)
    XCTAssertEqual(table.dividerThickness, 4)
    XCTAssertTrue(table.showBottomBorder)
    XCTAssertTrue(table.showCheckboxColumn)

    let page = CollectionDefaults.pageView(ControlNode(
      id: 6, type: "PageView", props: [
        "horizontal": .bool(false), "reverse": .bool(true), "keep_page": .bool(false),
        "pad_ends": .bool(false), "implicit_scrolling": .bool(true),
        "snap": .bool(false), "viewport_fraction": .double(0.75),
        "selected_index": .int(2), "clip_behavior": .string("none")
      ]))
    XCTAssertFalse(page.horizontal)
    XCTAssertTrue(page.reverse)
    XCTAssertFalse(page.keepPage)
    XCTAssertFalse(page.padEnds)
    XCTAssertTrue(page.implicitScrolling)
    XCTAssertFalse(page.snap)
    XCTAssertEqual(page.viewportFraction, 0.75)
    XCTAssertEqual(page.selectedIndex, 2)
    XCTAssertEqual(page.clipBehavior, "none")
  }

  func testListTileAndTabUseFlutterThemeMetricsWhenOmitted() {
    let oneLine = CollectionDefaults.listTile(ControlNode(id: 1, type: "ListTile"))
    XCTAssertEqual(oneLine.minHeight, 56)
    XCTAssertEqual(oneLine.horizontalTitleGap, 16)
    XCTAssertEqual(oneLine.minLeadingWidth, 24)

    let threeLine = CollectionDefaults.listTile(ControlNode(
      id: 2, type: "ListTile", props: ["is_three_line": .bool(true)]))
    XCTAssertEqual(threeLine.minHeight, 88)

    XCTAssertEqual(
      CollectionDefaults.tabHeight(ControlNode(id: 3, type: "Tab")), 46)
    XCTAssertEqual(
      CollectionDefaults.tabHeight(ControlNode(
        id: 4, type: "Tab", props: ["label": .string("Files"), "icon": .string("folder")])),
      72)
  }

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
