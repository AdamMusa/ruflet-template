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
    XCTAssertEqual(grid.runsCount, 1)
    XCTAssertNil(grid.maxExtent)

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

    let adaptiveGrid = CollectionDefaults.gridView(ControlNode(
      id: 20, type: "GridView", props: [
        "runs_count": .int(9), "max_extent": .double(120)
      ]))
    // Flet gives max_extent precedence over runs_count.
    XCTAssertEqual(adaptiveGrid.maxExtent, 120)

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

  func testMaterialListTileUsesPinnedMaterial3ConstructorAndThemeDefaults() {
    let base = ListTilePresentation(node: ControlNode(id: 1, type: "ListTile"))
    XCTAssertEqual(base.contentPadding.top, 0)
    XCTAssertEqual(base.contentPadding.leading, 16)
    XCTAssertEqual(base.contentPadding.bottom, 0)
    XCTAssertEqual(base.contentPadding.trailing, 24)
    XCTAssertEqual(base.horizontalTitleGap, 16)
    XCTAssertEqual(base.minLeadingWidth, 24)
    XCTAssertEqual(base.minHeight, 56)
    XCTAssertEqual(base.titleFontSize, 16)
    XCTAssertEqual(base.subtitleFontSize, 14)
    XCTAssertEqual(base.leadingTrailingFontSize, 11)
    XCTAssertEqual(base.shapeKind, .roundedRectangle)
    XCTAssertEqual(base.radii, RufletCornerRadii(uniform: 0))

    let dense = ListTilePresentation(node: ControlNode(
      id: 2, type: "ListTile",
      props: ["dense": .bool(true), "subtitle": .string("Details")]))
    XCTAssertEqual(dense.minHeight, 64)
    XCTAssertEqual(dense.titleFontSize, 13)
    XCTAssertEqual(dense.subtitleFontSize, 12)
  }

  func testStylelessMaterialListTileUsesNativeAppleRow() {
    XCTAssertFalse(ListTilePresentation(node: ControlNode(
      id: 1, type: "ListTile", props: [
        "title": .string("Settings"),
        "subtitle": .string("Application preferences"),
        "leading": .string("settings"),
      ])).requiresCustomRendering)
  }

  func testExplicitMaterialListTileVisualsPreserveCustomRoute() {
    for property in [
      "content_padding", "horizontal_spacing", "min_height", "dense", "shape",
      "bgcolor", "selected", "selected_color", "title_text_style", "visual_density",
    ] {
      let value: RufletValue
      switch property {
      case "dense", "selected": value = .bool(true)
      case "horizontal_spacing", "min_height": value = .double(12)
      default: value = .string("explicit")
      }
      XCTAssertTrue(ListTilePresentation(node: ControlNode(
        id: 1, type: "ListTile", props: [property: value])).requiresCustomRendering, property)
    }
  }

  func testMaterialListTileShapePreservesFletShapeAndBorderSide() {
    let tile = ListTilePresentation(node: ControlNode(
      id: 1, type: "ListTile",
      props: [
        "shape": .map([
          "_type": .string("stadium"),
          "radius": .double(13),
          "side": .map([
            "color": .string("red"), "width": .double(3),
            "style": .string("solid")
          ])
        ])
      ]))
    XCTAssertEqual(tile.shapeKind, .stadium)
    XCTAssertEqual(tile.radii, RufletCornerRadii(uniform: 13))
    XCTAssertEqual(tile.outlineWidth, 3)
  }

  func testCupertinoListTileUsesEachFlutterNativeLayoutVariant() {
    let base = CupertinoListTilePresentation(node: ControlNode(
      id: 1, type: "CupertinoListTile", props: ["title": .string("Title")]))
    XCTAssertEqual(base.leadingSize, 28)
    XCTAssertEqual(base.leadingToTitle, 16)
    XCTAssertEqual(base.minHeight, 44)
    XCTAssertEqual(base.contentPadding.leading, 20)
    XCTAssertEqual(base.contentPadding.trailing, 14)

    let baseSubtitle = CupertinoListTilePresentation(node: ControlNode(
      id: 2, type: "CupertinoListTile",
      props: ["title": .string("Title"), "subtitle": .string("Subtitle")]))
    XCTAssertEqual(baseSubtitle.minHeight, 48)
    XCTAssertEqual(baseSubtitle.subtitleFontSize, 12)

    let notchedLeading = CupertinoListTilePresentation(node: ControlNode(
      id: 3, type: "CupertinoListTile",
      props: [
        "title": .string("Title"), "subtitle": .string("Subtitle"),
        "leading": .string("settings"), "notched": .bool(true)
      ]))
    XCTAssertEqual(notchedLeading.leadingSize, 30)
    XCTAssertEqual(notchedLeading.leadingToTitle, 12)
    XCTAssertEqual(notchedLeading.minHeight, 54)
    XCTAssertEqual(notchedLeading.contentPadding.leading, 14)
    XCTAssertEqual(notchedLeading.subtitleFontSize, 14)

    let notchedWithoutLeading = CupertinoListTilePresentation(node: ControlNode(
      id: 4, type: "CupertinoListTile",
      props: ["title": .string("Title"), "notched": .bool(true)]))
    XCTAssertEqual(notchedWithoutLeading.minHeight, 50)
    XCTAssertEqual(notchedWithoutLeading.contentPadding.top, 10)
    XCTAssertEqual(notchedWithoutLeading.contentPadding.leading, 28)
    XCTAssertEqual(notchedWithoutLeading.contentPadding.bottom, 10)
  }

  func testCupertinoListTileRequiresVisibleTitleLikeFletErrorControl() {
    XCTAssertEqual(
      ListTilePresentation.validationMessage(ControlNode(id: 1, type: "CupertinoListTile")),
      "CupertinoListTile.title must be provided and visible")
    XCTAssertNil(ListTilePresentation.validationMessage(ControlNode(
      id: 2, type: "CupertinoListTile", props: ["title": .string("Settings")])))
    XCTAssertNil(ListTilePresentation.validationMessage(ControlNode(id: 3, type: "ListTile")))
  }

  func testListTileClicksNotifierIsInheritedEdgeTriggeredState() {
    let notifier = RufletListTileClickNotifier()
    XCTAssertEqual(notifier.generation, 0)
    notifier.click()
    XCTAssertEqual(notifier.generation, 1)
    notifier.click()
    XCTAssertEqual(notifier.generation, 2)
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

  func testStylelessTabBarUsesNativeAppleAppearance() {
    XCTAssertTrue(TabBarPresentation.usesNativeAppearance(ControlNode(
      id: 1, type: "TabBar")))
  }

  func testExplicitMaterialTabStripPropertiesPreserveCustomRoute() {
    for property in [
      "scrollable", "indicator_color", "indicator_thickness", "divider_color",
      "label_color", "label_text_style", "padding", "tab_alignment", "secondary",
    ] {
      let value: RufletValue = property == "secondary" || property == "scrollable"
        ? .bool(true) : .string("explicit")
      XCTAssertFalse(TabBarPresentation.usesNativeAppearance(ControlNode(
        id: 1, type: "TabBar", props: [property: value])), property)
    }
  }

  func testPageCommandsClampToMountedPageRange() {
    XCTAssertEqual(CollectionParity.clampedIndex(-1, count: 3), 0)
    XCTAssertEqual(CollectionParity.clampedIndex(3, count: 3), 2)
    XCTAssertEqual(
      CollectionParity.pageIndex(forOffset: 160, pageExtent: 100, count: 3), 2)
    XCTAssertEqual(
      CollectionParity.resolvedPageOffset(-1, pageExtent: 100, count: 3), 200)
    XCTAssertEqual(CollectionParity.clampedIndex(2, count: 0), 0)
  }

  func testPageViewReverseChangesAxisDirectionWithoutReorderingWireIndices() {
    XCTAssertEqual(
      PageViewParity.pages([10, 20, 30]),
      [.init(index: 0, id: 10), .init(index: 1, id: 20), .init(index: 2, id: 30)])
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
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "ListTile")?.supportedEvents,
      Set(["blur", "click", "focus", "long_press"]))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "CupertinoListTile")?.supportedEvents,
      Set(["click"]))
  }
}
