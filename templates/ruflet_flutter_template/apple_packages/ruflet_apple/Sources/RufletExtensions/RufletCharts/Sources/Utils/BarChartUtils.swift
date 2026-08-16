import RufletEngine
import RufletProtocol
import SwiftUI

struct BarChartRod: Identifiable {
  let id: Int
  let fromY: Double
  let toY: Double
  let width: Double
  let color: Color
  let gradient: ChartGradient?
  let borderRadius: CGFloat
  let borderSide: RufletBorderSide?
  let stackItems: [BarChartRodStackItem]
  let selected: Bool
}

struct BarChartRodStackItem: Identifiable {
  let id: Int
  let fromY: Double
  let toY: Double
  let color: Color
  let borderSide: RufletBorderSide?

  @MainActor static func parse(_ control: RufletControl, index: Int) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      fromY: control.number("from_y", default: 0) ?? 0,
      toY: control.number("to_y", default: 0) ?? 0,
      color: control.chartColor("color", default: ChartPalette.defaults[index % ChartPalette.defaults.count]),
      borderSide: parseBorderSide(control.value("border_side"), defaultValue: nil))
  }
}

struct BarChartGroup: Identifiable {
  let id: Int
  let x: Int
  let spacing: Double
  let groupVertically: Bool
  let rods: [BarChartRod]

  @MainActor static func parse(_ control: RufletControl, paletteIndex: Int) -> Self {
    control.notifyParent = true
    let selectedIndices = Set(
      control.value("showing_tooltip_indicators")?.array?.compactMap(\.integer) ?? [])
    let rods = control.children("rods").enumerated().map { index, rod in
      rod.notifyParent = true
      let radius = parseBorderRadius(rod.value("border_radius"))
      let pinnedStackItems = rod.children("stack_items")
      let stackItems = pinnedStackItems.isEmpty
        ? rod.children("rod_stack_items")
        : pinnedStackItems
      return BarChartRod(
        id: rod.id,
        fromY: rod.number("from_y", default: 0) ?? 0,
        toY: rod.number("to_y", default: 0) ?? 0,
        width: rod.number("width", default: 8) ?? 8,
        color: rod.chartColor("color", default: ChartPalette.defaults[(paletteIndex + index) % ChartPalette.defaults.count]),
        gradient: ChartGradient.parse(rod.value("gradient")),
        borderRadius: CGFloat(max(
          radius?.topLeft ?? 0, radius?.topRight ?? 0,
          radius?.bottomLeft ?? 0, radius?.bottomRight ?? 0)),
        borderSide: parseBorderSide(rod.value("border_side"), defaultValue: nil),
        stackItems: stackItems.enumerated().map {
          BarChartRodStackItem.parse($0.element, index: $0.offset)
        },
        selected: selectedIndices.contains(index) || rod.boolean("selected", default: false))
    }
    return Self(
      id: control.id,
      x: control.integer("x", default: paletteIndex) ?? paletteIndex,
      spacing: control.number("spacing") ?? control.number("bars_space") ?? 2,
      groupVertically: control.boolean("group_vertically", default: false),
      rods: rods)
  }
}

struct BarChartEventData: Equatable {
  let eventType: String
  let groupIndex: Int?
  let rodIndex: Int?
  let stackItemIndex: Int?

  var value: [String: RufletValue] {
    [
      "type": .string(eventType),
      "group_index": groupIndex.map { .int(Int64($0)) } ?? .null,
      "rod_index": rodIndex.map { .int(Int64($0)) } ?? .null,
      "stack_item_index": stackItemIndex.map { .int(Int64($0)) } ?? .null,
    ]
  }
}
