import RufletEngine
import RufletProtocol
import SwiftUI

enum RadarShape: String {
  case polygon
  case circle
}

struct RadarDataSet: Identifiable {
  let id: Int
  let entries: [Double]
  let fillColor: Color
  let fillGradient: ChartGradient?
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
      fillColor: control.chartColor("fill_color", default: .cyan),
      fillGradient: ChartGradient.parse(control.value("fill_gradient")),
      borderColor: control.chartColor("border_color", default: .cyan),
      borderWidth: control.number("border_width", default: 2) ?? 2,
      entryRadius: control.number("entry_radius", default: 5) ?? 5)
  }
}

struct RadarStroke {
  let color: Color
  let width: CGFloat

  static func parse(
    _ value: RufletValue?,
    defaultColor: Color = .primary,
    defaultWidth: CGFloat = 2
  ) -> Self {
    let map = value?.map ?? [:]
    return Self(
      color: ChartPalette.color(map["color"]?.text, default: defaultColor),
      width: CGFloat(max(0, map["width"]?.number ?? Double(defaultWidth))))
  }
}

struct RadarChartConfiguration {
  let shape: RadarShape
  let radarBackgroundColor: Color
  let radarBorder: RadarStroke
  let gridBorder: RadarStroke
  let tickBorder: RadarStroke
  let chartBorder: RufletBorder?
  let titleStyle: RufletTextStyle?
  let tickStyle: RufletTextStyle?
  let titlePositionPercentageOffset: Double
  let tickCount: Int
  let centerMinimumValue: Bool
  let touchSpotThreshold: CGFloat
  let interactive: Bool

  @MainActor
  init(control: RufletControl) {
    shape = RadarShape(rawValue: control.string("radar_shape")?.lowercased() ?? "") ?? .polygon
    radarBackgroundColor = control.chartColor("radar_bgcolor", default: .clear)
    radarBorder = RadarStroke.parse(control.value("radar_border_side"))
    gridBorder = RadarStroke.parse(control.value("grid_border_side"))
    tickBorder = RadarStroke.parse(control.value("tick_border_side"))
    chartBorder = parseBorder(control.value("border"))
    titleStyle = parseTextStyle(control.value("title_text_style"))
    tickStyle = parseTextStyle(control.value("ticks_text_style"))
    titlePositionPercentageOffset =
      control.number("title_position_percentage_offset", default: 0.2) ?? 0.2
    tickCount = control.integer("tick_count", default: 1) ?? 1
    centerMinimumValue = control.boolean("center_min_value", default: false)
    touchSpotThreshold = CGFloat(control.number("touch_spot_threshold", default: 10) ?? 10)
    interactive = control.boolean("interactive", default: true) && !control.disabled
    precondition(
      (0...1).contains(titlePositionPercentageOffset),
      "RadarChart.title_position_percentage_offset must be between zero and one")
    precondition(tickCount >= 1, "RadarChart.tick_count must be at least one")
  }
}

struct RadarChartLayout {
  struct Tick: Equatable {
    let radius: CGFloat
    let value: Double
  }

  struct Hit: Equatable {
    let dataSetIndex: Int
    let entryIndex: Int
    let entryValue: Double
  }

  let size: CGSize
  let count: Int
  let center: CGPoint
  let radius: CGFloat
  let minimum: Double
  let maximum: Double
  let centerValue: Double
  let ticks: [Tick]

  init(size: CGSize, dataSets: [RadarDataSet], configuration: RadarChartConfiguration) {
    self.size = size
    let counts = Set(dataSets.map(\.entries.count))
    precondition(counts.count <= 1, "RadarChart data sets must have equal entry counts")
    count = counts.first ?? 0
    precondition(
      count == 0 || count >= 3, "RadarChart data sets require zero or at least three entries")
    center = CGPoint(x: size.width / 2, y: size.height / 2)
    radius = max(0, min(size.width, size.height) * 0.4)
    let values = dataSets.flatMap(\.entries)
    minimum = values.min() ?? 0
    maximum = values.max() ?? 0
    let tickSpace: Double
    if configuration.centerMinimumValue {
      tickSpace = (maximum - minimum) / Double(configuration.tickCount)
      centerValue = minimum
    } else if maximum == minimum {
      tickSpace = (maximum - 0) / Double(configuration.tickCount + 1)
      centerValue = 0
    } else {
      tickSpace = (maximum - minimum) / Double(configuration.tickCount)
      centerValue = minimum - tickSpace
    }
    let firstTick =
      configuration.centerMinimumValue
      ? 0
      : (maximum == minimum ? tickSpace : minimum)
    let tickDistance =
      configuration.centerMinimumValue
      ? radius / CGFloat(configuration.tickCount)
      : radius / CGFloat(configuration.tickCount + 1)
    ticks = (0..<configuration.tickCount).map { index in
      Tick(
        radius: tickDistance * CGFloat(index + (configuration.centerMinimumValue ? 0 : 1)),
        value: firstTick + Double(index) * tickSpace)
    }
  }

  func scaledRadius(for value: Double) -> CGFloat {
    let denominator = maximum - centerValue
    return radius * CGFloat((value - centerValue) / (denominator == 0 ? 0.001 : denominator))
  }

  func vertex(index: Int, radius: CGFloat) -> CGPoint {
    let angle = CGFloat(index) / CGFloat(count) * 2 * .pi - .pi / 2
    return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
  }

  func hitTest(
    _ location: CGPoint,
    dataSets: [RadarDataSet],
    threshold: CGFloat
  ) -> Hit? {
    for (dataSetIndex, dataSet) in dataSets.enumerated() {
      for (entryIndex, value) in dataSet.entries.enumerated() {
        let point = vertex(index: entryIndex, radius: scaledRadius(for: value))
        if abs(location.x - point.x) <= threshold, abs(location.y - point.y) <= threshold {
          return Hit(
            dataSetIndex: dataSetIndex,
            entryIndex: entryIndex,
            entryValue: value)
        }
      }
    }
    return nil
  }
}

struct RadarChartTitleConfiguration: Identifiable, Equatable {
  let id: Int
  let text: String
  let angle: Double
  let positionPercentageOffset: Double

  @MainActor
  static func parse(
    _ control: RufletControl,
    defaultAngle: Double,
    defaultPositionPercentageOffset: Double
  ) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      text: control.string("text", default: "") ?? "",
      angle: control.number("angle") ?? defaultAngle,
      positionPercentageOffset: control.number("position_percentage_offset")
        ?? defaultPositionPercentageOffset)
  }

  func position(
    index: Int,
    count: Int,
    radius: CGFloat,
    center: CGPoint,
    textHeight: CGFloat
  ) -> CGPoint {
    let axisAngle = CGFloat(index) / CGFloat(count) * 2 * .pi - .pi / 2
    let distance = radius * (1 + CGFloat(positionPercentageOffset)) + textHeight / 2
    return CGPoint(
      x: center.x + cos(axisAngle) * distance,
      y: center.y + sin(axisAngle) * distance)
  }
}
