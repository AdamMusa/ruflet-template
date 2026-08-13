import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

struct ChartPoint: Equatable, Sendable {
  var x: Double
  var y: Double
}

struct ChartDomain: Equatable, Sendable {
  var minX: Double
  var maxX: Double
  var minY: Double
  var maxY: Double

  @MainActor init(points: [ChartPoint], control: RufletControl) {
    let xValues = points.map(\.x)
    let yValues = points.map(\.y)
    minX = control.number("min_x") ?? xValues.min() ?? 0
    maxX = control.number("max_x") ?? xValues.max() ?? 1
    minY = control.number("min_y") ?? yValues.min() ?? 0
    maxY = control.number("max_y") ?? yValues.max() ?? 1
    if minX == maxX { maxX = minX + 1 }
    if minY == maxY { maxY = minY + 1 }
  }

  func location(_ point: ChartPoint, in size: CGSize, inset: CGFloat = 16) -> CGPoint {
    let width = max(1, size.width - inset * 2)
    let height = max(1, size.height - inset * 2)
    let x = inset + CGFloat((point.x - minX) / (maxX - minX)) * width
    let y = size.height - inset - CGFloat((point.y - minY) / (maxY - minY)) * height
    return CGPoint(x: x, y: y)
  }

  func location(_ point: ChartPoint, in rect: CGRect) -> CGPoint {
    let width = max(1, rect.width)
    let height = max(1, rect.height)
    return CGPoint(
      x: rect.minX + CGFloat((point.x - minX) / (maxX - minX)) * width,
      y: rect.maxY - CGFloat((point.y - minY) / (maxY - minY)) * height)
  }
}

struct ChartAxisLabel: Identifiable {
  let id: Int
  let value: Double
  let control: RufletControl

  @MainActor static func parse(_ control: RufletControl) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      value: control.number("value", default: 0) ?? 0,
      control: control)
  }
}

struct ChartAxisConfiguration {
  let title: RufletControl?
  let labels: [ChartAxisLabel]
  let showLabels: Bool
  let labelSize: CGFloat
  let labelSpacing: Double?
  let showMinimum: Bool
  let showMaximum: Bool
  let titleSize: CGFloat

  @MainActor static func parse(_ control: RufletControl?) -> Self? {
    guard let control else { return nil }
    control.notifyParent = true
    let title = control.child("title", visibleOnly: false)
    title?.notifyParent = true
    let labels = control.children("labels", visibleOnly: false).map(ChartAxisLabel.parse)
    return Self(
      title: title,
      labels: labels,
      showLabels: control.boolean("show_labels", default: true),
      labelSize: CGFloat(max(0, control.number("label_size", default: 22) ?? 22)),
      labelSpacing: control.number("label_spacing"),
      showMinimum: control.boolean("show_min", default: true),
      showMaximum: control.boolean("show_max", default: true),
      titleSize: CGFloat(max(0, control.number("title_size", default: 16) ?? 16)))
  }

  var reservedSize: CGFloat {
    (showLabels ? labelSize : 0) + (title == nil ? 0 : titleSize)
  }
}

struct ChartAxes {
  let left: ChartAxisConfiguration?
  let top: ChartAxisConfiguration?
  let right: ChartAxisConfiguration?
  let bottom: ChartAxisConfiguration?

  @MainActor init(control: RufletControl) {
    left = ChartAxisConfiguration.parse(control.child("left_axis"))
    top = ChartAxisConfiguration.parse(control.child("top_axis"))
    right = ChartAxisConfiguration.parse(control.child("right_axis"))
    bottom = ChartAxisConfiguration.parse(control.child("bottom_axis"))
  }
}

struct ChartLineConfiguration {
  let interval: Double?
  let color: Color
  let width: CGFloat
  let dash: [CGFloat]

  static func parse(_ value: RufletValue?) -> Self? {
    guard let value else { return nil }
    let map = value.map ?? [:]
    return Self(
      interval: map["interval"]?.number,
      color: ChartPalette.color(map["color"]?.text, default: .secondary.opacity(0.28)),
      width: CGFloat(max(0, map["width"]?.number ?? 1)),
      dash: map["dash_pattern"]?.array?.compactMap(\.number).map { CGFloat($0) } ?? [])
  }
}

struct ChartGridConfiguration {
  let horizontal: ChartLineConfiguration?
  let vertical: ChartLineConfiguration?

  static func parse(horizontal: RufletValue?, vertical: RufletValue?) -> Self {
    Self(
      horizontal: ChartLineConfiguration.parse(horizontal),
      vertical: ChartLineConfiguration.parse(vertical))
  }
}

struct ChartGradient {
  let gradient: Gradient

  static func parse(_ value: RufletValue?) -> Self? {
    guard let colors = value?.map?["colors"]?.array?.compactMap(\.text), colors.count > 1 else {
      return nil
    }
    let parsed = colors.enumerated().map { index, color in
      ChartPalette.color(color, default: ChartPalette.defaults[index % ChartPalette.defaults.count])
    }
    let stops = value?.map?["stops"]?.array?.compactMap(\.number) ?? []
    if stops.count == parsed.count {
      return Self(gradient: Gradient(stops: zip(parsed, stops).map {
        .init(color: $0.0, location: $0.1)
      }))
    }
    return Self(gradient: Gradient(colors: parsed))
  }

  func shading(from start: CGPoint, to end: CGPoint) -> GraphicsContext.Shading {
    .linearGradient(gradient, startPoint: start, endPoint: end)
  }
}

struct ChartCartesianConfiguration {
  let axes: ChartAxes
  let grid: ChartGridConfiguration
  let border: RufletBorder?

  @MainActor init(control: RufletControl) {
    axes = ChartAxes(control: control)
    grid = ChartGridConfiguration.parse(
      horizontal: control.value("horizontal_grid_lines"),
      vertical: control.value("vertical_grid_lines"))
    border = parseBorder(control.value("border"))
  }
}

struct ChartCartesianLayout {
  let size: CGSize
  let plotRect: CGRect

  init(size: CGSize, axes: ChartAxes) {
    self.size = size
    let left = axes.left?.reservedSize ?? 0
    let top = axes.top?.reservedSize ?? 0
    let right = axes.right?.reservedSize ?? 0
    let bottom = axes.bottom?.reservedSize ?? 0
    plotRect = CGRect(
      x: min(left, max(0, size.width - 1)),
      y: min(top, max(0, size.height - 1)),
      width: max(1, size.width - left - right),
      height: max(1, size.height - top - bottom))
  }

  func location(_ point: ChartPoint, domain: ChartDomain) -> CGPoint {
    domain.location(point, in: plotRect)
  }
}

func drawCartesianDecoration(
  context: inout GraphicsContext,
  layout: ChartCartesianLayout,
  domain: ChartDomain,
  configuration: ChartCartesianConfiguration
) {
  if let horizontal = configuration.grid.horizontal {
    for value in chartTicks(min: domain.minY, max: domain.maxY, interval: horizontal.interval) {
      let y = layout.location(ChartPoint(x: domain.minX, y: value), domain: domain).y
      var path = Path()
      path.move(to: CGPoint(x: layout.plotRect.minX, y: y))
      path.addLine(to: CGPoint(x: layout.plotRect.maxX, y: y))
      context.stroke(path, with: .color(horizontal.color), style: StrokeStyle(
        lineWidth: horizontal.width, dash: horizontal.dash))
    }
  }
  if let vertical = configuration.grid.vertical {
    for value in chartTicks(min: domain.minX, max: domain.maxX, interval: vertical.interval) {
      let x = layout.location(ChartPoint(x: value, y: domain.minY), domain: domain).x
      var path = Path()
      path.move(to: CGPoint(x: x, y: layout.plotRect.minY))
      path.addLine(to: CGPoint(x: x, y: layout.plotRect.maxY))
      context.stroke(path, with: .color(vertical.color), style: StrokeStyle(
        lineWidth: vertical.width, dash: vertical.dash))
    }
  }
  if let border = configuration.border {
    drawBorderSide(border.left, from: CGPoint(x: layout.plotRect.minX, y: layout.plotRect.minY),
      to: CGPoint(x: layout.plotRect.minX, y: layout.plotRect.maxY), context: &context)
    drawBorderSide(border.top, from: CGPoint(x: layout.plotRect.minX, y: layout.plotRect.minY),
      to: CGPoint(x: layout.plotRect.maxX, y: layout.plotRect.minY), context: &context)
    drawBorderSide(border.right, from: CGPoint(x: layout.plotRect.maxX, y: layout.plotRect.minY),
      to: CGPoint(x: layout.plotRect.maxX, y: layout.plotRect.maxY), context: &context)
    drawBorderSide(border.bottom, from: CGPoint(x: layout.plotRect.minX, y: layout.plotRect.maxY),
      to: CGPoint(x: layout.plotRect.maxX, y: layout.plotRect.maxY), context: &context)
  }
}

private func drawBorderSide(
  _ side: RufletBorderSide?, from start: CGPoint, to end: CGPoint,
  context: inout GraphicsContext
) {
  guard let side, side.width > 0 else { return }
  var path = Path()
  path.move(to: start)
  path.addLine(to: end)
  context.stroke(path, with: .color(side.color), lineWidth: CGFloat(side.width))
}

func chartTicks(min minimum: Double, max maximum: Double, interval: Double?) -> [Double] {
  guard maximum > minimum else { return [minimum] }
  let step = interval.flatMap { $0 > 0 ? $0 : nil } ?? (maximum - minimum) / 4
  guard step.isFinite, step > 0 else { return [minimum, maximum] }
  var value = ceil(minimum / step) * step
  var result: [Double] = []
  while value <= maximum + step * 0.000_001, result.count < 1_000 {
    result.append(value)
    value += step
  }
  return result
}

@MainActor
struct ChartAxesOverlay: View {
  let axes: ChartAxes
  let domain: ChartDomain
  let layout: ChartCartesianLayout

  var body: some View {
    ZStack {
      axis(axes.left, side: .left)
      axis(axes.top, side: .top)
      axis(axes.right, side: .right)
      axis(axes.bottom, side: .bottom)
    }
    .allowsHitTesting(false)
  }

  @ViewBuilder
  private func axis(_ axis: ChartAxisConfiguration?, side: ChartSide) -> some View {
    if let axis {
      if let title = axis.title {
        ControlWidget(control: title)
          .frame(width: side.isVertical ? axis.titleSize : layout.plotRect.width,
            height: side.isVertical ? layout.plotRect.height : axis.titleSize)
          .rotationEffect(side == .left ? .degrees(-90) : side == .right ? .degrees(90) : .zero)
          .position(titlePosition(side: side, axis: axis))
      }
      if axis.showLabels {
        ForEach(labels(for: axis, side: side)) { label in
          label.view
            .frame(width: side.isVertical ? axis.labelSize : nil,
              height: side.isVertical ? nil : axis.labelSize)
            .position(label.position)
        }
      }
    }
  }

  private func labels(for axis: ChartAxisConfiguration, side: ChartSide) -> [ChartPositionedLabel] {
    let values = axis.labels.isEmpty
      ? chartTicks(
        min: side.isVertical ? domain.minY : domain.minX,
        max: side.isVertical ? domain.maxY : domain.maxX,
        interval: axis.labelSpacing).enumerated().map { index, value in
          ChartPositionedLabel.Source.text(index: index, value: value, text: chartNumber(value))
        }
      : axis.labels.enumerated().map { index, label in
          ChartPositionedLabel.Source.control(index: index, label: label)
        }

    return values.compactMap { source in
      let value = source.value
      let minimum = side.isVertical ? domain.minY : domain.minX
      let maximum = side.isVertical ? domain.maxY : domain.maxX
      guard value >= minimum, value <= maximum else { return nil }
      if !axis.showMinimum, abs(value - minimum) < 0.000_001 { return nil }
      if !axis.showMaximum, abs(value - maximum) < 0.000_001 { return nil }
      let plotPoint = layout.location(ChartPoint(x: value, y: value), domain: domain)
      let position: CGPoint
      switch side {
      case .left:
        position = CGPoint(x: layout.plotRect.minX - axis.labelSize / 2, y: plotPoint.y)
      case .right:
        position = CGPoint(x: layout.plotRect.maxX + axis.labelSize / 2, y: plotPoint.y)
      case .top:
        position = CGPoint(x: plotPoint.x, y: layout.plotRect.minY - axis.labelSize / 2)
      case .bottom:
        position = CGPoint(x: plotPoint.x, y: layout.plotRect.maxY + axis.labelSize / 2)
      }
      return ChartPositionedLabel(id: source.id, position: position, view: source.view)
    }
  }

  private func titlePosition(side: ChartSide, axis: ChartAxisConfiguration) -> CGPoint {
    switch side {
    case .left: CGPoint(x: axis.titleSize / 2, y: layout.plotRect.midY)
    case .right: CGPoint(x: layout.size.width - axis.titleSize / 2, y: layout.plotRect.midY)
    case .top: CGPoint(x: layout.plotRect.midX, y: axis.titleSize / 2)
    case .bottom: CGPoint(x: layout.plotRect.midX, y: layout.size.height - axis.titleSize / 2)
    }
  }
}

private enum ChartSide { case left, top, right, bottom
  var isVertical: Bool { self == .left || self == .right }
}

@MainActor
private struct ChartPositionedLabel: Identifiable {
  enum Source {
    case text(index: Int, value: Double, text: String)
    case control(index: Int, label: ChartAxisLabel)

    var id: Int {
      switch self {
      case .text(let index, _, _): index
      case .control(_, let label): label.id
      }
    }
    var value: Double {
      switch self {
      case .text(_, let value, _): value
      case .control(_, let label): label.value
      }
    }
    @MainActor var view: AnyView {
      switch self {
      case .text(_, _, let text): AnyView(Text(text).font(.caption2))
      case .control(_, let label): label.control.buildTextOrWidget("label") ?? AnyView(EmptyView())
      }
    }
  }

  let id: Int
  let position: CGPoint
  let view: AnyView
}

private func chartNumber(_ value: Double) -> String {
  value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
}

enum ChartPalette {
  static let defaults: [Color] = [
    .cyan, .blue, .orange, .green, .purple, .pink, .yellow, .teal,
  ]

  static func color(_ value: String?, default fallback: Color) -> Color {
    guard let value, !value.isEmpty else { return fallback }
    let normalized = value.lowercased().replacingOccurrences(of: "_", with: "")
    switch normalized {
    case "red": return .red
    case "pink": return .pink
    case "purple": return .purple
    case "indigo": return .indigo
    case "blue": return .blue
    case "cyan": return .cyan
    case "teal": return .teal
    case "green": return .green
    case "yellow": return .yellow
    case "orange": return .orange
    case "brown": return .brown
    case "grey", "gray": return .gray
    case "black": return .black
    case "white": return .white
    case "transparent": return .clear
    default:
      return hexColor(value) ?? fallback
    }
  }

  private static func hexColor(_ value: String) -> Color? {
    var hex = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if hex.hasPrefix("#") { hex.removeFirst() }
    if hex.lowercased().hasPrefix("0x") { hex.removeFirst(2) }
    guard let number = UInt64(hex, radix: 16) else { return nil }
    let argb: UInt64 = hex.count == 6 ? 0xff00_0000 | number : number
    guard hex.count == 6 || hex.count == 8 else { return nil }
    return Color(
      .sRGB,
      red: Double((argb >> 16) & 0xff) / 255,
      green: Double((argb >> 8) & 0xff) / 255,
      blue: Double(argb & 0xff) / 255,
      opacity: Double((argb >> 24) & 0xff) / 255)
  }
}

extension RufletControl {
  func chartColor(_ name: String, default fallback: Color) -> Color {
    ChartPalette.color(string(name), default: fallback)
  }
}

func chartEvent(type: String, location: CGPoint, fields: [String: RufletValue] = [:]) -> RufletValue {
  var result = fields
  result["type"] = .string(type)
  result["local_x"] = .double(Double(location.x))
  result["local_y"] = .double(Double(location.y))
  return .map(result)
}

struct ChartFrame<Content: View>: View {
  @ObservedObject var control: RufletControl
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .frame(maxWidth: .infinity, minHeight: 180, idealHeight: 300, maxHeight: .infinity)
      .background(control.chartColor("bgcolor", default: .clear))
      .clipped()
  }
}
