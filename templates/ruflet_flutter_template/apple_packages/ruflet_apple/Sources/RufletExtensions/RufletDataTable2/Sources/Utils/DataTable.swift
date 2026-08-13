import RufletEngine
import RufletProtocol
import SwiftUI

enum RufletDataColumnSize: String, Sendable {
  case small = "s"
  case medium = "m"
  case large = "l"

  init(_ raw: String?) {
    switch raw?.lowercased() {
    case "m", "medium": self = .medium
    case "l", "large": self = .large
    default: self = .small
    }
  }
}

struct RufletTableBorderSide {
  let color: Color
  let width: Double

  init?(_ value: RufletValue?) {
    guard let map = value?.map else { return nil }
    color = parseColor(map["color"]?.text, .secondary.opacity(0.35)) ?? .secondary.opacity(0.35)
    width = map["width"]?.number ?? 1
  }
}

func rufletTableColor(_ value: RufletValue?, default fallback: Color = .clear) -> Color {
  if let text = value?.text { return parseColor(text, fallback) ?? fallback }
  guard let map = value?.map else { return fallback }
  let raw = map["default"]?.text ?? map[""]?.text ?? map["any"]?.text
  return parseColor(raw, fallback) ?? fallback
}

@MainActor
func rufletDataColumnWidth(
  _ column: RufletControl,
  minWidth: Double,
  smallRatio: Double,
  largeRatio: Double
) -> Double {
  if let fixed = column.number("fixed_width") { return fixed }
  let base = max(minWidth, 90)
  switch RufletDataColumnSize(column.string("size")) {
  case .small: return base * smallRatio
  case .medium: return base
  case .large: return base * largeRatio
  }
}

struct RufletTableBackground: View {
  let control: RufletControl

  var body: some View {
    if let gradient = control.value("gradient")?.map,
       let colors = gradient["colors"]?.array?.compactMap({ parseColor($0.text) }),
       !colors.isEmpty
    {
      LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    } else {
      parseColor(control.string("bgcolor"), .clear) ?? .clear
    }
  }
}
