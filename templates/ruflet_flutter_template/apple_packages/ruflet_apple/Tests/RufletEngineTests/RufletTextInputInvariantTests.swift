import XCTest
@testable import RufletEngine

final class RufletTextInputInvariantTests: XCTestCase {
  func testPinnedCapitalizationModes() {
    XCTAssertEqual(applyCapitalization("hello   world", .words), "Hello World")
    XCTAssertEqual(applyCapitalization("hello. world", .sentences), "Hello. World")
    XCTAssertEqual(applyCapitalization("Hello 42", .characters), "HELLO 42")
    XCTAssertEqual(applyCapitalization("unchanged", .none), "unchanged")
  }

  func testPinnedInputFilterAcceptsOnlyCompletePatternMatches() throws {
    let filter = RufletInputFilter(
      expression: try NSRegularExpression(pattern: "^[0-9]*$"),
      allow: false,
      replacementString: "x")

    // Pinned CustomFilteringTextInputFormatter overrides Flutter's allow and
    // replacement behavior: a matching complete edit wins, otherwise old text.
    XCTAssertEqual(filter.format(oldValue: "12", newValue: "123"), "123")
    XCTAssertEqual(filter.format(oldValue: "12", newValue: "12a"), "12")
  }

  func testSelectionWireMapPreservesPinnedOffsets() {
    let selection = RufletTextSelection(baseOffset: 7, extentOffset: 3)
    XCTAssertEqual(selection.range, NSRange(location: 3, length: 4))
    XCTAssertEqual(selection.value.map?["base_offset"]?.integer, 7)
    XCTAssertEqual(selection.value.map?["extent_offset"]?.integer, 3)
    XCTAssertEqual(selection.value.map?["affinity"]?.text, "downstream")
    XCTAssertEqual(selection.value.map?["directional"]?.bool, false)
  }
}
