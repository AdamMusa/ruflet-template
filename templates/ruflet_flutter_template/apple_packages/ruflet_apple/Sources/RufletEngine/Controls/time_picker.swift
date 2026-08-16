import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `time_picker.dart`.
@MainActor
public struct TimePickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var presented = false
  @State private var draft = Date()
  @State private var entryMode = RufletTimeEntryMode.dial

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    Group {
      if presented {
        RufletPickerDialogLayer(
          barrierColor: presentation.barrierColor,
          barrierDismissible: !presentation.modal,
          onDismiss: { close(nil) }
        ) {
          pickerSheet
        }
      }
    }
      .onAppear(perform: synchronizePresentation)
      .onChange(of: control.properties) { _ in synchronizePresentation() }
  }

  private var pickerSheet: some View {
    let presentation = presentation
    return NavigationView {
      pickerContent(presentation: presentation)
        .padding()
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(presentation.cancelText) { close(nil) }
          }
          ToolbarItem(placement: .principal) {
            if entryMode.allowsToggle {
              Button {
                toggleEntryMode()
              } label: {
                entryModeIcon
              }
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(presentation.confirmText) { close(timeOfDay(from: draft)) }
          }
        }
    }
  }

  @ViewBuilder
  private func pickerContent(presentation: RufletTimePickerPresentation) -> some View {
    let content = Group {
      if let helpText = presentation.helpText {
        Text(helpText).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack(spacing: 8) {
        Text(presentation.hourLabelText ?? "Hour").font(.caption).foregroundStyle(.secondary)
        Text(presentation.minuteLabelText ?? "Minute").font(.caption).foregroundStyle(.secondary)
      }
      RufletNativeDatePicker(
        date: draft,
        minimumDate: nil,
        maximumDate: nil,
        mode: .time,
        style: entryMode.usesDial ? .wheels : .compact,
        minuteInterval: 1,
        locale: presentation.effectiveLocale,
        countdownDuration: nil
      ) { value, _ in draft = value }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      if entryMode == .input, let error = presentation.errorInvalidText {
        Text(error).font(.caption).foregroundStyle(.clear).accessibilityHidden(true)
      }
    }
    if presentation.orientation == .landscape {
      HStack(alignment: .center, spacing: 12) { content }
    } else {
      VStack(spacing: 12) { content }
    }
  }

  @ViewBuilder
  private var entryModeIcon: some View {
    let presentation = presentation
    let configured =
      entryMode.usesDial
      ? presentation.switchToInputIcon
      : presentation.switchToTimerIcon
    if let configured {
      RufletAppleIconView.registered(icon: configured, size: 18)
    } else {
      Image(systemName: entryMode.usesDial ? "keyboard" : "clock")
    }
  }

  func synchronizePresentation() {
    guard control.boolean("open", default: false),
      !control.boolean("_open", default: false),
      !presented
    else { return }
    let presentation = presentation
    let value = presentation.value ?? timeOfDay(from: Date())
    draft =
      Calendar.current.date(
        bySettingHour: value.hour,
        minute: value.minute,
        second: 0,
        of: Date()) ?? Date()
    entryMode = presentation.entryMode
    control.updateProperties(["_open": .bool(true)], server: false)
    presented = true
  }

  func toggleEntryMode() {
    entryMode = entryMode.usesDial ? .input : .dial
    control.updateProperties(["entry_mode": .string(entryMode.rawValue)])
    control.triggerEvent("entry_mode_change", data: ["entry_mode": .string(entryMode.rawValue)])
  }

  func close(_ value: RufletTimeOfDay?) {
    control.updateProperties(["_open": .bool(false)], server: false)
    let wire = value.map(rufletTimeValue) ?? .null
    control.updateProperties(["value": wire, "open": .bool(false)])
    if value != nil { control.triggerEvent("change", data: wire) }
    control.triggerEvent("dismiss", data: .bool(value == nil))
    presented = false
  }

  private func timeOfDay(from date: Date) -> RufletTimeOfDay {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return RufletTimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
  }

  var presentation: RufletTimePickerPresentation {
    RufletTimePickerPresentation(control: control)
  }
}

enum RufletTimeEntryMode: String, CaseIterable, RufletStringEnum {
  case dial, input, dialOnly, inputOnly
  var usesDial: Bool { self == .dial || self == .dialOnly }
  var allowsToggle: Bool { self == .dial || self == .input }
}

enum RufletPickerOrientation: String, CaseIterable, RufletStringEnum {
  case portrait, landscape
}

@MainActor
struct RufletTimePickerPresentation {
  let value: RufletTimeOfDay?
  let helpText: String?
  let cancelText: String
  let confirmText: String
  let hourLabelText: String?
  let minuteLabelText: String?
  let errorInvalidText: String?
  let entryMode: RufletTimeEntryMode
  let orientation: RufletPickerOrientation?
  let locale: Locale?
  let hourFormat: String?
  let effectiveLocale: Locale?
  let modal: Bool
  let barrierColor: Color?
  let switchToTimerIcon: RufletAppleIcon?
  let switchToInputIcon: RufletAppleIcon?

  init(control: RufletControl) {
    value = parseRufletTime(control.value("value"))
    helpText = control.string("help_text")
    cancelText = control.string("cancel_text", default: "Cancel") ?? "Cancel"
    confirmText = control.string("confirm_text", default: "OK") ?? "OK"
    hourLabelText = control.string("hour_label_text")
    minuteLabelText = control.string("minute_label_text")
    errorInvalidText = control.string("error_invalid_text")
    entryMode =
      parseEnum(
        RufletTimeEntryMode.self, control.string("entry_mode"), .dial) ?? .dial
    orientation = parseEnum(
      RufletPickerOrientation.self, control.string("orientation"), nil)
    locale = parseLocale(control.dynamicValue("locale"))
    hourFormat = control.string("hour_format")?.lowercased()
    switch hourFormat {
    case "h12": effectiveLocale = Locale(identifier: "en_US")
    case "h24": effectiveLocale = Locale(identifier: "en_GB")
    default: effectiveLocale = locale
    }
    modal = control.boolean("modal", default: false)
    barrierColor = parseColor(control.string("barrier_color"))
    switchToTimerIcon = Self.icon(control, property: "switch_to_timer_icon")
    switchToInputIcon = Self.icon(control, property: "switch_to_input_icon")
  }

  private static func icon(_ control: RufletControl, property: String) -> RufletAppleIcon? {
    guard let code = control.integer(property) else { return nil }
    return control.backend.extensionRegistry.appleIcon(for: code)
  }
}
