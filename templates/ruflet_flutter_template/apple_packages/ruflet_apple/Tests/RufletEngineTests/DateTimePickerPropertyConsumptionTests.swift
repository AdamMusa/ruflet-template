import Foundation
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class DateTimePickerPropertyConsumptionTests: XCTestCase {
  func testDatePickerConsumesPinnedPresentationAndInputProperties() throws {
    let fixture = makeControl(
      type: "DatePicker",
      properties: [
        "value": RufletMessagePack.temporalDate(date(2028, 6, 15)),
        "current_date": RufletMessagePack.temporalDate(date(2028, 6, 1)),
        "first_date": RufletMessagePack.temporalDate(date(2020, 1, 1)),
        "last_date": RufletMessagePack.temporalDate(date(2030, 12, 31)),
        "date_picker_mode": "year",
        "entry_mode": "input",
        "error_format_text": "Bad format",
        "error_invalid_text": "Out of range",
        "field_hint_text": "MM/DD/YYYY",
        "field_label_text": "Birthday",
        "keyboard_type": "datetime",
        "barrier_color": "#80112233",
        "inset_padding": ["left": 11.0, "top": 12.0, "right": 13.0, "bottom": 14.0],
        "locale": ["language_code": "en", "country_code": "US"],
        "modal": true,
        "switch_to_calendar_icon": 66_637,
        "switch_to_input_icon": 69_512,
      ])
    let presentation = RufletDatePickerPresentation(control: fixture.control)

    XCTAssertEqual(presentation.datePickerMode, .year)
    XCTAssertEqual(presentation.entryMode, .input)
    XCTAssertEqual(presentation.errorFormatText, "Bad format")
    XCTAssertEqual(presentation.errorInvalidText, "Out of range")
    XCTAssertEqual(presentation.fieldHintText, "MM/DD/YYYY")
    XCTAssertEqual(presentation.fieldLabelText, "Birthday")
    XCTAssertEqual(presentation.keyboardType, "datetime")
    XCTAssertEqual(presentation.insetPadding.leading, 11)
    XCTAssertEqual(presentation.insetPadding.top, 12)
    XCTAssertEqual(presentation.insetPadding.trailing, 13)
    XCTAssertEqual(presentation.insetPadding.bottom, 14)
    XCTAssertEqual(presentation.locale?.identifier, "en_US")
    XCTAssertTrue(presentation.modal)
    XCTAssertNotNil(presentation.barrierColor)
    XCTAssertNotNil(presentation.switchToCalendarIcon)
    XCTAssertNotNil(presentation.switchToInputIcon)
    XCTAssertEqual(Calendar.current.component(.year, from: try XCTUnwrap(presentation.value)), 2028)
  }

  func testDateRangePickerConsumesPinnedInputAndValidationProperties() {
    let fixture = makeControl(
      type: "DateRangePicker",
      properties: [
        "entry_mode": "input",
        "error_invalid_range_text": "Invalid range",
        "error_format_text": "Bad format",
        "error_invalid_text": "Out of bounds",
        "field_start_hint_text": "Start hint",
        "field_end_hint_text": "End hint",
        "field_start_label_text": "From",
        "field_end_label_text": "To",
        "keyboard_type": "datetime",
        "barrier_color": "#80445566",
        "save_text": "Save",
        "switch_to_calendar_icon": 66_637,
        "switch_to_input_icon": 69_512,
      ])
    let presentation = RufletDateRangePickerPresentation(control: fixture.control)

    XCTAssertEqual(presentation.entryMode, .input)
    XCTAssertEqual(presentation.errorInvalidRangeText, "Invalid range")
    XCTAssertEqual(presentation.errorFormatText, "Bad format")
    XCTAssertEqual(presentation.errorInvalidText, "Out of bounds")
    XCTAssertEqual(presentation.fieldStartHintText, "Start hint")
    XCTAssertEqual(presentation.fieldEndHintText, "End hint")
    XCTAssertEqual(presentation.fieldStartLabelText, "From")
    XCTAssertEqual(presentation.fieldEndLabelText, "To")
    XCTAssertEqual(presentation.keyboardType, "datetime")
    XCTAssertEqual(presentation.saveText, "Save")
    XCTAssertNotNil(presentation.barrierColor)
    XCTAssertNotNil(presentation.switchToCalendarIcon)
    XCTAssertNotNil(presentation.switchToInputIcon)
  }

  func testDateRangeUsesReadableNativePickerStylesPerApplePlatform() {
    guard case .compact = rufletDateRangePickerStyle(isIOS: true) else {
      return XCTFail("iPhone range endpoints must use compact UIDatePicker surfaces")
    }
    guard case .inline = rufletDateRangePickerStyle(isIOS: false) else {
      return XCTFail("desktop range endpoints retain inline calendars")
    }
  }

  func testStandardDialogsUseCupertinoPresentationOnIOS() {
    XCTAssertEqual(rufletAlertDialogStyle(isIOS: true), .cupertino)
    XCTAssertEqual(rufletAlertDialogStyle(isIOS: false), .standard)
  }

  func testTimePickerConsumesPinnedLabelsOrientationHourFormatAndIcons() {
    let fixture = makeControl(
      type: "TimePicker",
      properties: [
        "value": RufletMessagePack.temporalTime(hour: 21, minute: 7),
        "entry_mode": "input",
        "error_invalid_text": "Invalid time",
        "hour_label_text": "Hours",
        "minute_label_text": "Minutes",
        "hour_format": "h24",
        "orientation": "landscape",
        "barrier_color": "#80778899",
        "switch_to_timer_icon": 65_552,
        "switch_to_input_icon": 69_512,
      ])
    let presentation = RufletTimePickerPresentation(control: fixture.control)

    XCTAssertEqual(presentation.value, RufletTimeOfDay(hour: 21, minute: 7))
    XCTAssertEqual(presentation.entryMode, .input)
    XCTAssertEqual(presentation.errorInvalidText, "Invalid time")
    XCTAssertEqual(presentation.hourLabelText, "Hours")
    XCTAssertEqual(presentation.minuteLabelText, "Minutes")
    XCTAssertEqual(presentation.hourFormat, "h24")
    XCTAssertEqual(presentation.effectiveLocale?.identifier, "en_GB")
    XCTAssertEqual(presentation.orientation, .landscape)
    XCTAssertNotNil(presentation.barrierColor)
    XCTAssertNotNil(presentation.switchToTimerIcon)
    XCTAssertNotNil(presentation.switchToInputIcon)
  }

  func testPickerCloseTransactionsPreservePinnedPayloads() {
    let dateFixture = makeControl(type: "DatePicker", properties: ["value": .null])
    let selectedDate = date(2029, 4, 20)
    DatePickerControl(control: dateFixture.control).close(selectedDate)
    XCTAssertEqual(dateFixture.backend.updates.count, 2)
    XCTAssertEqual(dateFixture.backend.events.map(\.name), ["change", "dismiss"])
    XCTAssertEqual(dateFixture.backend.events.last?.data, false)

    let rangeFixture = makeControl(type: "DateRangePicker", properties: [:])
    DateRangePickerControl(control: rangeFixture.control).close(
      (date(2029, 4, 20), date(2029, 4, 22)))
    XCTAssertEqual(rangeFixture.backend.updates.count, 2)
    XCTAssertEqual(rangeFixture.backend.events.map(\.name), ["change", "dismiss"])
    XCTAssertNotNil(rangeFixture.backend.events.first?.data.map?["start"])
    XCTAssertNotNil(rangeFixture.backend.events.first?.data.map?["end"])

    let timeFixture = makeControl(type: "TimePicker", properties: [:])
    TimePickerControl(control: timeFixture.control).close(RufletTimeOfDay(hour: 9, minute: 5))
    XCTAssertEqual(timeFixture.backend.updates.count, 2)
    XCTAssertEqual(timeFixture.backend.events.map(\.name), ["change", "dismiss"])
    XCTAssertEqual(
      timeFixture.backend.events.first?.data,
      RufletMessagePack.temporalTime(hour: 9, minute: 5))
  }

  func testPickerDateTextRoundTripsInConfiguredLocale() throws {
    let source = date(2031, 11, 9)
    let locale = Locale(identifier: "en_US")
    let text = rufletPickerDateText(source, locale: locale)
    let parsed = try XCTUnwrap(rufletParsePickerDate(text, locale: locale))
    let expected = Calendar.current.dateComponents([.year, .month, .day], from: source)
    let actual = Calendar.current.dateComponents([.year, .month, .day], from: parsed)
    XCTAssertEqual(actual, expected)
  }

  private func makeControl(
    type: String,
    properties: [String: RufletValue]
  ) -> (control: RufletControl, backend: PickerBackend) {
    let backend = PickerBackend()
    let control = RufletControl(id: 44, type: type, properties: properties, backend: backend)
    return (control, backend)
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar(identifier: .gregorian).date(
      from: DateComponents(
        timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day))!
  }
}

@MainActor
private final class PickerBackend: RufletBackendProtocol {
  struct Update {
    let properties: [String: RufletValue]
    let server: Bool
  }

  struct Event {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  lazy var extensionRegistry = RufletExtensionRegistry([RufletCoreExtension()])
  var updates: [Update] = []
  var events: [Event] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    updates.append(Update(properties: properties, server: server))
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
