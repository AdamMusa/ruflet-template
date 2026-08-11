import Foundation
import RufletEngine
import RufletProtocol
import XCTest
@testable import RufletUI

final class RufletInputParityTests: XCTestCase {
  func testSelectionPayloadMatchesFletTextSelectionMap() {
    let data = RufletTextSelection.eventData(NSRange(location: 1, length: 3), in: "Ruflet")
    guard case .map(let event) = data,
      case .string(let selected) = event["selected_text"],
      case .map(let selection) = event["selection"]
    else { return XCTFail("expected Flet selection event map") }
    XCTAssertEqual(selected, "ufl")
    XCTAssertEqual(selection["base_offset"]?.intValue, 1)
    XCTAssertEqual(selection["extent_offset"]?.intValue, 4)
    XCTAssertEqual(selection["affinity"]?.stringValue, "downstream")
    XCTAssertEqual(selection["directional"]?.boolValue, false)
  }

  func testSelectionClampsToUtf16TextLength() {
    XCTAssertEqual(
      RufletTextSelection.normalized(NSRange(location: 2, length: 50), in: "abc"),
      NSRange(location: 2, length: 1))
    XCTAssertNil(RufletTextSelection.normalized(NSRange(location: 4, length: 0), in: "abc"))
  }

  func testInputDescriptorsExposeFletEventsAndMethods() {
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "TextField")?.supportedEvents,
      ["blur", "change", "click", "focus", "selection_change", "submit", "tap_outside"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "SearchBar")?.supportedEvents,
      ["blur", "change", "focus", "submit", "tap", "tap_outside_bar"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Dropdown")?.supportedEvents,
      ["blur", "focus", "select", "text_change"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DropdownM2")?.supportedEvents,
      ["blur", "change", "click", "focus"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DatePicker")?.supportedEvents,
      ["change", "dismiss", "entry_mode_change"])
  }

  func testAutoCompleteSuggestionsAreParsedFromFletValueMaps() {
    let store = ControlStore()
    let value = RufletValue.array([
      .map(["key": .string("nyc"), "value": .string("New York")]),
      .map(["key": .string("Paris")]),
      .map(["value": .string("Tokyo")]),
      .map(["key": .string(""), "value": .string("")]),
    ])

    XCTAssertEqual(
      RufletAutoCompleteSuggestion.parse(value, store: store),
      [
        RufletAutoCompleteSuggestion(key: "nyc", value: "New York"),
        RufletAutoCompleteSuggestion(key: "Paris", value: "Paris"),
        RufletAutoCompleteSuggestion(key: "Tokyo", value: "Tokyo"),
      ])
  }

  func testAutoCompleteSelectionPayloadPreservesDistinctKeyAndValue() {
    let suggestion = RufletAutoCompleteSuggestion(key: "nyc", value: "New York")
    XCTAssertEqual(
      suggestion.wireValue,
      .map(["key": .string("nyc"), "value": .string("New York")]))
  }

  func testMaterialPickerBoundsAreThePinnedFletDatesNotARollingWindow() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    XCTAssertEqual(calendar.component(.year, from: RufletPickerSemantics.defaultFirstDate), 1900)
    XCTAssertEqual(calendar.component(.month, from: RufletPickerSemantics.defaultFirstDate), 1)
    XCTAssertEqual(calendar.component(.day, from: RufletPickerSemantics.defaultFirstDate), 1)
    XCTAssertEqual(calendar.component(.year, from: RufletPickerSemantics.defaultLastDate), 2050)
    XCTAssertEqual(calendar.component(.month, from: RufletPickerSemantics.defaultLastDate), 1)
    XCTAssertEqual(calendar.component(.day, from: RufletPickerSemantics.defaultLastDate), 1)
  }
}
