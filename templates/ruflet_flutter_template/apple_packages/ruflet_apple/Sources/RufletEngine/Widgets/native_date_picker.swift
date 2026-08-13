import SwiftUI

#if os(iOS)
import UIKit

enum RufletNativeDatePickerMode { case date, time, dateAndTime, countdown }
enum RufletNativeDatePickerStyle { case automatic, compact, inline, wheels }

struct RufletNativeDatePicker: UIViewRepresentable {
  let date: Date
  let minimumDate: Date?
  let maximumDate: Date?
  let mode: RufletNativeDatePickerMode
  let style: RufletNativeDatePickerStyle
  let minuteInterval: Int
  let locale: Locale?
  let countdownDuration: TimeInterval?
  let onChange: (Date, TimeInterval?) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

  func makeUIView(context: Context) -> UIDatePicker {
    let picker = UIDatePicker()
    picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
    return picker
  }

  func updateUIView(_ picker: UIDatePicker, context: Context) {
    context.coordinator.onChange = onChange
    picker.datePickerMode = mode.uiKit
    picker.preferredDatePickerStyle = style.uiKit
    picker.minimumDate = minimumDate
    picker.maximumDate = maximumDate
    picker.minuteInterval = minuteInterval
    picker.locale = locale
    if mode == .countdown, let countdownDuration {
      if abs(picker.countDownDuration - countdownDuration) > 0.5 {
        picker.countDownDuration = countdownDuration
      }
    } else if abs(picker.date.timeIntervalSince1970 - date.timeIntervalSince1970) > 0.5 {
      picker.setDate(date, animated: false)
    }
  }

  final class Coordinator: NSObject {
    var onChange: (Date, TimeInterval?) -> Void
    init(onChange: @escaping (Date, TimeInterval?) -> Void) { self.onChange = onChange }
    @objc func changed(_ picker: UIDatePicker) {
      onChange(picker.date, picker.datePickerMode == .countDownTimer ? picker.countDownDuration : nil)
    }
  }
}

private extension RufletNativeDatePickerMode {
  var uiKit: UIDatePicker.Mode {
    switch self {
    case .date: .date
    case .time: .time
    case .dateAndTime: .dateAndTime
    case .countdown: .countDownTimer
    }
  }
}

private extension RufletNativeDatePickerStyle {
  var uiKit: UIDatePickerStyle {
    switch self {
    case .automatic: .automatic
    case .compact: .compact
    case .inline: .inline
    case .wheels: .wheels
    }
  }
}
#elseif os(macOS)
import AppKit

enum RufletNativeDatePickerMode { case date, time, dateAndTime, countdown }
enum RufletNativeDatePickerStyle { case automatic, compact, inline, wheels }

struct RufletNativeDatePicker: NSViewRepresentable {
  let date: Date
  let minimumDate: Date?
  let maximumDate: Date?
  let mode: RufletNativeDatePickerMode
  let style: RufletNativeDatePickerStyle
  let minuteInterval: Int
  let locale: Locale?
  let countdownDuration: TimeInterval?
  let onChange: (Date, TimeInterval?) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

  func makeNSView(context: Context) -> NSDatePicker {
    let picker = NSDatePicker()
    picker.target = context.coordinator
    picker.action = #selector(Coordinator.changed(_:))
    return picker
  }

  func updateNSView(_ picker: NSDatePicker, context: Context) {
    context.coordinator.onChange = onChange
    picker.datePickerElements = mode.appKit
    picker.datePickerStyle = style == .compact ? .textFieldAndStepper : .clockAndCalendar
    picker.minDate = minimumDate
    picker.maxDate = maximumDate
    picker.locale = locale
    picker.dateValue = mode == .countdown
      ? Date(timeIntervalSinceReferenceDate: countdownDuration ?? 0)
      : date
  }

  final class Coordinator: NSObject {
    var onChange: (Date, TimeInterval?) -> Void
    init(onChange: @escaping (Date, TimeInterval?) -> Void) { self.onChange = onChange }
    @objc func changed(_ picker: NSDatePicker) {
      let duration = picker.datePickerElements.contains(.hourMinuteSecond)
        ? picker.dateValue.timeIntervalSinceReferenceDate : nil
      onChange(picker.dateValue, duration)
    }
  }
}

private extension RufletNativeDatePickerMode {
  var appKit: NSDatePicker.ElementFlags {
    switch self {
    case .date: [.yearMonthDay]
    case .time, .countdown: [.hourMinuteSecond]
    case .dateAndTime: [.yearMonthDay, .hourMinuteSecond]
    }
  }
}
#endif
