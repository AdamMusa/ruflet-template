import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `date_range_picker.dart`.
@MainActor
public struct DateRangePickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var presented = false
  @State private var draftStart = Date()
  @State private var draftEnd = Date()
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
          .interactiveDismissDisabled(control.boolean("modal", default: false))
      }
  }

  private var pickerSheet: some View {
    NavigationView {
      VStack(spacing: 12) {
        if let helpText = control.string("help_text") {
          Text(helpText).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
        }
        HStack(alignment: .top, spacing: 12) {
          pickerColumn(
            title: control.string("field_start_label_text", default: "Start date")!,
            date: draftStart,
            minimum: minimumDate,
            maximum: min(draftEnd, maximumDate),
            changed: startChanged)
          pickerColumn(
            title: control.string("field_end_label_text", default: "End date")!,
            date: draftEnd,
            minimum: max(draftStart, minimumDate),
            maximum: maximumDate,
            changed: endChanged)
        }
      }
      .padding()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(control.string("cancel_text", default: "Cancel")!) { close(nil) }
        }
        ToolbarItem(placement: .principal) {
          if entryMode.allowsToggle {
            Button { toggleEntryMode() } label: {
              Image(systemName: entryMode.usesCalendar ? "keyboard" : "calendar")
            }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(confirmLabel) { close((draftStart, draftEnd)) }
        }
      }
    }
  }

  private func pickerColumn(
    title: String,
    date: Date,
    minimum: Date,
    maximum: Date,
    changed: @escaping (Date) -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline.weight(.semibold))
      RufletNativeDatePicker(
        date: date,
        minimumDate: minimum,
        maximumDate: maximum,
        mode: .date,
        style: entryMode.usesCalendar ? .inline : .compact,
        minuteInterval: 1,
        locale: parseLocale(control.dynamicValue("locale")),
        countdownDuration: nil
      ) { value, _ in changed(value) }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func synchronizePresentation() {
    guard control.boolean("open", default: false),
          !control.boolean("_open", default: false),
          !presented
    else { return }
    let current = parseRufletDate(control.value("current_date")) ?? Date()
    draftStart = parseRufletDate(control.value("start_value")) ?? current
    draftEnd = parseRufletDate(control.value("end_value")) ?? current
    if draftEnd < draftStart { draftEnd = draftStart }
    entryMode = parseEnum(RufletDateEntryMode.self, control.string("entry_mode"), .calendar)!
    control.updateProperties(["_open": .bool(true)], server: false)
    closedByAction = false
    presented = true
  }

  private func startChanged(_ value: Date) {
    draftStart = value
    if draftEnd < value { draftEnd = value }
  }

  private func endChanged(_ value: Date) {
    draftEnd = value
    if draftStart > value { draftStart = value }
  }

  private func toggleEntryMode() {
    entryMode = entryMode.usesCalendar ? .input : .calendar
    control.updateProperties(["entry_mode": .string(entryMode.rawValue)])
    control.triggerEvent("entry_mode_change", data: ["entry_mode": .string(entryMode.rawValue)])
  }

  private func close(_ range: (Date, Date)?) {
    closedByAction = true
    control.updateProperties(["_open": .bool(false)], server: false)
    let start = range.map { rufletDateValue($0.0) } ?? control.value("start_value") ?? .null
    let end = range.map { rufletDateValue($0.1) } ?? control.value("end_value") ?? .null
    control.updateProperties([
      "start_value": start,
      "end_value": end,
      "open": .bool(false),
    ])
    if range != nil {
      control.triggerEvent("change", data: ["start": start, "end": end])
    }
    control.triggerEvent("dismiss", data: .bool(range == nil))
    presented = false
  }

  private func sheetDismissed() {
    if closedByAction { closedByAction = false } else { close(nil) }
  }

  private var confirmLabel: String {
    if !entryMode.usesCalendar, let save = control.string("save_text") { return save }
    return control.string("confirm_text", default: "OK")!
  }
  private var minimumDate: Date {
    parseRufletDate(control.value("first_date"))
      ?? Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1))!
  }
  private var maximumDate: Date {
    parseRufletDate(control.value("last_date"))
      ?? Calendar.current.date(from: DateComponents(year: 2050, month: 1, day: 1))!
  }
}
