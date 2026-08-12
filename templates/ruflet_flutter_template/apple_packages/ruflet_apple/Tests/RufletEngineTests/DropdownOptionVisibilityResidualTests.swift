import RufletEngine
@testable import RufletUI
import XCTest

final class DropdownOptionVisibilityResidualTests: XCTestCase {
  func testDropdownFiltersInvisibleStructuralOptions() {
    let first = ControlNode(id: 2, type: "DropdownOption", props: [
      "key": .string("first"), "text": .string("First"),
    ])
    let hidden = ControlNode(id: 3, type: "DropdownOption", props: [
      "key": .string("hidden"), "text": .string("Hidden"),
      "visible": .bool(false),
    ])
    let last = ControlNode(id: 4, type: "DropdownOption", props: [
      "key": .string("last"), "visible": .bool(true),
    ])

    XCTAssertEqual(DropdownMenuDefaults.visibleOptions([first, hidden, last]).map(\.id), [2, 4])
  }

  func testDropdownDropsEntriesWithoutKeyOrTextAfterVisibilityFiltering() {
    let empty = ControlNode(id: 2, type: "DropdownOption")
    let textOnly = ControlNode(id: 3, type: "DropdownOption", props: [
      "text": .string("Text value"),
    ])
    let keyOnly = ControlNode(id: 4, type: "DropdownOption", props: [
      "key": .string("key-value"),
    ])

    XCTAssertEqual(DropdownMenuDefaults.visibleOptions([empty, textOnly, keyOnly]).map(\.id), [3, 4])
  }

  func testHiddenCurrentValueCannotRemainAValidSelection() {
    let hidden = ControlNode(id: 2, type: "DropdownOption", props: [
      "key": .string("selected"), "text": .string("Selected"),
      "visible": .bool(false),
    ])
    let visible = DropdownMenuDefaults.visibleOptions([hidden])

    XCTAssertFalse(visible.contains {
      ($0.string("key") ?? $0.string("text")) == "selected"
    })
  }
}
