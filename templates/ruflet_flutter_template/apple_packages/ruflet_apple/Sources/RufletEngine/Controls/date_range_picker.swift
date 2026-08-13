import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `date_range_picker.dart`.
@MainActor
public struct DateRangePickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var presented = false
  @State private var draftStart = Date()
  @State private var draftEnd = Date()
  @State private var startInputText = ""
  @State private var endInputText = ""
  @State private var entryMode = RufletDateEntryMode.calendar
  @State private var closedByAction = false

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .onAppear(perform: synchronizePresentation)
      .onChange(of: control.properties) { _ in synchronizePresentation() }
      .sheet(isPresented: $presented, onDismiss: sheetDismissed) {
        pickerSheet
          .interactiveDismissDisabled(presentation.modal)
      }
  }

  private var pickerSheet: some View {
    let presentation = presentation
    return NavigationView {
      VStack(spacing: 12) {
        if let helpText = presentation.helpText {
          Text(helpText).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
        }
        HStack(alignment: .top, spacing: 12) {
          pickerColumn(
            isStart: true,
            title: presentation.fieldStartLabelText ?? "Start date",
            hint: presentation.fieldStartHintText,
            date: draftStart,
            minimum: presentation.minimumDate,
            maximum: min(draftEnd, presentation.maximumDate),
            changed: startChanged)
          pickerColumn(
            isStart: false,
            title: presentation.fieldEndLabelText ?? "End date",
            hint: presentation.fieldEndHintText,
            date: draftEnd,
            minimum: max(draftStart, presentation.minimumDate),
            maximum: presentation.maximumDate,
            changed: endChanged)
        }
        if let validationMessage = validationMessage(presentation: presentation) {
          Text(validationMessage).font(.caption).foregroundStyle(.red)
        }
      }
      .padding()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(presentation.cancelText) { close(nil) }
        }
        ToolbarItem(placement: .principal) {
          if entryMode.allowsToggle {
            Button { toggleEntryMode() } label: { entryModeIcon }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(confirmLabel(presentation: presentation)) {
            close(selectedRange(presentation: presentation))
          }
          .disabled(validationMessage(presentation: presentation) != nil)
        }
      }
    }
  }

  @ViewBuilder
  private var entryModeIcon: some View {
    let presentation = presentation
    let configured = entryMode.usesCalendar
      ? presentation.switchToInputIcon
      : presentation.switchToCalendarIcon
    if let configured {
      RufletAppleIconView.registered(icon: configured, size: 18)
    } else {
      Image(systemName: entryMode.usesCalendar ? "keyboard" : "calendar")
    }
  }

  private func pickerColumn(
    isStart: Bool,
    title: String,
    hint: String?,
    date: Date,
    minimum: Date,
    maximum: Date,
    changed: @escaping (Date) -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline.weight(.semibold))
      if !entryMode.usesCalendar, let hint, !hint.isEmpty {
        Text(hint).font(.caption).foregroundStyle(.secondary)
      }
      if entryMode.usesCalendar {
        RufletNativeDatePicker(
          date: date,
          minimumDate: minimum,
          maximumDate: maximum,
          mode: .date,
          style: .inline,
          minuteInterval: 1,
          locale: presentation.locale,
          countdownDuration: nil
        ) { value, _ in changed(value) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        TextField(hint ?? title, text: isStart ? $startInputText : $endInputText)
          .textFieldStyle(.roundedBorder)
          .modifier(RufletPickerKeyboardModifier(type: presentation.keyboardType))
      }
    }
  }

  func synchronizePresentation() {
    guard control.boolean("open", default: false),
      !control.boolean("_open", default: false),
      !presented
    else { return }
    let presentation = presentation
    let current = presentation.currentDate ?? Date()
    draftStart = presentation.startValue ?? current
    draftEnd = presentation.endValue ?? current
    startInputText = rufletPickerDateText(draftStart, locale: presentation.locale)
    endInputText = rufletPickerDateText(draftEnd, locale: presentation.locale)
    entryMode = presentation.entryMode
    control.updateProperties(["_open": .bool(true)], server: false)
    closedByAction = false
    presented = true
  }

  private func startChanged(_ value: Date) {
    draftStart = value
  }

  private func endChanged(_ value: Date) {
    draftEnd = value
  }

  func toggleEntryMode() {
    entryMode = entryMode.usesCalendar ? .input : .calendar
    startInputText = rufletPickerDateText(draftStart, locale: presentation.locale)
    endInputText = rufletPickerDateText(draftEnd, locale: presentation.locale)
    control.updateProperties(["entry_mode": .string(entryMode.rawValue)])
  }

  func close(_ range: (Date, Date)?) {
    closedByAction = true
    control.updateProperties(["_open": .bool(false)], server: false)
    let start = range.map { rufletDateValue($0.0) } ?? control.value("start_value") ?? .null
    let end = range.map { rufletDateValue($0.1) } ?? control.value("end_value") ?? .null
    control.updateProperties([
      "start_value": start,
      "end_value": end,
      "open": .bool(false),
    ])
    if let range {
      control.triggerEvent(
        "change",
        data: ["start": rufletDateValue(range.0), "end": rufletDateValue(range.1)])
    }
    control.triggerEvent("dismiss", data: .bool(range == nil))
    presented = false
  }

  private func sheetDismissed() {
    if closedByAction { closedByAction = false } else { close(nil) }
  }

  private func confirmLabel(presentation: RufletDateRangePickerPresentation) -> String {
    if !entryMode.usesCalendar, let save = presentation.saveText { return save }
    return presentation.confirmText
  }

  private func selectedRange(
    presentation: RufletDateRangePickerPresentation
  ) -> (Date, Date)? {
    if entryMode.usesCalendar { return (draftStart, draftEnd) }
    guard
      let start = rufletParsePickerDate(startInputText, locale: presentation.locale),
      let end = rufletParsePickerDate(endInputText, locale: presentation.locale)
    else { return nil }
    return (start, end)
  }

  private func validationMessage(
    presentation: RufletDateRangePickerPresentation
  ) -> String? {
    let start: Date
    let end: Date
    if entryMode.usesCalendar {
      start = draftStart
      end = draftEnd
    } else {
      guard
        let parsedStart = rufletParsePickerDate(startInputText, locale: presentation.locale),
        let parsedEnd = rufletParsePickerDate(endInputText, locale: presentation.locale)
      else { return presentation.errorFormatText }
      start = parsedStart
      end = parsedEnd
    }
    if start > end { return presentation.errorInvalidRangeText }
    if start < presentation.minimumDate || end > presentation.maximumDate {
      return presentation.errorInvalidText
    }
    return nil
  }

  var presentation: RufletDateRangePickerPresentation {
    RufletDateRangePickerPresentation(control: control)
  }
}

@MainActor
struct RufletDateRangePickerPresentation {
  let currentDate: Date?
  let startValue: Date?
  let endValue: Date?
  let minimumDate: Date
  let maximumDate: Date
  let helpText: String?
  let cancelText: String
  let confirmText: String
  let saveText: String?
  let errorInvalidRangeText: String?
  let errorFormatText: String?
  let errorInvalidText: String?
  let fieldStartHintText: String?
  let fieldEndHintText: String?
  let fieldStartLabelText: String?
  let fieldEndLabelText: String?
  let keyboardType: String
  let entryMode: RufletDateEntryMode
  let locale: Locale?
  let modal: Bool
  let switchToCalendarIcon: RufletAppleIcon?
  let switchToInputIcon: RufletAppleIcon?

  init(control: RufletControl) {
    currentDate = parseRufletDate(control.value("current_date"))
    startValue = parseRufletDate(control.value("start_value"))
    endValue = parseRufletDate(control.value("end_value"))
    minimumDate = parseRufletDate(control.value("first_date"))
      ?? Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1))!
    maximumDate = parseRufletDate(control.value("last_date"))
      ?? Calendar.current.date(from: DateComponents(year: 2050, month: 1, day: 1))!
    helpText = control.string("help_text")
    cancelText = control.string("cancel_text", default: "Cancel") ?? "Cancel"
    confirmText = control.string("confirm_text", default: "OK") ?? "OK"
    saveText = control.string("save_text")
    errorInvalidRangeText = control.string("error_invalid_range_text")
    errorFormatText = control.string("error_format_text")
    errorInvalidText = control.string("error_invalid_text")
    fieldStartHintText = control.string("field_start_hint_text")
    fieldEndHintText = control.string("field_end_hint_text")
    fieldStartLabelText = control.string("field_start_label_text")
    fieldEndLabelText = control.string("field_end_label_text")
    keyboardType = control.string("keyboard_type", default: "text") ?? "text"
    entryMode = parseEnum(
      RufletDateEntryMode.self, control.string("entry_mode"), .calendar) ?? .calendar
    locale = parseLocale(control.dynamicValue("locale"))
    modal = control.boolean("modal", default: false)
    switchToCalendarIcon = Self.icon(control, property: "switch_to_calendar_icon")
    switchToInputIcon = Self.icon(control, property: "switch_to_input_icon")
  }

  private static func icon(_ control: RufletControl, property: String) -> RufletAppleIcon? {
    guard let code = control.integer(property) else { return nil }
    return control.backend.extensionRegistry.appleIcon(for: code)
  }
}
