import Foundation
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

@MainActor
final class DataTableControlTests: XCTestCase {
  func testStructureUsesVisibleChildrenAndMarksEveryOwnerForParentInvalidation() {
    let backend = DataTableTestBackend()
    let table = backend.control(
      type: "DataTable",
      properties: [
        "columns": .array([
          dataTableWireControl(id: 2, type: "DataColumn"),
          dataTableWireControl(
            id: 3, type: "DataColumn", properties: ["visible": .bool(false)]),
          dataTableWireControl(id: 4, type: "DataColumn"),
        ]),
        "rows": .array([
          dataTableWireControl(
            id: 5,
            type: "DataRow",
            properties: [
              "cells": .array([
                dataTableWireControl(id: 6, type: "DataCell"),
                dataTableWireControl(
                  id: 7, type: "DataCell", properties: ["visible": .bool(false)]),
                dataTableWireControl(id: 8, type: "DataCell"),
              ])
            ]),
          dataTableWireControl(
            id: 9, type: "DataRow", properties: ["visible": .bool(false)]),
        ]),
      ])

    let structure = RufletDataTableStructure(control: table)

    XCTAssertEqual(structure.columns.map(\.id), [2, 4])
    XCTAssertEqual(structure.rows.map(\.id), [5])
    XCTAssertEqual(structure.cells(for: structure.rows[0]).map(\.id), [6, 8])
    XCTAssertTrue(structure.columns.allSatisfy(\.notifyParent))
    XCTAssertTrue(structure.rows.allSatisfy(\.notifyParent))
    XCTAssertTrue(structure.cells(for: structure.rows[0]).allSatisfy(\.notifyParent))
    XCTAssertNil(structure.invalidRow)
  }

  func testStructureRejectsRowsWhoseVisibleCellCountDiffersFromColumns() {
    let backend = DataTableTestBackend()
    let table = backend.control(
      type: "DataTable",
      properties: [
        "columns": .array([
          dataTableWireControl(id: 2, type: "DataColumn"),
          dataTableWireControl(id: 3, type: "DataColumn"),
        ]),
        "rows": .array([
          dataTableWireControl(
            id: 4,
            type: "DataRow",
            properties: ["cells": .array([dataTableWireControl(id: 5, type: "DataCell")])])
        ]),
      ])

    XCTAssertEqual(RufletDataTableStructure(control: table).invalidRow?.id, 4)
  }

  func testSortPreservesPinnedColumnIndexAndAscendingPayload() {
    let backend = DataTableTestBackend()
    let table = backend.control(
      type: "DataTable",
      properties: ["sort_column_index": .int(1), "sort_ascending": .bool(true)])
    let column = backend.control(
      type: "DataColumn", properties: ["on_sort": .bool(true)])

    rufletSortDataTableColumn(column, index: 1, table: table)

    XCTAssertEqual(backend.events.count, 1)
    XCTAssertEqual(backend.events[0].controlID, column.id)
    XCTAssertEqual(backend.events[0].name, "sort")
    XCTAssertEqual(
      backend.events[0].data,
      .map(["ci": .int(1), "asc": .bool(false)]))
  }

  func testExplicitSelectAllEmitsOnlyTheTableEvent() {
    let backend = DataTableTestBackend()
    let table = backend.control(
      type: "DataTable",
      properties: [
        "on_select_all": .bool(true),
        "rows": .array([
          dataTableWireControl(
            id: 2, type: "DataRow",
            properties: ["on_select_change": .bool(true)])
        ]),
      ])

    rufletSelectAllDataTableRows(table, selected: true)

    XCTAssertEqual(backend.events.count, 1)
    XCTAssertEqual(backend.events[0].controlID, table.id)
    XCTAssertEqual(backend.events[0].name, "select_all")
    XCTAssertEqual(backend.events[0].data, .bool(true))
  }

  func testImplicitSelectAllDispatchesSelectableRowsInVisibleWireOrder() {
    let backend = DataTableTestBackend()
    let table = backend.control(
      type: "DataTable",
      properties: [
        "rows": .array([
          dataTableWireControl(
            id: 2, type: "DataRow", properties: ["on_select_change": .bool(true)]),
          dataTableWireControl(id: 3, type: "DataRow"),
          dataTableWireControl(
            id: 4, type: "DataRow",
            properties: ["on_select_change": .bool(true), "visible": .bool(false)]),
          dataTableWireControl(
            id: 5, type: "DataRow", properties: ["on_select_change": .bool(true)]),
        ])
      ])

    rufletSelectAllDataTableRows(table, selected: true)

    XCTAssertEqual(backend.events.map(\.controlID), [2, 5])
    XCTAssertEqual(backend.events.map(\.name), ["select_change", "select_change"])
    XCTAssertEqual(backend.events.map(\.data), [.bool(true), .bool(true)])
  }

  func testStructuralDisabledFlagDoesNotSuppressPinnedRowCallback() {
    let backend = DataTableTestBackend()
    let row = backend.control(
      type: "DataRow",
      properties: ["on_select_change": .bool(true), "disabled": .bool(true)])

    rufletSelectDataTableRow(row, selected: true)

    XCTAssertEqual(backend.events.count, 1)
    XCTAssertEqual(backend.events[0].name, "select_change")
    XCTAssertEqual(backend.events[0].data, .bool(true))
  }

  func testStylelessMetricsAndCellInsetsMatchPinnedDataTableDefaults() {
    let backend = DataTableTestBackend()
    let table = backend.control(type: "DataTable")
    let metrics = RufletDataTableMetrics(table: table)

    XCTAssertEqual(metrics.columnSpacing, 56)
    XCTAssertEqual(metrics.horizontalMargin, 24)
    XCTAssertEqual(metrics.headingRowHeight, 56)
    XCTAssertEqual(metrics.dataRowMinHeight, 48)
    XCTAssertEqual(metrics.dataRowMaxHeight, 48)
    XCTAssertEqual(metrics.dividerThickness, 1)
    XCTAssertEqual(metrics.checkboxMarginStart, 24)
    XCTAssertEqual(metrics.checkboxMarginEnd, 12)
    XCTAssertEqual(
      metrics.cellPadding(column: 0, columnCount: 3, checkboxVisible: false),
      EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 28))
    XCTAssertEqual(
      metrics.cellPadding(column: 0, columnCount: 3, checkboxVisible: true),
      EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 28))
    XCTAssertEqual(
      metrics.cellPadding(column: 1, columnCount: 3, checkboxVisible: false),
      EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
    XCTAssertEqual(
      metrics.cellPadding(column: 2, columnCount: 3, checkboxVisible: false),
      EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 24))
  }

  func testExplicitMetricsAndCheckboxMarginOverrideDefaults() {
    let backend = DataTableTestBackend()
    let table = backend.control(
      type: "DataTable",
      properties: [
        "column_spacing": .double(18),
        "horizontal_margin": .double(30),
        "heading_row_height": .double(61),
        "data_row_min_height": .double(37),
        "data_row_max_height": .double(73),
        "divider_thickness": .double(2.5),
        "checkbox_horizontal_margin": .double(9),
      ])
    let metrics = RufletDataTableMetrics(table: table)

    XCTAssertEqual(metrics.columnSpacing, 18)
    XCTAssertEqual(metrics.horizontalMargin, 30)
    XCTAssertEqual(metrics.headingRowHeight, 61)
    XCTAssertEqual(metrics.dataRowMinHeight, 37)
    XCTAssertEqual(metrics.dataRowMaxHeight, 73)
    XCTAssertEqual(metrics.dividerThickness, 2.5)
    XCTAssertEqual(metrics.checkboxMarginStart, 9)
    XCTAssertEqual(metrics.checkboxMarginEnd, 9)
  }

  func testAnyCellGestureOverridesRowInteraction() {
    let backend = DataTableTestBackend()
    for event in ["tap", "double_tap", "long_press", "tap_cancel", "tap_down"] {
      let cell = backend.control(
        type: "DataCell", properties: ["on_\(event)": .bool(true)])
      XCTAssertTrue(rufletDataCellOverridesRowInteraction(cell), event)
    }
    XCTAssertFalse(rufletDataCellOverridesRowInteraction(backend.control(type: "DataCell")))
  }

  func testColumnTooltipSupportsStringAndTooltipControlShapes() {
    let backend = DataTableTestBackend()
    let stringColumn = backend.control(
      type: "DataColumn", properties: ["tooltip": .string("Sort name")])
    let controlColumn = backend.control(
      type: "DataColumn",
      properties: [
        "tooltip": dataTableWireControl(
          id: 40, type: "Tooltip", properties: ["message": .string("Sort amount")])
      ])

    XCTAssertEqual(rufletDataColumnTooltip(stringColumn), "Sort name")
    XCTAssertEqual(rufletDataColumnTooltip(controlColumn), "Sort amount")
  }

  func testTapDownPayloadUsesPinnedCompactLocalAndGlobalMaps() {
    let payload = rufletDataTableTapDetails(
      local: CGPoint(x: 12, y: 24),
      global: CGPoint(x: 112, y: 224),
      kind: "touch")

    XCTAssertEqual(
      payload,
      .map([
        "k": .string("touch"),
        "l": .map(["x": .double(12), "y": .double(24)]),
        "g": .map(["x": .double(112), "y": .double(224)]),
      ]))
  }

  func testHorizontalLinesConsumesThePinnedWireSpellingOnly() {
    let backend = DataTableTestBackend()
    let correct = backend.control(
      type: "DataTable",
      properties: [
        "horizontal_lLines": .map(["width": .double(3), "color": .string("#ff0000")])
      ])
    let similarlyNamed = backend.control(
      type: "DataTable",
      properties: [
        "horizontal_lines": .map(["width": .double(9), "color": .string("#ff0000")])
      ])

    XCTAssertEqual(rufletDataTableHorizontalLines(correct)?.width, 3)
    XCTAssertNil(rufletDataTableHorizontalLines(similarlyNamed))
  }
}

private func dataTableWireControl(
  id: Int,
  type: String,
  properties: [String: RufletValue] = [:]
) -> RufletValue {
  .map(
    properties.merging([
      "_i": .int(Int64(id)),
      "_c": .string(type),
    ]) { current, _ in current })
}

private struct DataTableTestEvent {
  let controlID: Int
  let name: String
  let data: RufletValue
}

@MainActor
private final class DataTableTestBackend: RufletBackendProtocol {
  var pageURI: URL?
  lazy var extensionRegistry = RufletExtensionRegistry([])
  var events: [DataTableTestEvent] = []
  private var nextID = 1

  func control(
    type: String,
    properties: [String: RufletValue] = [:]
  ) -> RufletControl {
    defer { nextID += 1 }
    return RufletControl(id: nextID, type: type, properties: properties, backend: self)
  }

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(DataTableTestEvent(controlID: control.id, name: name, data: data))
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(DataTableTestEvent(controlID: controlID, name: name, data: data))
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
