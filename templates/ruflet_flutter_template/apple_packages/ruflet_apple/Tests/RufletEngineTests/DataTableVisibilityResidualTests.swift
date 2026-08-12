import RufletEngine
@testable import RufletUI
import XCTest

final class DataTableVisibilityResidualTests: XCTestCase {
  func testDataTableFiltersInvisibleColumnsAndPreservesVisibleIndices() {
    let nodes = structuralNodes()

    XCTAssertEqual(
      DataTablePresentation.visibleStructuralIDs([2, 3, 4, 99], in: nodes),
      [2, 4])
  }

  func testDataTableFiltersInvisibleRowsBeforeSelectionOwnership() {
    var nodes = structuralNodes()
    nodes[5] = ControlNode(id: 5, type: "DataRow", props: ["visible": .bool(false)])
    nodes[6] = ControlNode(id: 6, type: "DataRow")

    XCTAssertEqual(
      DataTablePresentation.visibleStructuralIDs([5, 6], in: nodes),
      [6])
  }

  func testDataTableFiltersCellsWithinEachVisibleRow() {
    var nodes = structuralNodes()
    nodes[7] = ControlNode(id: 7, type: "DataCell")
    nodes[8] = ControlNode(id: 8, type: "DataCell", props: ["visible": .bool(false)])
    nodes[9] = ControlNode(id: 9, type: "DataCell", props: ["visible": .bool(true)])

    XCTAssertEqual(
      DataTablePresentation.visibleStructuralIDs([7, 8, 9], in: nodes),
      [7, 9])
  }

  private func structuralNodes() -> [Int: ControlNode] {
    [
      2: ControlNode(id: 2, type: "DataColumn"),
      3: ControlNode(id: 3, type: "DataColumn", props: ["visible": .bool(false)]),
      4: ControlNode(id: 4, type: "DataColumn", props: ["visible": .bool(true)]),
    ]
  }
}
