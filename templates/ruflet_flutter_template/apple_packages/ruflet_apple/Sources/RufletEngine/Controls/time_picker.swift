import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `time_picker.dart`.
@MainActor
public struct TimePickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var presented = false
  @State private var draft = Date()
  @State private var entryMode = RufletTimeEntryMode.dial
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
          minimumDate: nil,
          maximumDate: nil,
          mode: .time,
          style: entryMode.usesDial ? .wheels : .compact,
          minuteInterval: 1,
          locale: effectiveLocale,
          countdownDuration: nil
        ) { value, _ in draft = value }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .padding()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(control.string("cancel_text", default: "Cancel")!) { close(nil) }
        }
        ToolbarItem(placement: .principal) {
          if entryMode.allowsToggle {
            Button { toggleEntryMode() } label: {
              Image(systemName: entryMode.usesDial ? "keyboard" : "clock")
            }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(control.string("confirm_text", default: "OK")!) { close(timeOfDay(from: draft)) }
        }
      }
    }
  }

  private func synchronizePresentation() {
    guard control.boolean("open", default: false),
          !control.boolean("_open", default: false),
          !presented
    else { return }
    let now = timeOfDay(from: Date())
    let value = parseRufletTime(control.value("value"), now)!
    draft = Calendar.current.date(
      bySettingHour: value.hour,
      minute: value.minute,
      second: 0,
      of: Date()) ?? Date()
    entryMode = parseEnum(RufletTimeEntryMode.self, control.string("entry_mode"), .dial)!
    control.updateProperties(["_open": .bool(true)], server: false)
    closedByAction = false
    presented = true
  }

  private func toggleEntryMode() {
    entryMode = entryMode.usesDial ? .input : .dial
    control.updateProperties(["entry_mode": .string(entryMode.rawValue)])
    control.triggerEvent("entry_mode_change", data: ["entry_mode": .string(entryMode.rawValue)])
  }

  private func close(_ value: RufletTimeOfDay?) {
    closedByAction = true
    control.updateProperties(["_open": .bool(false)], server: false)
    let wire = value.map(rufletTimeValue) ?? .null
    control.updateProperties(["value": wire, "open": .bool(false)])
    if value != nil { control.triggerEvent("change", data: wire) }
    control.triggerEvent("dismiss", data: .bool(value == nil))
    presented = false
  }

  private func sheetDismissed() {
    if closedByAction { closedByAction = false } else { close(nil) }
  }

  private func timeOfDay(from date: Date) -> RufletTimeOfDay {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return RufletTimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
  }

  private var effectiveLocale: Locale? {
    let configured = parseLocale(control.dynamicValue("locale"))
    return switch control.string("hour_format")?.lowercased() {
    case "h12": Locale(identifier: "en_US")
    case "h24": Locale(identifier: "en_GB")
    default: configured
    }
  }
}

private enum RufletTimeEntryMode: String, CaseIterable, RufletStringEnum {
  case dial, input, dialOnly, inputOnly
  var usesDial: Bool { self == .dial || self == .dialOnly }
  var allowsToggle: Bool { self == .dial || self == .input }
}
