import RufletEngine
import RufletProtocol
import SwiftUI

struct BarChartRod: Identifiable {
  let id: Int
  let fromY: Double
  let toY: Double
  let width: Double
  let color: Color
  let selected: Bool
}

struct BarChartGroup: Identifiable {
  let id: Int
  let x: Int
  let spacing: Double
  let groupVertically: Bool
  let rods: [BarChartRod]

  @MainActor static func parse(_ control: RufletControl, paletteIndex: Int) -> Self {
    control.notifyParent = true
    let rods = control.children("rods").enumerated().map { index, rod in
      rod.notifyParent = true
      return BarChartRod(
        id: rod.id,
        fromY: rod.number("from_y", default: 0) ?? 0,
        toY: rod.number("to_y", default: 0) ?? 0,
        width: rod.number("width", default: 8) ?? 8,
        color: rod.chartColor("color", default: ChartPalette.defaults[(paletteIndex + index) % ChartPalette.defaults.count]),
        selected: rod.boolean("selected", default: false))
    }
    return Self(
      id: control.id,
      x: control.integer("x", default: paletteIndex) ?? paletteIndex,
      spacing: control.number("spacing", default: 2) ?? 2,
      groupVertically: control.boolean("group_vertically", default: false),
      rods: rods)
  }
}

struct BarChartEventData: Equatable {
  let eventType: String
  let groupIndex: Int?
  let rodIndex: Int?

  var value: [String: RufletValue] {
    [
      "type": .string(eventType),
      "group_index": groupIndex.map { .int(Int64($0)) } ?? .null,
      "rod_index": rodIndex.map { .int(Int64($0)) } ?? .null,
    ]
  }
}
