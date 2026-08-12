import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI
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

  func testSearchAndDropdownOmittedDecorationUseNativeAppleChrome() {
    XCTAssertTrue(RufletSearchBarDefaults.usesNativeChrome(
      ControlNode(id: 1, type: "SearchBar")))
    XCTAssertFalse(RufletSearchBarDefaults.usesNativeChrome(ControlNode(
      id: 2, type: "SearchBar", props: ["bar_bgcolor": .string("#ffffff")])))

    XCTAssertTrue(DropdownMenuDefaults.usesNativeChrome(
      ControlNode(id: 3, type: "Dropdown")))
    XCTAssertFalse(DropdownMenuDefaults.usesNativeChrome(ControlNode(
      id: 4, type: "Dropdown", props: ["border": .string("outline")])))
  }

  func testDropdownDefaultsKeepSearchAndFilteringDistinct() {
    let omitted = ControlNode(id: 1, type: "Dropdown")
    XCTAssertFalse(DropdownMenuDefaults.filtersOptions(omitted))
    XCTAssertTrue(DropdownMenuDefaults.searchesOptions(omitted))

    let explicit = ControlNode(
      id: 2, type: "Dropdown",
      props: ["enable_filter": .bool(true), "enable_search": .bool(false)])
    XCTAssertTrue(DropdownMenuDefaults.filtersOptions(explicit))
    XCTAssertFalse(DropdownMenuDefaults.searchesOptions(explicit))
  }

  func testDropdownSelectionFollowsControllerThenSelectionOrdering() {
    let node = ControlNode(id: 8, type: "Dropdown", props: [
      "on_select": .bool(true), "on_text_change": .bool(true),
    ])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, data in calls.append("event:\(name):\(data.stringValue ?? "")") },
      setLocal: { _, key, value in calls.append("local:\(key):\(value.stringValue ?? "")") },
      update: { _, props in
        calls.append("update:\(props.keys.sorted().joined(separator: ","))")
      })

    RufletDropdownEvents.select(key: "nyc", text: "New York", on: node, to: sink)
    XCTAssertEqual(calls, [
      "local:text:New York", "update:text", "event:text_change:New York",
      "local:value:nyc", "update:value", "event:select:nyc",
    ])
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

  func testSearchBarChangeUpdatesBeforeOptionalEvent() {
    let node = ControlNode(id: 7, type: "SearchBar", props: ["on_change": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, _ in calls.append("event:\(name)") },
      setLocal: { _, key, _ in calls.append("local:\(key)") },
      update: { _, props in calls.append("update:\(props.keys.sorted().joined(separator: ","))") })

    RufletSearchBarEvents.change("native", on: node, to: sink)
    XCTAssertEqual(calls, ["local:value", "update:value", "event:change"])
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

  func testAutoCompleteChangeMatchesControllerWireOrdering() {
    let node = ControlNode(id: 6, type: "AutoComplete", props: ["on_change": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, _ in calls.append("event:\(name)") },
      setLocal: { _, key, _ in calls.append("local:\(key)") },
      update: { _, props in calls.append("update:\(props.keys.sorted().joined(separator: ","))") })

    RufletAutoCompleteEvents.change("swift", on: node, to: sink)
    XCTAssertEqual(calls, ["local:value", "update:value", "event:change"])
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

  func testPickerDefaultsKeepExactFletModesAndDateInsets() {
    let date = ControlNode(id: 1, type: "DatePicker")
    let range = ControlNode(id: 2, type: "DateRangePicker")
    let time = ControlNode(id: 3, type: "TimePicker")

    XCTAssertEqual(RufletPickerSemantics.initialEntryMode(date, kind: .date), "calendar")
    XCTAssertEqual(RufletPickerSemantics.initialEntryMode(range, kind: .dateRange), "calendar")
    XCTAssertEqual(RufletPickerSemantics.initialEntryMode(time, kind: .time), "dial")

    let inset = RufletPickerSemantics.contentInsets(date, kind: .date)
    XCTAssertEqual(inset.top, 24)
    XCTAssertEqual(inset.leading, 16)
    XCTAssertEqual(inset.bottom, 24)
    XCTAssertEqual(inset.trailing, 16)
    XCTAssertEqual(
      RufletPickerSemantics.contentInsets(range, kind: .dateRange), SwiftUI.EdgeInsets())
    XCTAssertEqual(RufletPickerSemantics.contentInsets(time, kind: .time), SwiftUI.EdgeInsets())
    XCTAssertEqual(RufletOverlaySemantics.defaultBarrierOpacity(date), 0.54)
  }

  func testPickerConfirmationUpdatesBeforeChangeAndDismiss() {
    let node = ControlNode(id: 10, type: "DatePicker", props: [
      "open": .bool(true), "on_change": .bool(true), "on_dismiss": .bool(true),
    ])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, data in
        calls.append(
          "event:\(name):\(data.mapValue?["value"]?.stringValue ?? data.boolValue.map { String($0) } ?? "")")
      },
      setLocal: { _, key, value in
        let rendered = value.stringValue ?? value.boolValue.map { String($0) } ?? value.description
        calls.append("local:\(key):\(rendered)")
      },
      update: { _, props in calls.append("update:\(props.keys.sorted().joined(separator: ","))") })

    RufletPickerEvents.confirm(value: "2026-05-21", on: node, to: sink)
    XCTAssertEqual(calls, [
      "local:_open:false", "local:value:2026-05-21", "local:open:false",
      "update:open,value", "event:change:2026-05-21", "event:dismiss:false",
    ])
  }

  func testPickerCancellationPreservesRangeAndClearsBothOpenBits() {
    let node = ControlNode(id: 11, type: "DateRangePicker", props: [
      "open": .bool(true), "start_value": .string("2026-05-01"),
      "end_value": .string("2026-05-21"), "on_dismiss": .bool(true),
    ])
    var updates: [[String: RufletValue]] = []
    var locals: [String: RufletValue] = [:]
    var dismissal: RufletValue?
    let sink = RufletEventSink(
      send: { _, name, data in if name == "dismiss" { dismissal = data } },
      setLocal: { _, key, value in locals[key] = value },
      update: { _, props in updates.append(props) })

    RufletPickerEvents.cancel(node, to: sink)
    XCTAssertEqual(locals["_open"], .bool(false))
    XCTAssertEqual(locals["open"], .bool(false))
    XCTAssertEqual(updates.last?["start_value"], .string("2026-05-01"))
    XCTAssertEqual(updates.last?["end_value"], .string("2026-05-21"))
    XCTAssertEqual(updates.last?["open"], .bool(false))
    XCTAssertEqual(dismissal, .bool(true))
  }

  func testTimePickerCancellationMatchesFletNullableResult() {
    let node = ControlNode(id: 13, type: "TimePicker", props: [
      "open": .bool(true), "value": .string("19:30"), "on_dismiss": .bool(true),
    ])
    var update: [String: RufletValue] = [:]
    let sink = RufletEventSink(
      send: { _, _, _ in }, setLocal: { _, _, _ in }, update: { _, props in update = props })

    RufletPickerEvents.cancel(node, to: sink)
    XCTAssertEqual(update["value"], .null)
    XCTAssertEqual(update["open"], .bool(false))
  }

  func testPickerEntryModeChangeUsesFletMapPayload() {
    let node = ControlNode(id: 12, type: "TimePicker", props: [
      "on_entry_mode_change": .bool(true),
    ])
    var event: RufletValue?
    let sink = RufletEventSink(
      send: { _, name, data in if name == "entry_mode_change" { event = data } },
      setLocal: { _, _, _ in }, update: { _, _ in })

    RufletPickerEvents.entryModeChanged("input", on: node, to: sink)
    XCTAssertEqual(event, .map(["entry_mode": .string("input")]))
  }
}
