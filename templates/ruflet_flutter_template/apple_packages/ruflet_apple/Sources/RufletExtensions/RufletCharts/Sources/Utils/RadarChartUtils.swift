import RufletEngine
import SwiftUI

enum RadarShape: String {
  case polygon
  case circle
}

struct RadarDataSet: Identifiable {
  let id: Int
  let entries: [Double]
  let fillColor: Color
  let borderColor: Color
  let borderWidth: Double
  let entryRadius: Double

  @MainActor static func parse(_ control: RufletControl, index: Int) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      entries: control.children("entries").map {
        $0.notifyParent = true
        return $0.number("value", default: 0) ?? 0
      },
      fillColor: control.chartColor("fill_color", default: ChartPalette.defaults[index % ChartPalette.defaults.count].opacity(0.25)),
      borderColor: control.chartColor("border_color", default: ChartPalette.defaults[index % ChartPalette.defaults.count]),
      borderWidth: control.number("border_width", default: 2) ?? 2,
      entryRadius: control.number("entry_radius", default: 5) ?? 5)
  }
}

struct RadarChartEventData: Equatable {
  let eventType: String
  let dataSetIndex: Int?
  let entryIndex: Int?
  let entryValue: Double?
}
