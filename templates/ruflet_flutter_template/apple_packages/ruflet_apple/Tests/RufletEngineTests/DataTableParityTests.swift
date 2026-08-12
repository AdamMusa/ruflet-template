import XCTest
@testable import RufletEngine
@testable import RufletUI

final class DataTableParityTests: XCTestCase {
  func testStylelessDataTableLeavesAppleGeometryUnspecified() {
    let values = DataTablePresentation.nativeMetrics(ControlNode(id: 1, type: "DataTable"))

    XCTAssertNil(values.columnSpacing)
    XCTAssertNil(values.horizontalMargin)
    XCTAssertNil(values.headingRowHeight)
    XCTAssertNil(values.dataRowMinHeight)
    XCTAssertNil(values.dataRowMaxHeight)
    XCTAssertNil(values.dividerThickness)
    XCTAssertNil(values.checkboxHorizontalMargin)
  }

  func testDataTableExplicitMetricsAndCheckboxMarginOverrideDefaults() {
    let node = ControlNode(
      id: 1, type: "DataTable", props: [
        "column_spacing": .double(18),
        "horizontal_margin": .double(30),
        "heading_row_height": .double(61),
        "data_row_min_height": .double(37),
        "data_row_max_height": .double(73),
        "divider_thickness": .double(2.5),
        "show_bottom_border": .bool(true),
        "show_checkbox_column": .bool(true),
        "checkbox_horizontal_margin": .double(9),
      ])
    let values = CollectionDefaults.dataTable(node)
    let native = DataTablePresentation.nativeMetrics(node)

    XCTAssertEqual(values.columnSpacing, 18)
    XCTAssertEqual(values.horizontalMargin, 30)
    XCTAssertEqual(values.headingRowHeight, 61)
    XCTAssertEqual(values.dataRowMinHeight, 37)
    XCTAssertEqual(values.dataRowMaxHeight, 73)
    XCTAssertEqual(values.dividerThickness, 2.5)
    XCTAssertTrue(values.showBottomBorder)
    XCTAssertTrue(values.showCheckboxColumn)
    XCTAssertEqual(values.checkboxMarginStart, 9)
    XCTAssertEqual(values.checkboxMarginEnd, 9)
    XCTAssertEqual(native.columnSpacing, 18)
    XCTAssertEqual(native.horizontalMargin, 30)
    XCTAssertEqual(native.headingRowHeight, 61)
    XCTAssertEqual(native.dataRowMinHeight, 37)
    XCTAssertEqual(native.dataRowMaxHeight, 73)
    XCTAssertEqual(native.dividerThickness, 2.5)
    XCTAssertEqual(native.checkboxHorizontalMargin, 9)
  }

  func testLegacyIOS15FallbackRetainsFletDataTableGeometry() {
    let values = CollectionDefaults.dataTable(ControlNode(id: 1, type: "DataTable"))

    let firstWithoutCheckbox = values.cellPadding(
      column: 0, columnCount: 3, checkboxVisible: false)
    XCTAssertEqual(firstWithoutCheckbox.leading, 24)
    XCTAssertEqual(firstWithoutCheckbox.trailing, 28)

    let firstWithCheckbox = values.cellPadding(
      column: 0, columnCount: 3, checkboxVisible: true)
    XCTAssertEqual(firstWithCheckbox.leading, 12)
    XCTAssertEqual(firstWithCheckbox.trailing, 28)

    let middle = values.cellPadding(column: 1, columnCount: 3, checkboxVisible: false)
    XCTAssertEqual(middle.leading, 28)
    XCTAssertEqual(middle.trailing, 28)

    let last = values.cellPadding(column: 2, columnCount: 3, checkboxVisible: false)
    XCTAssertEqual(last.leading, 28)
    XCTAssertEqual(last.trailing, 24)
  }

  func testSortCallbackAscendingArgumentMatchesFlutter() {
    XCTAssertTrue(DataTablePresentation.nextSortAscending(
      sortedColumn: nil, tappedColumn: 2, currentlyAscending: false))
    XCTAssertTrue(DataTablePresentation.nextSortAscending(
      sortedColumn: 1, tappedColumn: 2, currentlyAscending: false))
    XCTAssertFalse(DataTablePresentation.nextSortAscending(
      sortedColumn: 2, tappedColumn: 2, currentlyAscending: true))
    XCTAssertTrue(DataTablePresentation.nextSortAscending(
      sortedColumn: 2, tappedColumn: 2, currentlyAscending: false))
  }

  func testSelectAllOnlyCountsSelectableRowsAndIndeterminateSelectsAll() {
    let rows = [
      ControlNode(id: 1, type: "DataRow", props: [
        "selected": .bool(true), "on_select_change": .bool(true),
      ]),
      ControlNode(id: 2, type: "DataRow", props: [
        "selected": .bool(false), "on_select_change": .bool(true),
      ]),
      ControlNode(id: 3, type: "DataRow", props: ["selected": .bool(true)]),
    ]

    XCTAssertTrue(DataTablePresentation.nextSelectAllValue(rows: rows))
    let changes = DataTablePresentation.fallbackRowChanges(rows: rows, selected: true)
    XCTAssertEqual(changes.count, 1)
    XCTAssertEqual(changes.first?.id, 2)
    XCTAssertEqual(changes.first?.selected, true)

    let allSelected = [
      ControlNode(id: 1, type: "DataRow", props: [
        "selected": .bool(true), "on_select_change": .bool(true),
      ]),
      ControlNode(id: 2, type: "DataRow", props: [
        "selected": .bool(true), "on_select_change": .bool(true),
      ]),
    ]
    XCTAssertFalse(DataTablePresentation.nextSelectAllValue(rows: allSelected))
  }

  func testDataColumnTooltipSupportsStringAndFletTooltipControlShape() {
    XCTAssertEqual(DataTablePresentation.tooltipMessage(ControlNode(
      id: 1, type: "DataColumn", props: ["tooltip": .string("Sort name")])), "Sort name")
    XCTAssertEqual(DataTablePresentation.tooltipMessage(ControlNode(
      id: 2, type: "DataColumn", props: [
        "tooltip": .map(["message": .string("Sort amount")]),
      ])), "Sort amount")
  }

  func testAnyDataCellGestureSuppressesRowSelectionAndLongPressFallback() {
    for event in ["tap", "double_tap", "long_press", "tap_cancel", "tap_down"] {
      XCTAssertTrue(DataTablePresentation.cellOverridesRowInteraction(ControlNode(
        id: 1, type: "DataCell", props: ["on_\(event)": .bool(true)])))
    }
    XCTAssertFalse(DataTablePresentation.cellOverridesRowInteraction(ControlNode(
      id: 2, type: "DataCell")))
  }
}
