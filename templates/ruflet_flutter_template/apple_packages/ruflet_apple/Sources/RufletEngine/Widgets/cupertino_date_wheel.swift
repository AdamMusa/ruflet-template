import SwiftUI

enum RufletDatePickerDateOrder: String, CaseIterable, RufletStringEnum {
  case dmy, mdy, ymd, ydm
}

enum RufletDateWheelComponent: Equatable {
  case day, month, year
}

@MainActor
struct RufletCupertinoDateWheelConfiguration {
  let calendar: Calendar
  let dateOrder: RufletDatePickerDateOrder
  let itemExtent: CGFloat
  let locale: Locale
  let maximumDate: Date?
  let maximumYear: Int
  let minimumDate: Date?
  let minimumYear: Int
  let mode: RufletCupertinoDatePickerMode
  let showDayOfWeek: Bool

  init(control: RufletControl) {
    locale = parseLocale(control.dynamicValue("locale")) ?? .current
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = locale
    self.calendar = calendar
    mode = parseEnum(
      RufletCupertinoDatePickerMode.self,
      control.string("date_picker_mode"),
      .dateAndTime)!
    let explicitOrder = parseEnum(
      RufletDatePickerDateOrder.self,
      control.string("date_order"))
    dateOrder = explicitOrder ?? Self.localizedDateOrder(locale: locale)
    showDayOfWeek = control.boolean("show_day_of_week", default: false)
    itemExtent = CGFloat(control.number("item_extent", default: 32) ?? 32)
    minimumDate = parseRufletDate(control.value("first_date"))
    maximumDate = parseRufletDate(control.value("last_date"))
    let declaredMinimumYear = max(control.integer("minimum_year", default: 1) ?? 1, 1)
    minimumYear = max(
      declaredMinimumYear,
      minimumDate.map { calendar.component(.year, from: $0) } ?? declaredMinimumYear)
    let declaredMaximumYear = control.integer("maximum_year") ?? 9_999
    maximumYear = max(
      min(
        declaredMaximumYear,
        maximumDate.map { calendar.component(.year, from: $0) } ?? declaredMaximumYear),
      minimumYear)
    precondition(itemExtent > 0, "item_extent must be greater than zero")
  }

  var components: [RufletDateWheelComponent] {
    if mode == .monthYear {
      switch dateOrder {
      case .dmy, .mdy: return [.month, .year]
      case .ymd, .ydm: return [.year, .month]
      }
    }
    switch dateOrder {
    case .dmy: return [.day, .month, .year]
    case .mdy: return [.month, .day, .year]
    case .ymd: return [.year, .month, .day]
    case .ydm: return [.year, .day, .month]
    }
  }

  func rowCount(for component: RufletDateWheelComponent, value: Date) -> Int {
    switch component {
    case .day: return calendar.range(of: .day, in: .month, for: value)?.count ?? 31
    case .month: return 12
    case .year: return maximumYear - minimumYear + 1
    }
  }

  func selectedRow(for component: RufletDateWheelComponent, value: Date) -> Int {
    switch component {
    case .day:
      return min(
        max(calendar.component(.day, from: value) - 1, 0),
        rowCount(for: .day, value: value) - 1)
    case .month: return min(max(calendar.component(.month, from: value) - 1, 0), 11)
    case .year:
      return min(
        max(calendar.component(.year, from: value) - minimumYear, 0), maximumYear - minimumYear)
    }
  }

  func label(for component: RufletDateWheelComponent, row: Int, value: Date) -> String {
    switch component {
    case .day:
      let day = row + 1
      guard showDayOfWeek,
        let date = replacing(component: .day, row: row, in: value)
      else { return String(day) }
      let formatter = DateFormatter()
      formatter.locale = locale
      formatter.calendar = calendar
      formatter.setLocalizedDateFormatFromTemplate("EEE")
      return "\(formatter.string(from: date)) \(day)"
    case .month:
      let formatter = DateFormatter()
      formatter.locale = locale
      let names = formatter.standaloneMonthSymbols ?? formatter.monthSymbols ?? []
      return names.indices.contains(row) ? names[row] : String(row + 1)
    case .year:
      return String(minimumYear + row)
    }
  }

  func replacing(
    component: RufletDateWheelComponent,
    row: Int,
    in value: Date
  ) -> Date? {
    var values = calendar.dateComponents(
      [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond],
      from: value)
    switch component {
    case .day: values.day = row + 1
    case .month: values.month = row + 1
    case .year: values.year = minimumYear + row
    }
    let year = min(max(values.year ?? minimumYear, minimumYear), maximumYear)
    let month = min(max(values.month ?? 1, 1), 12)
    values.year = year
    values.month = month
    values.day = min(
      max(values.day ?? 1, 1),
      daysInMonth(year: year, month: month))
    guard let proposed = calendar.date(from: values) else { return nil }
    if let minimumDate, proposed < minimumDate { return minimumDate }
    if let maximumDate, proposed > maximumDate { return maximumDate }
    return proposed
  }

  private func daysInMonth(year: Int, month: Int) -> Int {
    var values = DateComponents()
    values.calendar = calendar
    values.year = year
    values.month = month
    values.day = 1
    guard let date = calendar.date(from: values) else { return 31 }
    return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
  }

  private static func localizedDateOrder(locale: Locale) -> RufletDatePickerDateOrder {
    let format =
      DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? "M/d/y"
    let positions = [
      ("y", format.firstIndex(where: { $0 == "y" || $0 == "Y" })),
      ("m", format.firstIndex(where: { $0 == "M" || $0 == "L" })),
      ("d", format.firstIndex(where: { $0 == "d" || $0 == "D" })),
    ]
    let ordered = positions.compactMap { key, index in index.map { (key, $0) } }
      .sorted { $0.1 < $1.1 }.map(\.0).joined()
    return RufletDatePickerDateOrder(rawValue: ordered) ?? .mdy
  }
}

struct RufletCupertinoDateWheel: View {
  let value: Date
  let configuration: RufletCupertinoDateWheelConfiguration
  let onChange: (Date) -> Void

  var body: some View {
    #if os(iOS)
      RufletNativeCupertinoDateWheel(
        value: value,
        configuration: configuration,
        onChange: onChange)
    #elseif os(macOS)
      RufletDesktopCupertinoDateWheel(
        value: value,
        configuration: configuration,
        onChange: onChange)
    #endif
  }
}

#if os(iOS)
  import UIKit

  private struct RufletNativeCupertinoDateWheel: UIViewRepresentable {
    let value: Date
    let configuration: RufletCupertinoDateWheelConfiguration
    let onChange: (Date) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIPickerView {
      let picker = UIPickerView()
      picker.dataSource = context.coordinator
      picker.delegate = context.coordinator
      picker.backgroundColor = .clear
      context.coordinator.install(parent: self, in: picker, reload: true)
      return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
      context.coordinator.install(parent: self, in: picker, reload: false)
    }

    @MainActor
    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
      private var parent: RufletNativeCupertinoDateWheel
      private var signature = ""

      init(parent: RufletNativeCupertinoDateWheel) { self.parent = parent }

      func install(
        parent: RufletNativeCupertinoDateWheel,
        in picker: UIPickerView,
        reload: Bool
      ) {
        self.parent = parent
        let nextSignature =
          "\(parent.configuration.components)-\(parent.configuration.minimumYear)-\(parent.configuration.maximumYear)-\(parent.configuration.showDayOfWeek)"
        if reload || nextSignature != signature {
          signature = nextSignature
          picker.reloadAllComponents()
        }
        synchronize(picker)
      }

      func numberOfComponents(in pickerView: UIPickerView) -> Int {
        parent.configuration.components.count
      }

      func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        parent.configuration.rowCount(
          for: parent.configuration.components[component],
          value: parent.value)
      }

      func pickerView(
        _ pickerView: UIPickerView,
        rowHeightForComponent component: Int
      ) -> CGFloat { parent.configuration.itemExtent }

      func pickerView(
        _ pickerView: UIPickerView,
        titleForRow row: Int,
        forComponent component: Int
      ) -> String? {
        parent.configuration.label(
          for: parent.configuration.components[component],
          row: row,
          value: parent.value)
      }

      func pickerView(
        _ pickerView: UIPickerView,
        didSelectRow row: Int,
        inComponent component: Int
      ) {
        guard
          let next = parent.configuration.replacing(
            component: parent.configuration.components[component],
            row: row,
            in: parent.value)
        else { return }
        parent.onChange(next)
        pickerView.reloadAllComponents()
        synchronize(pickerView, value: next)
      }

      private func synchronize(_ picker: UIPickerView, value: Date? = nil) {
        let selected = value ?? parent.value
        for (index, component) in parent.configuration.components.enumerated() {
          let row = parent.configuration.selectedRow(for: component, value: selected)
          if picker.selectedRow(inComponent: index) != row {
            picker.selectRow(row, inComponent: index, animated: false)
          }
        }
      }
    }
  }
#endif

#if os(macOS)
  private struct RufletDesktopCupertinoDateWheel: View {
    let value: Date
    let configuration: RufletCupertinoDateWheelConfiguration
    let onChange: (Date) -> Void

    var body: some View {
      HStack(spacing: 0) {
        ForEach(Array(configuration.components.enumerated()), id: \.offset) { _, component in
          column(component)
        }
      }
    }

    private func column(_ component: RufletDateWheelComponent) -> some View {
      let selected = configuration.selectedRow(for: component, value: value)
      let count = configuration.rowCount(for: component, value: value)
      return VStack(spacing: 0) {
        ForEach((-2...2), id: \.self) { offset in
          let row = min(max(selected + offset, 0), max(count - 1, 0))
          Button {
            select(component, row: row)
          } label: {
            Text(configuration.label(for: component, row: row, value: value))
              .foregroundStyle(offset == 0 ? .primary : .secondary)
              .opacity(offset == 0 ? 1 : 0.7)
              .frame(maxWidth: .infinity)
              .frame(height: configuration.itemExtent)
          }
          .buttonStyle(.plain)
        }
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 8).onEnded { gesture in
          let steps = max(1, Int(abs(gesture.translation.height) / configuration.itemExtent))
          select(component, row: selected + (gesture.translation.height < 0 ? steps : -steps))
        })
    }

    private func select(_ component: RufletDateWheelComponent, row: Int) {
      let count = configuration.rowCount(for: component, value: value)
      let valid = min(max(row, 0), max(count - 1, 0))
      if let next = configuration.replacing(component: component, row: valid, in: value) {
        onChange(next)
      }
    }
  }
#endif
