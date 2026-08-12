import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CollectionParityTests: XCTestCase {
  func testPinnedFletCollectionDefaultsAreResolvedWithoutScreenLiterals() {
    let list = CollectionDefaults.listView(ControlNode(id: 1, type: "ListView"))
    XCTAssertFalse(list.horizontal)
    XCTAssertEqual(list.spacing, 0)
    XCTAssertEqual(list.dividerThickness, 0)
    XCTAssertNil(list.itemExtent)
    XCTAssertNil(list.cacheExtent)
    XCTAssertNil(list.semanticChildCount)
    XCTAssertFalse(list.reverse)
    XCTAssertFalse(list.firstItemPrototype)
    XCTAssertFalse(list.usesPrototype)
    XCTAssertTrue(list.lazy)
    XCTAssertEqual(list.clipBehavior, "hardEdge")

    let grid = CollectionDefaults.gridView(ControlNode(id: 2, type: "GridView"))
    XCTAssertFalse(grid.horizontal)
    XCTAssertEqual(grid.spacing, 10)
    XCTAssertEqual(grid.runSpacing, 10)
    XCTAssertEqual(grid.childAspectRatio, 1)
    XCTAssertNil(grid.cacheExtent)
    XCTAssertNil(grid.semanticChildCount)
    XCTAssertFalse(grid.reverse)
    XCTAssertTrue(grid.lazy)
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
    XCTAssertFalse(tabs.secondary)
    XCTAssertEqual(tabs.indicatorThickness, 2)
    XCTAssertEqual(tabs.effectiveIndicatorThickness, 3)
    XCTAssertEqual(tabs.indicatorSizeToken, "label")
    XCTAssertEqual(tabs.indicatorAnimationToken, "elastic")
    XCTAssertEqual(tabs.indicatorColorToken, "primary")
    XCTAssertEqual(tabs.dividerColorToken, "outlinevariant")
    XCTAssertEqual(tabs.dividerHeight, 1)
    XCTAssertTrue(tabs.showsDivider)
    XCTAssertEqual(tabs.labelColorToken, "primary")
    XCTAssertEqual(tabs.unselectedLabelColorToken, "onsurfacevariant")
    XCTAssertEqual(tabs.labelTextStyleToken, "titlesmall")
    XCTAssertEqual(tabs.unselectedLabelTextStyleToken, "titlesmall")
    XCTAssertEqual(tabs.tabAlignmentToken, "startOffset")
    XCTAssertTrue(tabs.enableFeedback)

    let table = CollectionDefaults.dataTable(ControlNode(id: 5, type: "DataTable"))
    XCTAssertEqual(table.columnSpacing, 56)
    XCTAssertEqual(table.horizontalMargin, 24)
    XCTAssertEqual(table.headingRowHeight, 56)
    XCTAssertEqual(table.dataRowMinHeight, 48)
    XCTAssertEqual(table.dataRowMaxHeight, 48)
    XCTAssertFalse(table.showBottomBorder)
    XCTAssertFalse(table.showCheckboxColumn)
  }

  func testListViewSeparatedConstructorSuppressesExtentAndPrototypeLikeFlet() {
    let separated = CollectionDefaults.listView(ControlNode(
      id: 1, type: "ListView", props: [
        "spacing": .double(12),
        "divider_thickness": .double(2),
        "item_extent": .double(44),
        "first_item_prototype": .bool(true),
        "prototype_item": .controlRef(91),
        "cache_extent": .double(320),
        "semantic_child_count": .int(7),
      ]))

    XCTAssertEqual(separated.spacing, 12)
    XCTAssertEqual(separated.dividerThickness, 2)
    XCTAssertNil(separated.itemExtent)
    XCTAssertFalse(separated.usesPrototype)
    XCTAssertEqual(separated.cacheExtent, 320)
    XCTAssertEqual(separated.semanticChildCount, 7)
  }

  func testListViewBuilderRetainsFletExtentAndPrototypeContractsWithoutFixedFallback() {
    let fixed = CollectionDefaults.listView(ControlNode(
      id: 1, type: "ListView", props: [
        "item_extent": .double(44),
        "first_item_prototype": .bool(true),
        "prototype_item": .controlRef(91),
        "reverse": .bool(true),
      ]))

    XCTAssertEqual(fixed.itemExtent, 44)
    XCTAssertTrue(fixed.usesPrototype)
    XCTAssertEqual(fixed.prototypeItemID, 91)
    XCTAssertTrue(fixed.reverse)
  }

  func testGridViewPreservesPinnedDelegateAndBuilderInputs() {
    let grid = CollectionDefaults.gridView(ControlNode(
      id: 1, type: "GridView", props: [
        "child_aspect_ratio": .double(1.75),
        "cache_extent": .double(280),
        "semantic_child_count": .int(9),
        "reverse": .bool(true),
        "build_controls_on_demand": .bool(false),
      ]))

    XCTAssertEqual(grid.childAspectRatio, 1.75)
    XCTAssertEqual(grid.cacheExtent, 280)
    XCTAssertEqual(grid.semanticChildCount, 9)
    XCTAssertTrue(grid.reverse)
    XCTAssertFalse(grid.lazy)
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
    XCTAssertEqual(CollectionGridGeometry.crossAxisCount(
      availableExtent: 351, spacing: 10, runsCount: 9, maxExtent: 220), 2)
    XCTAssertEqual(CollectionGridGeometry.crossAxisCount(
      availableExtent: 760, spacing: 10, runsCount: 9, maxExtent: 220), 4)
    XCTAssertEqual(CollectionGridGeometry.crossAxisCount(
      availableExtent: 351, spacing: 10, runsCount: 3, maxExtent: nil), 3)

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

  func testNativeListTilePreservesLeadingAndTrailingTextStyle() {
    let tile = ListTilePresentation(node: ControlNode(
      id: 1, type: "ListTile", props: [
        "title": .string("Settings"),
        "leading": .string("settings"),
        "trailing": .string("chevron_right"),
        "leading_and_trailing_text_style": .map([
          "size": .double(21), "weight": .string("bold"),
        ]),
      ]))

    // This semantic style is representable by native SwiftUI content and must
    // not force the handwritten Material row. Both control and icon/string
    // slots receive the same parsed style in `nativeTileContents`.
    XCTAssertFalse(tile.requiresCustomRendering)
    XCTAssertEqual(tile.leadingTrailingTextStyle?.size, 21)
    XCTAssertEqual(tile.leadingTrailingTextStyle?.weight, .bold)
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
    let reference = ControlNode(
      id: 4, type: "CupertinoListTile", props: ["title": .controlRef(40)])
    XCTAssertEqual(
      ListTilePresentation.validationMessage(
        reference, title: ControlNode(
          id: 40, type: "Text", props: ["visible": .bool(false)])),
      "CupertinoListTile.title must be provided and visible")
    XCTAssertNil(ListTilePresentation.validationMessage(
      reference, title: ControlNode(id: 40, type: "Text")))
    XCTAssertNil(ListTilePresentation.validationMessage(ControlNode(
      id: 5, type: "CupertinoListTile", props: ["title": .string("")])))
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

  func testTabsLengthObserverClampsAgainstDeliveredLength() {
    XCTAssertEqual(TabsPresentation.preservedIndex(4, forDeliveredLength: 2), 1)
    XCTAssertEqual(TabsPresentation.preservedIndex(1, forDeliveredLength: 5), 1)
  }

  func testAutoScrollTargetsTheDeliveredChildCollection() {
    XCTAssertEqual(CollectionAutoScrollTarget.lastID(in: [10, 20, 30]), 30)
    XCTAssertNil(CollectionAutoScrollTarget.lastID(in: []))
  }

  func testTabsKeepPinnedFletControllerDefaultsAndValidation() {
    let defaults = TabsPresentation(node: ControlNode(
      id: 1, type: "Tabs", props: [
        "length": .int(3), "selected_index": .int(-1), "content": .controlRef(9)
      ]))
    XCTAssertEqual(defaults.length, 3)
    XCTAssertEqual(defaults.rawSelectedIndex, -1)
    XCTAssertEqual(defaults.selectedIndex, 2)
    XCTAssertEqual(defaults.animationDuration, 0.1)
    XCTAssertEqual(TabsPresentation.moveDefaultCurveToken, "easeIn")
    XCTAssertNil(TabsPresentation.validationMessage(defaults.node))

    XCTAssertEqual(
      TabsPresentation.validationMessage(ControlNode(
        id: 2, type: "Tabs", props: [
          "length": .int(-1), "selected_index": .int(0), "content": .controlRef(9)
        ])),
      "length must be greater than or equal to 0, got -1")
    XCTAssertEqual(
      TabsPresentation.validationMessage(ControlNode(
        id: 3, type: "Tabs", props: [
          "length": .int(3), "selected_index": .int(3), "content": .controlRef(9)
        ])),
      "selected_index out of range: got 3, expected in range [-3, 2]")
    XCTAssertEqual(
      TabsPresentation.validationMessage(ControlNode(
        id: 4, type: "Tabs", props: ["length": .int(2)])),
      "Tabs.content must be provided and visible")
    XCTAssertEqual(
      TabsPresentation.validationMessage(defaults.node, contentIsVisible: false),
      "Tabs.content must be provided and visible")
    XCTAssertNil(TabsPresentation.moveValidationMessage(index: -1, length: 3))
    XCTAssertEqual(
      TabsPresentation.moveValidationMessage(index: 3, length: 3),
      "index out of range: got 3, expected in range [-3, 2]")
  }

  func testEveryTabBarPropertyKeepsNativeAppleAppearance() {
    XCTAssertTrue(TabBarPresentation.usesNativeAppearance(ControlNode(
      id: 1, type: "TabBar")))
    XCTAssertEqual(
      TabBarPresentation.ancestorError,
      "TabBar must be used within a Tabs control")
    XCTAssertEqual(
      TabBarViewPresentation.ancestorError,
      "TabBarView must be used within a Tabs control")
    XCTAssertEqual(CollectionDefaults.tabIconSize, 24)
    for property in [
      "scrollable", "indicator", "indicator_color", "indicator_thickness",
      "indicator_size", "indicator_animation", "divider_color", "divider_height",
      "label_color", "unselected_label_color", "label_text_style",
      "unselected_label_text_style", "label_padding", "padding", "overlay_color",
      "splash_border_radius", "tab_alignment", "secondary", "enable_feedback",
    ] {
      let value: RufletValue
      switch property {
      case "secondary", "scrollable", "enable_feedback": value = .bool(true)
      case "indicator_thickness", "divider_height": value = .double(4)
      case "indicator", "label_text_style", "unselected_label_text_style":
        value = .map([:])
      default: value = .string("explicit")
      }
      XCTAssertTrue(TabBarPresentation.usesNativeAppearance(ControlNode(
        id: 1, type: "TabBar", props: [property: value])), property)
    }
  }

  func testTabBarMaterial3SemanticDefaultsTrackPrimaryAndSecondaryConstructors() {
    let primary = CollectionDefaults.tabBar(ControlNode(id: 1, type: "TabBar"))
    XCTAssertEqual(primary.indicatorSizeToken, "label")
    XCTAssertEqual(primary.indicatorAnimationToken, "elastic")
    XCTAssertEqual(primary.effectiveIndicatorThickness, 3)
    XCTAssertEqual(primary.labelColorToken, "primary")
    XCTAssertEqual(primary.tabAlignmentToken, "startOffset")
    XCTAssertTrue(primary.showsDivider)

    let secondary = CollectionDefaults.tabBar(ControlNode(
      id: 2, type: "TabBar", props: [
        "secondary": .bool(true), "scrollable": .bool(false)
      ]))
    XCTAssertTrue(secondary.secondary)
    XCTAssertEqual(secondary.indicatorSizeToken, "tab")
    XCTAssertEqual(secondary.indicatorAnimationToken, "linear")
    XCTAssertEqual(secondary.effectiveIndicatorThickness, 2)
    XCTAssertEqual(secondary.labelColorToken, "onsurface")
    XCTAssertEqual(secondary.tabAlignmentToken, "fill")
    XCTAssertTrue(secondary.showsDivider)
  }

  func testTabBarConsumesFletSplashBorderRadiusWithoutReplacingNativePicker() {
    let values = CollectionDefaults.tabBar(ControlNode(
      id: 1, type: "TabBar", props: [
        "splash_border_radius": .map([
          "top_left": .double(2), "top_right": .double(4),
          "bottom_left": .double(6), "bottom_right": .double(8),
        ])
      ]))
    XCTAssertEqual(
      values.splashBorderRadius,
      RufletCornerRadii(topLeft: 2, topRight: 4, bottomLeft: 6, bottomRight: 8))
    XCTAssertTrue(TabBarPresentation.usesNativeAppearance(ControlNode(id: 1, type: "TabBar")))
  }

  func testTabBarExplicitSemanticsOverrideEveryPinnedDefault() {
    let values = CollectionDefaults.tabBar(ControlNode(
      id: 1, type: "TabBar", props: [
        "scrollable": .bool(false), "secondary": .bool(true),
        "indicator_thickness": .double(5), "indicator_size": .string("label"),
        "indicator_animation": .string("linear"),
        "indicator_padding": .map([
          "top": .double(1), "left": .double(2),
          "bottom": .double(3), "right": .double(4)
        ]),
        "indicator_color": .string("red"), "divider_height": .double(6),
        "divider_color": .string("blue"), "label_color": .string("green"),
        "unselected_label_color": .string("amber"),
        "label_text_style": .map(["theme_style": .string("bodyLarge")]),
        "unselected_label_text_style": .map(["theme_style": .string("bodySmall")]),
        "tab_alignment": .string("center"), "enable_feedback": .bool(false),
      ]))
    XCTAssertFalse(values.scrollable)
    XCTAssertTrue(values.secondary)
    XCTAssertEqual(values.indicatorThickness, 5)
    XCTAssertEqual(values.effectiveIndicatorThickness, 5)
    XCTAssertEqual(values.indicatorSizeToken, "label")
    XCTAssertEqual(values.indicatorAnimationToken, "linear")
    XCTAssertEqual(values.indicatorPadding.top, 1)
    XCTAssertEqual(values.indicatorPadding.leading, 2)
    XCTAssertEqual(values.indicatorPadding.bottom, 3)
    XCTAssertEqual(values.indicatorPadding.trailing, 4)
    XCTAssertEqual(values.indicatorColorToken, "red")
    XCTAssertEqual(values.dividerHeight, 6)
    XCTAssertEqual(values.dividerColorToken, "blue")
    XCTAssertEqual(values.labelColorToken, "green")
    XCTAssertEqual(values.unselectedLabelColorToken, "amber")
    XCTAssertEqual(values.labelTextStyleToken, "bodyLarge")
    XCTAssertEqual(values.unselectedLabelTextStyleToken, "bodySmall")
    XCTAssertEqual(values.tabAlignmentToken, "center")
    XCTAssertFalse(values.enableFeedback)
  }

  func testTabBarAndTabImplementFletValidationMessages() {
    XCTAssertEqual(
      TabBarPresentation.validationMessage(ControlNode(
        id: 1, type: "TabBar", props: ["indicator_thickness": .double(0)])),
      "indicator_thickness must be strictly greater than zero if indicator is None, got 0.0")
    XCTAssertNil(TabBarPresentation.validationMessage(ControlNode(
      id: 2, type: "TabBar", props: [
        "indicator": .map([:]), "indicator_thickness": .double(0)
      ])))
    XCTAssertEqual(
      TabBarPresentation.validationMessage(ControlNode(
        id: 3, type: "TabBar", props: ["tab_alignment": .string("fill")])),
      "If scrollable is True, tab_alignment must be one of: TabAlignment.START, TabAlignment.START_OFFSET, TabAlignment.CENTER.")
    XCTAssertEqual(
      TabBarPresentation.validationMessage(ControlNode(
        id: 4, type: "TabBar", props: [
          "scrollable": .bool(false), "tab_alignment": .string("start")
        ])),
      "If scrollable is False, tab_alignment must be one of: TabAlignment.CENTER, TabAlignment.FILL.")
    XCTAssertEqual(
      TabPresentation.validationMessage(ControlNode(id: 5, type: "Tab")),
      "Tab must have at least label or icon property set")
    XCTAssertNil(TabPresentation.validationMessage(ControlNode(
      id: 6, type: "Tab", props: ["icon": .string("settings")])))
    XCTAssertNil(TabPresentation.validationMessage(ControlNode(
      id: 7, type: "Text", props: ["value": .string("Custom tab")])))
  }

  func testTabAndTabBarViewKeepFlutterConstructorDefaults() {
    let textTab = TabPresentation(node: ControlNode(
      id: 1, type: "Tab", props: ["label": .string("Files")]))
    XCTAssertEqual(textTab.height, 46)
    XCTAssertEqual(textTab.iconMargin.bottom, 2)

    let combined = TabPresentation(node: ControlNode(
      id: 2, type: "Tab", props: [
        "label": .string("Files"), "icon": .string("folder")
      ]))
    XCTAssertEqual(combined.height, 72)

    let explicit = TabPresentation(node: ControlNode(
      id: 3, type: "Tab", props: [
        "label": .string("Files"), "icon": .string("folder"),
        "height": .double(80),
        "icon_margin": .map(["bottom": .double(9)])
      ]))
    XCTAssertEqual(explicit.height, 80)
    XCTAssertEqual(explicit.iconMargin.bottom, 9)

    let view = TabBarViewPresentation(node: ControlNode(id: 4, type: "TabBarView"))
    XCTAssertEqual(view.clipBehaviorToken, "hardEdge")
    XCTAssertEqual(view.viewportFraction, 1)
    let customView = TabBarViewPresentation(node: ControlNode(
      id: 5, type: "TabBarView", props: [
        "clip_behavior": .string("none"), "viewport_fraction": .double(0.75)
      ]))
    XCTAssertEqual(customView.clipBehaviorToken, "none")
    XCTAssertEqual(customView.viewportFraction, 0.75)
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
