import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `cupertino_date_picker.dart`.
@MainActor
public struct CupertinoDatePickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var value: Date

  public init(control: RufletControl) {
    self.control = control
    _value = State(initialValue: parseRufletDate(control.value("value")) ?? Date())
  }

  public var body: some View {
    let configuration = RufletCupertinoDateWheelConfiguration(control: control)
    LayoutControl(control: control) {
      picker(configuration: configuration)
        .frame(minHeight: configuration.itemExtent * 5)
        .background(parseColor(control.string("bgcolor")) ?? .clear)
    }
    .onChange(of: control.properties) { _ in
      if let next = parseRufletDate(control.value("value")), next != value { value = next }
    }
  }

  @ViewBuilder
  private func picker(configuration: RufletCupertinoDateWheelConfiguration) -> some View {
    if pickerMode == .date || pickerMode == .monthYear {
      RufletCupertinoDateWheel(
        value: value,
        configuration: configuration,
        onChange: commit
      )
    } else {
      RufletNativeDatePicker(
        date: value,
        minimumDate: minimumDate,
        maximumDate: maximumDate,
        mode: pickerMode.native,
        style: .wheels,
        minuteInterval: control.integer("minute_interval", default: 1) ?? 1,
        locale: effectiveLocale,
        countdownDuration: nil
      ) { next, _ in
        commit(next)
      }
    }
  }

  private func commit(_ next: Date) {
    guard abs(next.timeIntervalSince1970 - value.timeIntervalSince1970) > 0.5 else { return }
    value = next
    let wire = rufletDateValue(next)
    control.updateProperties(["value": wire])
    control.triggerEvent("change", data: wire)
  }

  private var pickerMode: RufletCupertinoDatePickerMode {
    parseEnum(
      RufletCupertinoDatePickerMode.self,
      control.string("date_picker_mode"),
      .dateAndTime)!
  }

  private var minimumDate: Date? {
    if let date = parseRufletDate(control.value("first_date")) { return date }
    guard pickerMode == .date || pickerMode == .monthYear else { return nil }
    return Calendar.current.date(
      from: DateComponents(
        year: control.integer("minimum_year", default: 1) ?? 1,
        month: 1,
        day: 1))
  }
  private var maximumDate: Date? {
    if let date = parseRufletDate(control.value("last_date")) { return date }
    guard let year = control.integer("maximum_year") else { return nil }
    return Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31))
  }
  private var effectiveLocale: Locale? {
    if let locale = parseLocale(control.dynamicValue("locale")) { return locale }
    if control.boolean("use_24h_format", default: false) { return Locale(identifier: "en_GB") }
    return nil
  }
}

enum RufletCupertinoDatePickerMode: String, CaseIterable, RufletStringEnum {
  case time, date, dateAndTime, monthYear

  var native: RufletNativeDatePickerMode {
    switch self {
    case .time: .time
    case .date, .monthYear: .date
    case .dateAndTime: .dateAndTime
    }
  }
}
