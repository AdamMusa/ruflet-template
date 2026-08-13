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
}

struct ChartAxisConfiguration: Equatable, Sendable {
  var showLabels: Bool
  var labelSize: Double
  var labelSpacing: Double?
  var showMinimum: Bool
  var showMaximum: Bool

  @MainActor static func parse(_ control: RufletControl?) -> Self? {
    guard let control else { return nil }
    control.notifyParent = true
    control.children("labels", visibleOnly: false).forEach { $0.notifyParent = true }
    return Self(
      showLabels: control.boolean("show_labels", default: true),
      labelSize: control.number("label_size", default: 22) ?? 22,
      labelSpacing: control.number("label_spacing"),
      showMinimum: control.boolean("show_min", default: true),
      showMaximum: control.boolean("show_max", default: true))
  }
}

struct ChartGridConfiguration: Equatable, Sendable {
  var horizontalInterval: Double?
  var verticalInterval: Double?

  static func parse(horizontal: RufletValue?, vertical: RufletValue?) -> Self? {
    guard horizontal != nil || vertical != nil else { return nil }
    return Self(
      horizontalInterval: horizontal?["interval"]?.number,
      verticalInterval: vertical?["interval"]?.number)
  }
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
