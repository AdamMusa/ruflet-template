import RufletEngine
import SwiftUI

struct LineChartSeries: Identifiable {
  let id: Int
  let points: [LineChartPoint]
  let color: Color
  let gradient: ChartGradient?
  let strokeWidth: Double
  let curved: Bool
  let roundedStrokeCap: Bool
  let dashPattern: [Double]

  @MainActor static func parse(_ control: RufletControl, index: Int) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      points: control.children("points").map(LineChartPoint.parse),
      color: control.chartColor("color", default: ChartPalette.defaults[index % ChartPalette.defaults.count]),
      gradient: ChartGradient.parse(control.value("gradient")),
      strokeWidth: control.number("stroke_width", default: 2) ?? 2,
      curved: control.boolean("curved", default: false),
      roundedStrokeCap: control.boolean("rounded_stroke_cap", default: false),
      dashPattern: control.value("dash_pattern")?.array?.compactMap(\.number) ?? [])
  }
}

struct LineChartPoint: Identifiable {
  let id: Int
  let x: Double
  let y: Double
  let selected: Bool
  let showAboveLine: Bool
  let showBelowLine: Bool

  @MainActor static func parse(_ control: RufletControl) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      x: control.number("x", default: 0) ?? 0,
      y: control.number("y", default: 0) ?? 0,
      selected: control.boolean("selected", default: false),
      showAboveLine: control.boolean("show_above_line", default: true),
      showBelowLine: control.boolean("show_below_line", default: true))
  }
}
