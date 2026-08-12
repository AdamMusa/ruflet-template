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
    XCTAssertEqual(ControlRegistry.descriptor(for: "TextField")?.supportedMethods, ["focus"])
  }

  func testTextFieldDefaultsMatchPinnedFletBehaviorWithoutMaterialChrome() {
    let omitted = ControlNode(id: 1, type: "TextField")
    XCTAssertFalse(RufletTextFieldDefaults.isMultiline(omitted))
    XCTAssertEqual(RufletTextFieldDefaults.minLines(omitted), 1)
    XCTAssertEqual(RufletTextFieldDefaults.maxLines(omitted), 1)
    XCTAssertEqual(RufletTextFieldDefaults.defaultWidth(omitted), 300)

    let shifted = ControlNode(
      id: 2, type: "TextField",
      props: ["shift_enter": .bool(true)])
    XCTAssertTrue(RufletTextFieldDefaults.isMultiline(shifted))
    XCTAssertEqual(RufletTextFieldDefaults.minLines(shifted), 1)
    XCTAssertNil(RufletTextFieldDefaults.maxLines(shifted))

    XCTAssertNil(RufletTextFieldDefaults.defaultWidth(ControlNode(
      id: 3, type: "TextField", props: ["expand": .int(1)])))
    XCTAssertNil(RufletTextFieldDefaults.defaultWidth(ControlNode(
      id: 4, type: "TextField", props: ["width": .double(240)])))
  }

  func testTextFieldCounterInterpolatesFletTokens() {
    XCTAssertEqual(
      RufletTextFieldDefaults.counterText(
        "{value_length}/{max_length} ({symbols_left})", value: "ruby", maxLength: 10),
      "4/10 (6)")
    XCTAssertNil(RufletTextFieldDefaults.counterText(nil, value: "ruby", maxLength: 10))
    XCTAssertEqual(
      RufletTextFieldDefaults.counterText(
        "{value_length}:{max_length}:{symbols_left}", value: "ruby", maxLength: nil),
      "4:None:None")
  }

  func testTextFieldChangeUpdatesWireBeforeOptionalEvent() {
    let node = ControlNode(
      id: 9, type: "TextField",
      props: ["on_change": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, data in
        calls.append("event:\(name):\(data.stringValue ?? "")")
      },
      setLocal: { _, key, value in
        calls.append("local:\(key):\(value.stringValue ?? "")")
      },
      update: { _, props in
        calls.append("update:value:\(props["value"]?.stringValue ?? "")")
      })

    RufletTextFieldEvents.change("native", on: node, to: sink)
    XCTAssertEqual(calls, [
      "local:value:native", "update:value:native", "event:change:native",
    ])
  }

  func testDropdownKeepsFletFieldAndPopupGeometryIndependent() {
    let omitted = ControlNode(id: 1, type: "Dropdown")
    XCTAssertNil(DropdownMenuDefaults.fieldWidth(omitted))
    XCTAssertNil(DropdownMenuDefaults.menuWidth(omitted))
    XCTAssertNil(DropdownMenuDefaults.menuHeight(omitted))

    let explicit = ControlNode(
      id: 2, type: "Dropdown",
      props: [
        "width": .double(240),
        "menu_width": .double(360),
        "menu_height": .double(280),
      ])
    XCTAssertEqual(DropdownMenuDefaults.fieldWidth(explicit), 240)
    XCTAssertEqual(DropdownMenuDefaults.menuWidth(explicit), 360)
    XCTAssertEqual(DropdownMenuDefaults.menuHeight(explicit), 280)
  }

  func testSearchBarUsesFlutterScrollPaddingWithoutChangingBarLayout() {
    let omitted = RufletSearchBarDefaults.scrollPadding(
      ControlNode(id: 1, type: "SearchBar"))
    XCTAssertEqual(omitted.top, 20)
    XCTAssertEqual(omitted.leading, 20)
    XCTAssertEqual(omitted.bottom, 20)
    XCTAssertEqual(omitted.trailing, 20)

    let explicit = RufletSearchBarDefaults.scrollPadding(ControlNode(
      id: 2,
      type: "SearchBar",
      props: [
        "bar_scroll_padding": .map([
          "top": .double(1), "left": .double(2),
          "bottom": .double(3), "right": .double(4),
        ])
      ]))
    XCTAssertEqual(explicit.top, 1)
    XCTAssertEqual(explicit.leading, 2)
    XCTAssertEqual(explicit.bottom, 3)
    XCTAssertEqual(explicit.trailing, 4)
  }

  func testSearchBarCapitalizationMatchesPinnedFletController() {
    XCTAssertEqual(
      RufletSearchBarDefaults.capitalized("ruflet native", mode: "characters"),
      "RUFLET NATIVE")
    XCTAssertEqual(
      RufletSearchBarDefaults.capitalized("rUFLET   nATIVE", mode: "words"),
      "Ruflet Native")
    XCTAssertEqual(
      RufletSearchBarDefaults.capitalized("hELLO. nATIVE WORLD", mode: "sentences"),
      "Hello. Native world")
    XCTAssertEqual(
      RufletSearchBarDefaults.capitalized("Keep My Case", mode: "none"),
      "Keep My Case")
  }

  func testSearchBarCarriesCaretPaddingThroughNativeTextTraits() {
    var traits = RufletTextInputTraits()
    traits.caretScrollPadding = RufletSearchBarDefaults.scrollPadding(
      ControlNode(id: 1, type: "SearchBar"))
    XCTAssertEqual(traits.caretScrollPadding.top, 20)
    XCTAssertEqual(traits.caretScrollPadding.trailing, 20)
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

  func testMaterialPickersUseFletsOpenFalsePresentationGate() {
    XCTAssertFalse(RufletPickerSemantics.isPresented(ControlNode(id: 1, type: "DatePicker")))
    XCTAssertFalse(RufletPickerSemantics.isPresented(ControlNode(
      id: 2,
      type: "TimePicker",
      props: ["open": .bool(false)])))
    XCTAssertTrue(RufletPickerSemantics.isPresented(ControlNode(
      id: 3,
      type: "DateRangePicker",
      props: ["open": .bool(true)])))
  }

  func testEveryMaterialPickerAdvertisesItsPinnedFletEvents() {
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DatePicker")?.supportedEvents,
      ["change", "dismiss", "entry_mode_change"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DateRangePicker")?.supportedEvents,
      ["change", "dismiss"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "TimePicker")?.supportedEvents,
      ["change", "dismiss", "entry_mode_change"])
  }
}
