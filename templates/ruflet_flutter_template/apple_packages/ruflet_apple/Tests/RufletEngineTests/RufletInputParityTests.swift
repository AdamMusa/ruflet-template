import Foundation
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
}
