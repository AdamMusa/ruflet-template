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

  func testTextFieldDefaultsMatchPinnedFletDecorationAndTypography() {
    let omitted = ControlNode(id: 1, type: "TextField")
    XCTAssertFalse(RufletTextFieldDefaults.isMultiline(omitted))
    XCTAssertEqual(RufletTextFieldDefaults.minLines(omitted), 1)
    XCTAssertEqual(RufletTextFieldDefaults.maxLines(omitted), 1)
    XCTAssertEqual(RufletTextFieldDefaults.defaultWidth(omitted), 300)
    XCTAssertEqual(RufletTextFieldDefaults.borderKind(omitted), .outline)
    XCTAssertEqual(RufletTextFieldDefaults.fieldCornerRadius(omitted), 4)
    XCTAssertEqual(RufletTextFieldDefaults.borderWidth(omitted, focused: false), 1)
    XCTAssertEqual(RufletTextFieldDefaults.borderWidth(omitted, focused: true), 2)
    XCTAssertEqual(RufletTextFieldDefaults.borderColorToken(omitted, focused: false), "black")
    XCTAssertEqual(RufletTextFieldDefaults.borderColorToken(omitted, focused: true), "primary")
    XCTAssertEqual(RufletTextFieldDefaults.defaultTextSize, 16)
    XCTAssertEqual(RufletTextFieldDefaults.defaultTextLineHeight, 24)
    XCTAssertTrue(RufletTextFieldDefaults.usesNativeApplePresentation(omitted))
    XCTAssertEqual(RufletTextFieldDefaults.nativeSingleLineHeight, 36)
    let padding = RufletTextFieldDefaults.contentPadding(omitted)
    XCTAssertEqual(padding.top, 20)
    XCTAssertEqual(padding.leading, 12)
    XCTAssertEqual(padding.bottom, 12)
    XCTAssertEqual(padding.trailing, 12)

    let overridden = ControlNode(id: 5, type: "TextField", props: [
      "border_width": .double(1),
    ])
    XCTAssertFalse(RufletTextFieldDefaults.usesNativeApplePresentation(overridden))
    XCTAssertEqual(RufletTextFieldDefaults.borderColorToken(overridden, focused: false), "onsurface,0.38")
    XCTAssertEqual(RufletTextFieldDefaults.borderColorToken(overridden, focused: true), "primary")
    XCTAssertEqual(RufletTextFieldDefaults.borderWidth(overridden, focused: true), 1)

    let disabled = ControlNode(id: 6, type: "TextField", props: [
      "disabled": .bool(true),
      "border_width": .double(4),
      "border_color": .string("red"),
    ])
    XCTAssertEqual(RufletTextFieldDefaults.borderWidth(disabled, focused: false), 1)
    XCTAssertEqual(
      RufletTextFieldDefaults.borderColorToken(disabled, focused: false), "onsurface,0.12")

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

  func testNativeTextFieldSearchPrefixUsesAppleSearchChrome() throws {
    let searchIndex = try XCTUnwrap(MaterialIconNames.material.firstIndex(of: "SEARCH"))
    let search = ControlNode(id: 1, type: "TextField", props: [
      "prefix_icon": .int(Int64(MaterialIconNames.firstCodepoint + searchIndex))
    ])
    XCTAssertTrue(RufletTextFieldDefaults.usesNativeApplePresentation(search))
    XCTAssertTrue(RufletTextFieldDefaults.hasSearchPrefix(search))

    let custom = ControlNode(id: 2, type: "TextField", props: [
      "prefix_icon": .string("home"), "border_radius": .double(12)
    ])
    XCTAssertFalse(RufletTextFieldDefaults.hasSearchPrefix(custom))
    XCTAssertFalse(RufletTextFieldDefaults.usesNativeApplePresentation(custom))
  }

  func testOmittedAccessibilityLabelPreservesNativeInference() {
    XCTAssertNil(RufletAccessibilitySemantics.label(ControlNode(id: 1, type: "Checkbox")))
    XCTAssertEqual(RufletAccessibilitySemantics.label(ControlNode(
      id: 2, type: "Checkbox", props: ["semantics_label": .string("")])), "")
    XCTAssertEqual(RufletAccessibilitySemantics.label(ControlNode(
      id: 3, type: "CupertinoCheckbox",
      props: ["semantics_label": .string("Receive updates")])), "Receive updates")
  }

  func testTextFieldCounterInterpolatesFletTokens() {
    XCTAssertEqual(
      RufletTextFieldDefaults.counterText(
        "{value_length}/{max_length} ({symbols_left})", value: "ruby", maxLength: 10),
      "4/10 (6)")
    XCTAssertEqual(RufletTextFieldDefaults.counterText(nil, value: "ruby", maxLength: 10), "4/10")
    XCTAssertEqual(RufletTextFieldDefaults.counterText(nil, value: "😀", maxLength: 10), "1/10")
    XCTAssertEqual(RufletTextFieldDefaults.counterText(nil, value: "ruby", maxLength: -1), "4")
    XCTAssertEqual(
      RufletTextFieldDefaults.counterText(
        "{value_length}:{max_length}:{symbols_left}", value: "ruby", maxLength: nil),
      "4:None:None")
    XCTAssertEqual(
      RufletTextFieldDefaults.counterText(
        "{value_length}", value: "😀", maxLength: nil),
      "2")
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

  func testSearchKeepsPinnedMaterialConstructorAndThemeDefaults() {
    let search = ControlNode(id: 1, type: "SearchBar")
    XCTAssertEqual(RufletSearchBarDefaults.defaultElevation, 6)
    XCTAssertEqual(RufletSearchBarDefaults.defaultTextSize, 16)
    XCTAssertEqual(RufletSearchBarDefaults.defaultLineHeight, 24)
    XCTAssertEqual(RufletSearchBarDefaults.barMinimumWidth(search), 360)
    XCTAssertEqual(RufletSearchBarDefaults.barMaximumWidth(search), 800)
    XCTAssertEqual(RufletSearchBarDefaults.barMinimumHeight(search), 56)
    XCTAssertEqual(RufletSearchBarDefaults.viewMinimumWidth(search), 360)
    XCTAssertEqual(RufletSearchBarDefaults.viewMinimumHeight(search), 240)
    XCTAssertEqual(RufletSearchBarDefaults.viewHeaderHeight(fullScreen: false), 56)
    XCTAssertEqual(RufletSearchBarDefaults.viewHeaderHeight(fullScreen: true), 72)
    XCTAssertEqual(RufletSearchBarDefaults.cornerRadius(prefix: "bar", fullScreen: false), 28)
    XCTAssertEqual(RufletSearchBarDefaults.cornerRadius(prefix: "view", fullScreen: true), 0)
    let padding = RufletSearchBarDefaults.barPadding(search)
    XCTAssertEqual(padding.top, 0)
    XCTAssertEqual(padding.leading, 8)
    XCTAssertEqual(padding.bottom, 0)
    XCTAssertEqual(padding.trailing, 8)
  }

  func testDropdownPreservesFletDecorationDefaults() {

    let dropdown = ControlNode(id: 3, type: "Dropdown")
    XCTAssertEqual(DropdownMenuDefaults.borderKind(dropdown), .outline)
    XCTAssertEqual(DropdownMenuDefaults.fieldCornerRadius(dropdown), 4)
    XCTAssertEqual(DropdownMenuDefaults.borderWidth(dropdown, focused: false), 1)
    XCTAssertEqual(DropdownMenuDefaults.borderWidth(dropdown, focused: true), 2)
    XCTAssertEqual(DropdownMenuDefaults.defaultTextSize, 16)
    XCTAssertEqual(DropdownMenuDefaults.defaultMenuElevation, 3)
    XCTAssertEqual(DropdownMenuDefaults.defaultMenuCornerRadius, 4)
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

  func testDropdownMenuKeepsPinnedFlutterGeometryAndTypographyDefaults() {
    let node = ControlNode(id: 1, type: "Dropdown")
    XCTAssertEqual(DropdownMenuDefaults.minimumMenuWidth, 112)
    XCTAssertEqual(DropdownMenuDefaults.optionHorizontalPadding, 12)
    XCTAssertEqual(DropdownMenuDefaults.optionMinimumHeight, 48)
    XCTAssertEqual(DropdownMenuDefaults.defaultTextSize, 16)
    XCTAssertEqual(DropdownMenuDefaults.menuVerticalPadding(node), 8)
    let padding = DropdownMenuDefaults.contentPadding(node)
    XCTAssertEqual(padding.top, 20)
    XCTAssertEqual(padding.leading, 12)
    XCTAssertEqual(padding.bottom, 12)
    XCTAssertEqual(padding.trailing, 12)

    let styled = ControlNode(id: 2, type: "Dropdown", props: [
      "menu_style": .map([
        "min_size": .map(["width": .double(140), "height": .double(20)]),
        "max_size": .map(["width": .double(360), "height": .double(280)]),
        "fixed_size": .map(["width": .double(240), "height": .double(180)]),
      ])
    ])
    XCTAssertEqual(DropdownMenuDefaults.effectiveMenuWidth(styled), 240)
    XCTAssertEqual(DropdownMenuDefaults.effectiveMenuHeight(styled), 180)
    XCTAssertEqual(DropdownMenuDefaults.minimumStyledWidth(styled), 140)
    XCTAssertEqual(DropdownMenuDefaults.maximumStyledWidth(styled), 360)
  }

  func testDropdownM2KeepsLegacyConstructorDefaults() {
    let node = ControlNode(id: 1, type: "DropdownM2")
    XCTAssertEqual(DropdownM2Defaults.defaultWidth, 300)
    XCTAssertEqual(DropdownM2Defaults.optionHorizontalPadding, 16)
    XCTAssertEqual(DropdownM2Defaults.itemHeight(node), 48)
    XCTAssertEqual(DropdownM2Defaults.selectIconSize(node), 24)
    XCTAssertEqual(DropdownM2Defaults.elevation(node), 8)
    XCTAssertTrue(DropdownM2Defaults.optionsFillHorizontally(node))
    XCTAssertEqual(DropdownM2Defaults.fieldCornerRadius(node), 4)
    let padding = DropdownM2Defaults.decorationContentPadding(node)
    XCTAssertEqual(padding.top, 20)
    XCTAssertEqual(padding.leading, 12)
    XCTAssertEqual(padding.bottom, 12)
    XCTAssertEqual(padding.trailing, 12)
  }

  func testDropdownM2OptionClickPrecedesParentValueChange() {
    let option = ControlNode(id: 3, type: "DropdownOption", props: ["on_click": .bool(true)])
    let node = ControlNode(id: 2, type: "DropdownM2", props: ["on_change": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { control, name, data in
        calls.append("event:\(control):\(name):\(data.stringValue ?? "")")
      },
      setLocal: { _, key, value in calls.append("local:\(key):\(value.stringValue ?? "")") },
      update: { _, props in calls.append("update:\(props.keys.sorted().joined(separator: ","))") })

    RufletDropdownM2Events.select(value: "ruby", option: option, on: node, to: sink)
    XCTAssertEqual(calls, [
      "event:3:click:", "local:value:ruby", "update:value", "event:2:change:ruby",
    ])
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

  func testAutoCompleteKeepsFlutterFieldAndPopupDefaults() {
    let node = ControlNode(id: 1, type: "AutoComplete")
    XCTAssertEqual(RufletAutoCompleteDefaults.suggestionsMaxHeight(node), 200)
    XCTAssertEqual(RufletAutoCompleteDefaults.popupElevation, 4)
    XCTAssertEqual(RufletAutoCompleteDefaults.fieldTextSize, 16)
    XCTAssertEqual(RufletAutoCompleteDefaults.optionTextSize, 14)
    XCTAssertEqual(RufletAutoCompleteDefaults.optionPadding.top, 16)
    XCTAssertEqual(RufletAutoCompleteDefaults.optionPadding.leading, 16)
    XCTAssertEqual(RufletAutoCompleteDefaults.fieldContentPadding.top, 8)
    XCTAssertEqual(RufletAutoCompleteDefaults.fieldContentPadding.leading, 0)
    XCTAssertEqual(RufletAutoCompleteDefaults.fieldBorderWidth(focused: false), 1)
    XCTAssertEqual(RufletAutoCompleteDefaults.fieldBorderWidth(focused: true), 2)
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

  func testPickerTypedEntryStringsAndSwitchIconsStayOnTheirFletConstructors() {
    let date = ControlNode(id: 1, type: "DatePicker", props: [
      "help_text": .string("Select a date"),
      "cancel_text": .string("Never mind"),
      "confirm_text": .string("Apply"),
      "error_format_text": .string("Bad format"),
      "error_invalid_text": .string("Bad date"),
      "field_hint_text": .string("MM/DD/YYYY"),
      "field_label_text": .string("Birthday"),
      "switch_to_calendar_icon": .int(100),
      "switch_to_input_icon": .int(101),
    ])
    let dateText = RufletPickerSemantics.text(date, kind: .date)
    XCTAssertEqual(dateText.helpText, "Select a date")
    XCTAssertEqual(dateText.cancelText, "Never mind")
    XCTAssertEqual(dateText.confirmText, "Apply")
    XCTAssertEqual(dateText.errorFormatText, "Bad format")
    XCTAssertEqual(dateText.errorInvalidText, "Bad date")
    XCTAssertEqual(dateText.fieldHintText, "MM/DD/YYYY")
    XCTAssertEqual(dateText.fieldLabelText, "Birthday")
    XCTAssertEqual(RufletPickerSemantics.validationMessage(.format, text: dateText), "Bad format")
    XCTAssertEqual(
      RufletPickerSemantics.switchIcon(date, kind: .date, entryMode: "input"), .int(100))
    XCTAssertEqual(
      RufletPickerSemantics.switchIcon(date, kind: .date, entryMode: "calendar"), .int(101))

    let range = ControlNode(id: 2, type: "DateRangePicker", props: [
      "confirm_text": .string("Apply range"),
      "save_text": .string("Save range"),
      "error_format_text": .string("Bad format"),
      "error_invalid_text": .string("Bad date"),
      "error_invalid_range_text": .string("Bad range"),
      "field_start_hint_text": .string("Start"),
      "field_end_hint_text": .string("End"),
      "field_start_label_text": .string("From"),
      "field_end_label_text": .string("To"),
      "switch_to_calendar_icon": .int(200),
      "switch_to_input_icon": .int(201),
    ])
    let rangeText = RufletPickerSemantics.text(range, kind: .dateRange)
    XCTAssertEqual(rangeText.confirmText, "Apply range")
    XCTAssertEqual(rangeText.saveText, "Save range")
    XCTAssertEqual(rangeText.errorFormatText, "Bad format")
    XCTAssertEqual(rangeText.errorInvalidText, "Bad date")
    XCTAssertEqual(rangeText.fieldStartHintText, "Start")
    XCTAssertEqual(rangeText.fieldEndHintText, "End")
    XCTAssertEqual(rangeText.fieldStartLabelText, "From")
    XCTAssertEqual(rangeText.fieldEndLabelText, "To")
    XCTAssertEqual(
      RufletPickerSemantics.validationMessage(.invalidRange, text: rangeText), "Bad range")
    XCTAssertEqual(
      RufletPickerSemantics.switchIcon(range, kind: .dateRange, entryMode: "input"), .int(200))
    XCTAssertEqual(
      RufletPickerSemantics.switchIcon(range, kind: .dateRange, entryMode: "calendar"), .int(201))

    let time = ControlNode(id: 3, type: "TimePicker", props: [
      "error_invalid_text": .string("Bad time"),
      "hour_label_text": .string("Hour"),
      "minute_label_text": .string("Minute"),
      "switch_to_timer_icon": .int(300),
      "switch_to_input_icon": .int(301),
    ])
    let timeText = RufletPickerSemantics.text(time, kind: .time)
    XCTAssertEqual(timeText.errorInvalidText, "Bad time")
    XCTAssertEqual(timeText.hourLabelText, "Hour")
    XCTAssertEqual(timeText.minuteLabelText, "Minute")
    XCTAssertNil(RufletPickerSemantics.validationMessage(.format, text: timeText))
    XCTAssertEqual(
      RufletPickerSemantics.switchIcon(time, kind: .time, entryMode: "input"), .int(300))
    XCTAssertEqual(
      RufletPickerSemantics.switchIcon(time, kind: .time, entryMode: "dial"), .int(301))
  }

  func testDateRangeUsesConfirmForInputAndSaveForCalendarMode() {
    let defaults = RufletPickerTextSemantics()
    XCTAssertEqual(
      RufletPickerSemantics.confirmationText(defaults, kind: .dateRange, entryMode: "input"),
      "OK")
    XCTAssertEqual(
      RufletPickerSemantics.confirmationText(defaults, kind: .dateRange, entryMode: "calendar"),
      "Save")

    let custom = RufletPickerTextSemantics(confirmText: "Apply", saveText: "Store")
    XCTAssertEqual(
      RufletPickerSemantics.confirmationText(custom, kind: .dateRange, entryMode: "input"),
      "Apply")
    XCTAssertEqual(
      RufletPickerSemantics.confirmationText(custom, kind: .dateRange, entryMode: "calendar"),
      "Store")
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
