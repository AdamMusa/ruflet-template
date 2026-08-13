import RufletEngine
import SwiftUI

struct PieChartSection: Identifiable {
  let id: Int
  let value: Double
  let color: Color
  let radius: Double?
  let title: String?
  let titlePosition: Double
  let badgePosition: Double?

  @MainActor static func parse(_ control: RufletControl, index: Int) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      value: max(0, control.number("value", default: 0) ?? 0),
      color: control.chartColor("color", default: ChartPalette.defaults[index % ChartPalette.defaults.count]),
      radius: control.number("radius"),
      title: control.string("title"),
      titlePosition: control.number("title_position", default: 0.5) ?? 0.5,
      badgePosition: control.number("badge_position"))
  }
}

struct PieChartEventData: Equatable {
  let eventType: String
  let sectionIndex: Int?
}
