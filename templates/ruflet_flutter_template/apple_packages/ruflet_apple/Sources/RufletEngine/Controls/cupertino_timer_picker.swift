import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `cupertino_timer_picker.dart`.
@MainActor
public struct CupertinoTimerPickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var hours: Int
  @State private var minutes: Int
  @State private var seconds: Int
  @State private var synchronizing = false

  public init(control: RufletControl) {
    self.control = control
    let duration = parseRufletWireDuration(control.value("value"), 0, numberUnit: .seconds) ?? 0
    let total = max(Int(duration), 0)
    _hours = State(initialValue: min(total / 3_600, 23))
    _minutes = State(initialValue: (total / 60) % 60)
    _seconds = State(initialValue: total % 60)
  }

  public var body: some View {
    LayoutControl(control: control) {
      HStack(spacing: 4) {
        if mode != .ms { componentPicker("hours", selection: $hours, values: Array(0..<24)) }
        if mode != .ms { Text(":").font(.title2.monospacedDigit()) }
        componentPicker("minutes", selection: $minutes, values: minuteValues)
        if mode != .hm {
          Text(":").font(.title2.monospacedDigit())
          componentPicker("seconds", selection: $seconds, values: secondValues)
        }
      }
      .frame(minHeight: itemExtent * 5, alignment: alignment)
      .background(parseColor(control.string("bgcolor")) ?? .clear)
      .clipped()
    }
    .onChange(of: hours) { _ in selectionChanged() }
    .onChange(of: minutes) { _ in selectionChanged() }
    .onChange(of: seconds) { _ in selectionChanged() }
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  @ViewBuilder
  private func componentPicker(_ label: String, selection: Binding<Int>, values: [Int]) -> some View {
    #if os(iOS)
    Picker(label, selection: selection) {
      ForEach(values, id: \.self) { value in
        Text(String(format: "%02d", value)).tag(value)
      }
    }
    .pickerStyle(.wheel)
    .labelsHidden()
    .frame(maxWidth: 90)
    #elseif os(macOS)
    Picker(label, selection: selection) {
      ForEach(values, id: \.self) { value in
        Text(String(format: "%02d", value)).tag(value)
      }
    }
    .pickerStyle(.menu)
    .labelsHidden()
    .frame(maxWidth: 90)
    #endif
  }

  private func selectionChanged() {
    guard !synchronizing else { return }
    let duration = TimeInterval(hours * 3_600 + minutes * 60 + seconds)
    let existing = parseRufletWireDuration(control.value("value"), nil, numberUnit: .seconds)
    guard existing == nil || abs(existing! - duration) > 0.5 else { return }
    let wire: RufletValue
    if case .int = control.value("value") {
      wire = .int(Int64(duration))
    } else {
      wire = rufletDurationValue(duration)
    }
    control.updateProperties(["value": wire])
    control.triggerEvent("change", data: wire)
  }

  private func synchronizeFromControl() {
    let duration = parseRufletWireDuration(control.value("value"), 0, numberUnit: .seconds) ?? 0
    let total = max(Int(duration), 0)
    synchronizing = true
    hours = min(total / 3_600, 23)
    minutes = nearest(total: (total / 60) % 60, values: minuteValues)
    seconds = nearest(total: total % 60, values: secondValues)
    DispatchQueue.main.async { synchronizing = false }
  }

  private func nearest(total: Int, values: [Int]) -> Int {
    values.min(by: { abs($0 - total) < abs($1 - total) }) ?? 0
  }

  private var mode: RufletCupertinoTimerPickerMode {
    parseEnum(RufletCupertinoTimerPickerMode.self, control.string("mode"), .hms)!
  }
  private var minuteValues: [Int] {
    Array(stride(from: 0, to: 60, by: max(control.integer("minute_interval", default: 1) ?? 1, 1)))
  }
  private var secondValues: [Int] {
    Array(stride(from: 0, to: 60, by: max(control.integer("second_interval", default: 1) ?? 1, 1)))
  }
  private var itemExtent: CGFloat { CGFloat(control.number("item_extent", default: 32) ?? 32) }
  private var alignment: Alignment {
    parseAlignment(control.dynamicValue("alignment"), .center)!.swiftUI
  }
}

private enum RufletCupertinoTimerPickerMode: String, CaseIterable, RufletStringEnum {
  case hm, ms, hms
}
