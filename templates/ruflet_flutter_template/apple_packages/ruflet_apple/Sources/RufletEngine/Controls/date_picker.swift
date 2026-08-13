import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `date_picker.dart`.
@MainActor
public struct DatePickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var presented = false
  @State private var draft = Date()
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
        RufletNativeDatePicker(
          date: draft,
          minimumDate: minimumDate,
          maximumDate: maximumDate,
          mode: .date,
          style: entryMode.usesCalendar ? .inline : .compact,
          minuteInterval: 1,
          locale: parseLocale(control.dynamicValue("locale")),
          countdownDuration: nil
        ) { date, _ in
          draft = date
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .padding(parsePadding(control.dynamicValue("inset_padding"))
        ?? EdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16))
      .navigationTitle(control.string("field_label_text", default: "")!)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(control.string("cancel_text", default: "Cancel")!) { close(nil) }
        }
        ToolbarItem(placement: .principal) {
          if entryMode.allowsToggle {
            Button { toggleEntryMode() } label: {
              Image(systemName: entryMode.usesCalendar ? "keyboard" : "calendar")
            }
            .accessibilityLabel(entryMode.usesCalendar ? "Use date input" : "Use calendar")
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(control.string("confirm_text", default: "OK")!) { close(draft) }
        }
      }
    }
  }

  private func synchronizePresentation() {
    guard control.boolean("open", default: false),
          !control.boolean("_open", default: false),
          !presented
    else { return }
    draft = parseRufletDate(control.value("value"))
      ?? parseRufletDate(control.value("current_date"))
      ?? Date()
    entryMode = parseEnum(
      RufletDateEntryMode.self,
      control.string("entry_mode"),
      .calendar)!
    control.updateProperties(["_open": .bool(true)], server: false)
    closedByAction = false
    presented = true
  }

  private func toggleEntryMode() {
    entryMode = entryMode.usesCalendar ? .input : .calendar
    control.updateProperties(["entry_mode": .string(entryMode.rawValue)])
    control.triggerEvent("entry_mode_change", data: ["entry_mode": .string(entryMode.rawValue)])
  }

  private func close(_ date: Date?) {
    closedByAction = true
    control.updateProperties(["_open": .bool(false)], server: false)
    control.updateProperties([
      "value": date.map(rufletDateValue) ?? control.value("value") ?? .null,
      "open": .bool(false),
    ])
    if let date { control.triggerEvent("change", data: rufletDateValue(date)) }
    control.triggerEvent("dismiss", data: .bool(date == nil))
    presented = false
  }

  private func sheetDismissed() {
    if closedByAction {
      closedByAction = false
    } else {
      close(nil)
    }
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

enum RufletDateEntryMode: String, CaseIterable, RufletStringEnum {
  case calendar, input, calendarOnly, inputOnly

  var usesCalendar: Bool { self == .calendar || self == .calendarOnly }
  var allowsToggle: Bool { self == .calendar || self == .input }
}
