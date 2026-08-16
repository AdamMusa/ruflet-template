import RufletProtocol
import SwiftUI

#if os(iOS)
  import UIKit
#endif

/// Apple-native port of pinned `date_picker.dart`.
@MainActor
public struct DatePickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var presented = false
  @State private var draft = Date()
  @State private var inputText = ""
  @State private var entryMode = RufletDateEntryMode.calendar

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
      VStack(spacing: 12) {
        if let helpText = presentation.helpText {
          Text(helpText).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
        }
        if entryMode.usesCalendar {
          RufletNativeDatePicker(
            date: draft,
            minimumDate: presentation.minimumDate,
            maximumDate: presentation.maximumDate,
            mode: .date,
            style: pickerStyle,
            minuteInterval: 1,
            locale: presentation.locale,
            countdownDuration: nil
          ) { date, _ in
            draft = date
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          TextField(
            presentation.fieldHintText ?? presentation.fieldLabelText ?? "Date",
            text: $inputText
          )
          .textFieldStyle(.roundedBorder)
          .modifier(RufletPickerKeyboardModifier(type: presentation.keyboardType))
          .onChange(of: inputText) { text in
            if let parsed = rufletParsePickerDate(text, locale: presentation.locale) {
              draft = parsed
            }
          }
        }
      }
      .padding(presentation.insetPadding)
      .navigationTitle(presentation.fieldLabelText ?? "")
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
            .accessibilityLabel(entryMode.usesCalendar ? "Use date input" : "Use calendar")
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(presentation.confirmText) {
            close(
              entryMode.usesCalendar
                ? draft
                : rufletParsePickerDate(inputText, locale: presentation.locale))
          }
          .disabled(validationMessage(presentation: presentation) != nil)
        }
      }
      .overlay(alignment: .top) {
        if let validationMessage = validationMessage(presentation: presentation) {
          Text(validationMessage)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 8)
        }
      }
    }
  }

  @ViewBuilder
  private var entryModeIcon: some View {
    let presentation = presentation
    let configured =
      entryMode.usesCalendar
      ? presentation.switchToInputIcon
      : presentation.switchToCalendarIcon
    if let configured {
      RufletAppleIconView.registered(icon: configured, size: 18)
    } else {
      Image(systemName: entryMode.usesCalendar ? "keyboard" : "calendar")
    }
  }

  private var pickerStyle: RufletNativeDatePickerStyle {
    guard entryMode.usesCalendar else { return .compact }
    return presentation.datePickerMode == .year ? .compact : .inline
  }

  func synchronizePresentation() {
    guard control.boolean("open", default: false),
      !control.boolean("_open", default: false),
      !presented
    else { return }
    let presentation = presentation
    draft = presentation.value ?? presentation.currentDate ?? Date()
    inputText = rufletPickerDateText(draft, locale: presentation.locale)
    entryMode = presentation.entryMode
    control.updateProperties(["_open": .bool(true)], server: false)
    presented = true
  }

  func toggleEntryMode() {
    entryMode = entryMode.usesCalendar ? .input : .calendar
    inputText = rufletPickerDateText(draft, locale: presentation.locale)
    control.updateProperties(["entry_mode": .string(entryMode.rawValue)])
    control.triggerEvent("entry_mode_change", data: ["entry_mode": .string(entryMode.rawValue)])
  }

  func close(_ date: Date?) {
    control.updateProperties(["_open": .bool(false)], server: false)
    control.updateProperties([
      "value": date.map(rufletDateValue) ?? control.value("value") ?? .null,
      "open": .bool(false),
    ])
    if let date { control.triggerEvent("change", data: rufletDateValue(date)) }
    control.triggerEvent("dismiss", data: .bool(date == nil))
    presented = false
  }

  private func validationMessage(presentation: RufletDatePickerPresentation) -> String? {
    guard entryMode == .input else { return nil }
    guard let parsed = rufletParsePickerDate(inputText, locale: presentation.locale) else {
      return presentation.errorFormatText
    }
    if parsed < presentation.minimumDate || parsed > presentation.maximumDate {
      return presentation.errorInvalidText
    }
    return nil
  }

  var presentation: RufletDatePickerPresentation {
    RufletDatePickerPresentation(control: control)
  }
}

enum RufletDateEntryMode: String, CaseIterable, RufletStringEnum {
  case calendar, input, calendarOnly, inputOnly

  var usesCalendar: Bool { self == .calendar || self == .calendarOnly }
  var allowsToggle: Bool { self == .calendar || self == .input }
}

enum RufletDatePickerMode: String, CaseIterable, RufletStringEnum {
  case day, year
}

@MainActor
struct RufletDatePickerPresentation {
  let value: Date?
  let currentDate: Date?
  let minimumDate: Date
  let maximumDate: Date
  let helpText: String?
  let cancelText: String
  let confirmText: String
  let errorFormatText: String?
  let errorInvalidText: String?
  let keyboardType: String
  let datePickerMode: RufletDatePickerMode
  let entryMode: RufletDateEntryMode
  let fieldHintText: String?
  let fieldLabelText: String?
  let insetPadding: EdgeInsets
  let locale: Locale?
  let modal: Bool
  let barrierColor: Color?
  let switchToCalendarIcon: RufletAppleIcon?
  let switchToInputIcon: RufletAppleIcon?

  init(control: RufletControl) {
    value = parseRufletDate(control.value("value"))
    currentDate = parseRufletDate(control.value("current_date"))
    minimumDate =
      parseRufletDate(control.value("first_date"))
      ?? Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1))!
    maximumDate =
      parseRufletDate(control.value("last_date"))
      ?? Calendar.current.date(from: DateComponents(year: 2050, month: 1, day: 1))!
    helpText = control.string("help_text")
    cancelText = control.string("cancel_text", default: "Cancel") ?? "Cancel"
    confirmText = control.string("confirm_text", default: "OK") ?? "OK"
    errorFormatText = control.string("error_format_text")
    errorInvalidText = control.string("error_invalid_text")
    keyboardType = control.string("keyboard_type", default: "text") ?? "text"
    datePickerMode =
      parseEnum(
        RufletDatePickerMode.self, control.string("date_picker_mode"), .day) ?? .day
    entryMode =
      parseEnum(
        RufletDateEntryMode.self, control.string("entry_mode"), .calendar) ?? .calendar
    fieldHintText = control.string("field_hint_text")
    fieldLabelText = control.string("field_label_text")
    insetPadding =
      parsePadding(control.dynamicValue("inset_padding"))
      ?? EdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16)
    locale = parseLocale(control.dynamicValue("locale"))
    modal = control.boolean("modal", default: false)
    barrierColor = parseColor(control.string("barrier_color"))
    switchToCalendarIcon = Self.icon(control, property: "switch_to_calendar_icon")
    switchToInputIcon = Self.icon(control, property: "switch_to_input_icon")
  }

  private static func icon(_ control: RufletControl, property: String) -> RufletAppleIcon? {
    guard let code = control.integer(property) else { return nil }
    return control.backend.extensionRegistry.appleIcon(for: code)
  }
}

/// Shared Material-dialog presentation used by Flet's date, date-range and
/// time pickers. Unlike SwiftUI's system sheet, this owns the complete modal
/// barrier, matching `showDialog`'s `barrierColor` and `barrierDismissible`
/// contract on every Apple deployment target.
@MainActor
struct RufletPickerDialogLayer<Content: View>: View {
  let barrierColor: Color?
  let barrierDismissible: Bool
  let onDismiss: () -> Void
  let content: Content

  init(
    barrierColor: Color?,
    barrierDismissible: Bool,
    onDismiss: @escaping () -> Void,
    @ViewBuilder content: () -> Content
  ) {
    self.barrierColor = barrierColor
    self.barrierDismissible = barrierDismissible
    self.onDismiss = onDismiss
    self.content = content()
  }

  var body: some View {
    ZStack {
      (barrierColor ?? Color.black.opacity(0.54))
        .contentShape(Rectangle())
        .onTapGesture {
          if barrierDismissible { onDismiss() }
        }
      dialog
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .zIndex(100)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }

  private var dialog: some View {
    content
      #if os(macOS)
      .frame(
        minWidth: 420, idealWidth: 520, maxWidth: 720,
        minHeight: 420, idealHeight: 520, maxHeight: 720)
      #else
      .frame(maxWidth: 720, minHeight: 360, maxHeight: 720)
      #endif
      .background(Color.rufletSystemBackground)
      .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
      .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
      .padding(24)
  }
}

func rufletPickerDateText(_ date: Date, locale: Locale?) -> String {
  let formatter = DateFormatter()
  formatter.locale = locale
  formatter.dateStyle = .short
  formatter.timeStyle = .none
  return formatter.string(from: date)
}

func rufletParsePickerDate(_ text: String, locale: Locale?) -> Date? {
  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return nil }
  let formatter = DateFormatter()
  formatter.locale = locale
  formatter.dateStyle = .short
  formatter.timeStyle = .none
  formatter.isLenient = false
  if let date = formatter.date(from: trimmed) { return date }
  return parseRufletDate(.string(trimmed))
}

struct RufletPickerKeyboardModifier: ViewModifier {
  let type: String

  @ViewBuilder
  func body(content: Content) -> some View {
    #if os(iOS)
      content.keyboardType(keyboardType)
    #else
      content
    #endif
  }

  #if os(iOS)
    private var keyboardType: UIKeyboardType {
      switch type.lowercased() {
      case "datetime": return .numbersAndPunctuation
      case "email": return .emailAddress
      case "name": return .namePhonePad
      case "number": return .decimalPad
      case "phone": return .phonePad
      case "url": return .URL
      case "visiblepassword": return .asciiCapable
      case "websearch": return .webSearch
      case "twitter": return .twitter
      default: return .default
      }
    }
  #endif
}
