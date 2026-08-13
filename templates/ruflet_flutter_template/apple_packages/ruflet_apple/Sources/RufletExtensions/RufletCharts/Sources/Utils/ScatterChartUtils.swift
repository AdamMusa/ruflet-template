import RufletEngine
import SwiftUI

struct ScatterChartSpot: Identifiable {
  let id: Int
  let x: Double
  let y: Double
  let radius: Double
  let color: Color
  let selected: Bool
  let label: String?

  @MainActor static func parse(_ control: RufletControl, index: Int) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      x: control.number("x", default: 0) ?? 0,
      y: control.number("y", default: 0) ?? 0,
      radius: control.number("radius", default: 4) ?? 4,
      color: control.chartColor("color", default: ChartPalette.defaults[index % ChartPalette.defaults.count]),
      selected: control.boolean("selected", default: false),
      label: control.string("label_text"))
  }
}

struct ScatterChartEventData: Equatable {
  let eventType: String
  let spotIndex: Int?
}
