import RufletEngine
@testable import RufletUI
import XCTest

final class DropdownM2OptionVisibilityResidualTests: XCTestCase {
  func testLegacyDropdownFiltersInvisibleStructuralOptions() {
    let visible = ControlNode(id: 2, type: "DropdownOption", props: [
      "key": .string("visible"), "text": .string("Visible"),
    ])
    let hidden = ControlNode(id: 3, type: "DropdownOption", props: [
      "key": .string("hidden"), "text": .string("Hidden"),
      "visible": .bool(false),
    ])
    let explicitlyVisible = ControlNode(id: 4, type: "DropdownOption", props: [
      "text": .string("Explicit"), "visible": .bool(true),
    ])

    XCTAssertEqual(
      DropdownM2Defaults.visibleOptions([visible, hidden, explicitlyVisible]).map(\.id),
      [2, 4])
  }

  func testLegacyDropdownDropsOptionsWithoutKeyOrText() {
    let empty = ControlNode(id: 2, type: "DropdownOption")
    let keyOnly = ControlNode(id: 3, type: "DropdownOption", props: [
      "key": .string("key-value"),
    ])
    let textOnly = ControlNode(id: 4, type: "DropdownOption", props: [
      "text": .string("Text value"),
    ])

    XCTAssertEqual(
      DropdownM2Defaults.visibleOptions([empty, keyOnly, textOnly]).map(\.id),
      [3, 4])
  }

  func testHiddenCurrentValueCannotRemainAValidSelection() {
    let hidden = ControlNode(id: 2, type: "DropdownOption", props: [
      "key": .string("selected"), "visible": .bool(false),
    ])
    let options = DropdownM2Defaults.visibleOptions([hidden])

    XCTAssertFalse(options.contains {
      ($0.string("key") ?? $0.string("text")) == "selected"
    })
  }
}
