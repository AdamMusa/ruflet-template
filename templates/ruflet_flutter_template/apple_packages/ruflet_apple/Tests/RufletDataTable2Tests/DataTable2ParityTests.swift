import RufletEngine
@testable import RufletDataTable2
@testable import RufletUI
import XCTest

@MainActor
final class DataTable2ParityTests: XCTestCase {
  func testManifestAndOptionalBoundaryMatchVendoredPackage() throws {
    let package = try XCTUnwrap(
      RufletExtensionManifest.packages.first { $0.fletPackage == "flet_datatable2" })
    XCTAssertEqual(package.swiftProduct, "RufletDataTable2")
    XCTAssertEqual(package.status, .available)
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "DataTable2")?.rendering,
      .optionalBundle("RufletDataTable2"))
  }

  func testExtensionReplacesFallbackWithoutRegisteringAService() {
    let registry = ServiceRegistry()
    registry.register(extension: RufletDataTable2.self)

    XCTAssertTrue(registry.hasExtension("RufletDataTable2"))
    XCTAssertFalse(registry.handles("DataTable2"))
    XCTAssertEqual(ControlRegistry.descriptor(for: "DataTable2")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DataTable2")?.implementation,
      "RufletDataTable2.DataTable2ControlView")
  }

  func testDefaultsMatchFletDataTable2Adapter() {
    let value = DataTable2Semantics(ControlNode(id: 1, type: "DataTable2"))
    XCTAssertEqual(value.fixedLeftColumns, 0)
    XCTAssertEqual(value.fixedTopRows, 1)
    XCTAssertEqual(value.smallRatio, 0.67)
    XCTAssertEqual(value.largeRatio, 1.2)
    XCTAssertTrue(value.showHeadingCheckbox)
    XCTAssertFalse(value.showBottomBorder)
    XCTAssertFalse(value.showCheckboxColumn)
    XCTAssertFalse(value.sortAscending)
    XCTAssertEqual(value.checkboxAlignment, "center")
    XCTAssertEqual(value.clipBehavior, "none")
    XCTAssertNil(value.visibleHorizontalScrollbar)
    XCTAssertNil(value.visibleVerticalScrollbar)
  }

  func testExplicitDataTableAndColumnPropertiesArePreserved() {
    let value = DataTable2Semantics(ControlNode(
      id: 1, type: "DataTable2", props: [
        "fixed_left_columns": .int(2), "fixed_top_rows": .int(3),
        "sm_ratio": .double(0.5), "lm_ratio": .double(1.75),
        "show_heading_checkbox": .bool(false), "show_bottom_border": .bool(true),
        "show_checkbox_column": .bool(true), "sort_ascending": .bool(true),
        "checkbox_alignment": .string("bottom_right"),
        "visible_horizontal_scroll_bar": .bool(false),
        "visible_vertical_scroll_bar": .bool(true), "min_width": .double(640),
        "bottom_margin": .double(24), "clip_behavior": .string("anti_alias"),
      ]))
    XCTAssertEqual(value.fixedLeftColumns, 2)
    XCTAssertEqual(value.fixedTopRows, 3)
    XCTAssertEqual(value.smallRatio, 0.5)
    XCTAssertEqual(value.largeRatio, 1.75)
    XCTAssertFalse(value.showHeadingCheckbox)
    XCTAssertTrue(value.showBottomBorder)
    XCTAssertTrue(value.showCheckboxColumn)
    XCTAssertTrue(value.sortAscending)
    XCTAssertEqual(value.minWidth, 640)
    XCTAssertEqual(value.bottomMargin, 24)

    XCTAssertEqual(
      value.width(of: ControlNode(id: 2, type: "DataColumn", props: [
        "size": .string("S"),
      ]), mediumWidth: 100), 50)
    XCTAssertEqual(
      value.width(of: ControlNode(id: 3, type: "DataColumn", props: [
        "size": .string("M"),
      ]), mediumWidth: 100), 100)
    XCTAssertEqual(
      value.width(of: ControlNode(id: 4, type: "DataColumn", props: [
        "size": .string("L"),
      ]), mediumWidth: 100), 175)
    XCTAssertEqual(
      value.width(of: ControlNode(id: 5, type: "DataColumn", props: [
        "fixed_width": .double(88),
      ]), mediumWidth: 100), 88)
  }

  func testSpecificRowHeightOverridesTableHeight() {
    let value = DataTable2Semantics(ControlNode(id: 1, type: "DataTable2"))
    XCTAssertEqual(
      value.height(of: ControlNode(id: 2, type: "DataRow", props: [
        "specific_row_height": .double(72),
      ]), fallback: 48), 72)
    XCTAssertEqual(value.height(of: ControlNode(id: 3, type: "DataRow"), fallback: 48), 48)
  }

  func testExplicitFixedDimensionsArePassedThroughWithoutRendererClamping() {
    let value = DataTable2Semantics(ControlNode(id: 1, type: "DataTable2"))
    XCTAssertEqual(
      value.width(of: ControlNode(id: 2, type: "DataColumn", props: [
        "fixed_width": .double(-8),
      ]), mediumWidth: 100), -8)
    XCTAssertEqual(
      value.height(of: ControlNode(id: 3, type: "DataRow", props: [
        "specific_row_height": .double(-4),
      ]), fallback: 48), -4)
  }

  func testLayoutDefaultsAndCheckboxWidthMatchDataTable2() {
    let layout = DataTable2LayoutMetrics(ControlNode(id: 1, type: "DataTable2"))
    XCTAssertEqual(layout.horizontalMargin, 24)
    XCTAssertEqual(layout.columnSpacing, 56)
    XCTAssertEqual(layout.smallRatio, 0.67)
    XCTAssertEqual(layout.largeRatio, 1.2)
    XCTAssertEqual(layout.checkboxWidth(visible: false), 0)
    XCTAssertEqual(layout.checkboxWidth(visible: true), 54)

    let custom = DataTable2LayoutMetrics(ControlNode(
      id: 2, type: "DataTable2", props: ["checkbox_horizontal_margin": .double(8)]))
    XCTAssertEqual(custom.checkboxWidth(visible: true), 30)
  }

  func testColumnWidthsUseDataTable2RatiosAndBakeMarginsIntoEdgeColumns() {
    let layout = DataTable2LayoutMetrics(ControlNode(id: 1, type: "DataTable2"))
    let columns = [
      ControlNode(id: 2, type: "DataColumn", props: ["size": .string("S")]),
      ControlNode(id: 3, type: "DataColumn", props: ["size": .string("M")]),
      ControlNode(id: 4, type: "DataColumn", props: ["size": .string("L")]),
    ]
    let widths = layout.columnWidths(
      availableWidth: 600, columns: columns, checkboxVisible: false)
    XCTAssertEqual(widths.reduce(0, +), 600, accuracy: 0.0001)
    XCTAssertEqual((widths[0] - 24) / widths[1], 0.67, accuracy: 0.0001)
    XCTAssertEqual((widths[2] - 24) / widths[1], 1.2, accuracy: 0.0001)

    let checkboxWidths = layout.columnWidths(
      availableWidth: 600, columns: columns, checkboxVisible: true)
    XCTAssertEqual(
      checkboxWidths.reduce(0, +) + layout.checkboxWidth(visible: true),
      600, accuracy: 0.0001)
  }

  func testFixedColumnWidthAndCellPaddingMatchDataTable2() {
    let layout = DataTable2LayoutMetrics(ControlNode(id: 1, type: "DataTable2"))
    let columns = [
      ControlNode(id: 2, type: "DataColumn", props: ["fixed_width": .double(80)]),
      ControlNode(id: 3, type: "DataColumn", props: ["size": .string("M")]),
    ]
    let widths = layout.columnWidths(
      availableWidth: 300, columns: columns, checkboxVisible: false)
    XCTAssertEqual(widths[0], 104, accuracy: 0.0001)
    XCTAssertEqual(widths.reduce(0, +), 300, accuracy: 0.0001)

    let first = layout.cellPadding(columnIndex: 0, columnCount: 3, checkboxVisible: false)
    XCTAssertEqual(first.leading, 24)
    XCTAssertEqual(first.trailing, 28)
    let firstAfterCheckbox = layout.cellPadding(
      columnIndex: 0, columnCount: 3, checkboxVisible: true)
    XCTAssertEqual(firstAfterCheckbox.leading, 12)
    XCTAssertEqual(firstAfterCheckbox.trailing, 28)
    let last = layout.cellPadding(columnIndex: 2, columnCount: 3, checkboxVisible: false)
    XCTAssertEqual(last.leading, 28)
    XCTAssertEqual(last.trailing, 24)
  }

  func testFixedColumnCountIncludesCheckboxAndDisablesStickyColumnsWhenEmpty() {
    let layout = DataTable2LayoutMetrics(ControlNode(id: 1, type: "DataTable2"))
    XCTAssertEqual(
      layout.fixedPartition(
        columnCount: 3, rowsAreEmpty: false, checkboxDeclared: true,
        checkboxVisible: true, fixedLeftColumns: 2),
      .init(checkboxIsFixed: true, fixedDataColumnCount: 1))
    XCTAssertEqual(
      layout.fixedPartition(
        columnCount: 3, rowsAreEmpty: false, checkboxDeclared: false,
        checkboxVisible: false, fixedLeftColumns: 2),
      .init(checkboxIsFixed: false, fixedDataColumnCount: 2))
    XCTAssertEqual(
      layout.fixedPartition(
        columnCount: 3, rowsAreEmpty: true, checkboxDeclared: true,
        checkboxVisible: false, fixedLeftColumns: 2),
      .init(checkboxIsFixed: false, fixedDataColumnCount: 0))
  }

  func testSelectAllFallbackTargetsOnlySelectableRowsThatNeedAChange() {
    let rows = [
      ControlNode(id: 2, type: "DataRow", props: [
        "on_select_change": .bool(true), "selected": .bool(true),
      ]),
      ControlNode(id: 3, type: "DataRow", props: [
        "on_select_change": .bool(true), "selected": .bool(false),
      ]),
      ControlNode(id: 4, type: "DataRow", props: ["selected": .bool(false)]),
    ]
    XCTAssertTrue(DataTable2SelectionSemantics.nextSelectAllValue(rows: rows))
    let selecting = DataTable2SelectionSemantics.fallbackRowChanges(
      rows: rows, selected: true)
    XCTAssertEqual(selecting.count, 1)
    XCTAssertEqual(selecting.first?.id, 3)
    XCTAssertEqual(selecting.first?.selected, true)

    let selectedRows = rows.map { row -> ControlNode in
      guard row.handlesEvent("select_change") else { return row }
      var changed = row
      changed.props["selected"] = .bool(true)
      return changed
    }
    XCTAssertFalse(DataTable2SelectionSemantics.nextSelectAllValue(rows: selectedRows))
  }

  func testTapDownPayloadMatchesFletEventMap() {
    XCTAssertEqual(
      DataTable2EventPayload.tapDown(
        kind: "touch", local: CGPoint(x: 2, y: 3), global: CGPoint(x: 12, y: 13)),
      .map([
        "k": .string("touch"),
        "l": .map(["x": .double(2), "y": .double(3)]),
        "g": .map(["x": .double(12), "y": .double(13)]),
      ]))
  }

  func testTooltipIconAndDurationParsersMatchFletAdapter() {
    XCTAssertEqual(
      DataTable2ColumnSemantics.tooltipMessage(ControlNode(
        id: 2, type: "DataColumn", props: ["tooltip": .string("Plain")])),
      "Plain")
    XCTAssertEqual(
      DataTable2ColumnSemantics.tooltipMessage(ControlNode(
        id: 3, type: "DataColumn", props: [
          "tooltip": .map(["message": .string("Structured")]),
        ])),
      "Structured")
    XCTAssertEqual(
      DataTable2ColumnSemantics.sortArrowRendering(ControlNode(
        id: 4, type: "DataTable2", props: ["sort_arrow_icon": .string("arrow_downward")])),
      .materialGlyph(codepoint: 0xe097, name: "ARROW_DOWNWARD"))

    XCTAssertEqual(
      DataTable2ColumnSemantics.sortArrowDurationSeconds(ControlNode(
        id: 5, type: "DataTable2")),
      0.00015, accuracy: 0.0000001)
    XCTAssertEqual(
      DataTable2ColumnSemantics.sortArrowDurationSeconds(ControlNode(
        id: 6, type: "DataTable2", props: [
          "sort_arrow_animation_duration": .int(150),
        ])),
      0.15, accuracy: 0.0000001)
    XCTAssertEqual(
      DataTable2ColumnSemantics.sortArrowDurationSeconds(ControlNode(
        id: 7, type: "DataTable2", props: [
          "sort_arrow_animation_duration": .map([
            "seconds": .int(1), "milliseconds": .int(250),
            "microseconds": .int(500),
          ]),
        ])),
      1.2505, accuracy: 0.0000001)
  }

  func testDescriptorAdvertisesFletDataTable2RowAndCellEvents() throws {
    let descriptor = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "DataTable2"))
    XCTAssertEqual(descriptor.supportedEvents, [
      "double_tap", "long_press", "secondary_tap", "secondary_tap_down",
      "select_all", "select_change", "sort", "tap", "tap_cancel", "tap_down",
    ])
  }
}
