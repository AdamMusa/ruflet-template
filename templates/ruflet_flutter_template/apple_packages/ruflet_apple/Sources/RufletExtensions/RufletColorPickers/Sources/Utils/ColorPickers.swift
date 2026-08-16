import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RufletPickerColor: Equatable, Sendable {
  var red: Double
  var green: Double
  var blue: Double
  var alpha: Double

  static let black = Self(red: 0, green: 0, blue: 0, alpha: 1)

  var swiftUI: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

  var hex: String {
    let components = [alpha, red, green, blue].map { Int(($0.clamped * 255).rounded()) }
    return "#" + components.map { String(format: "%02x", $0) }.joined()
  }

  var hsv: RufletHSVColor {
    let maximum = max(red, green, blue)
    let minimum = min(red, green, blue)
    let delta = maximum - minimum
    let hue: Double
    if delta == 0 { hue = 0 }
    else if maximum == red { hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6) }
    else if maximum == green { hue = 60 * ((blue - red) / delta + 2) }
    else { hue = 60 * ((red - green) / delta + 4) }
    return RufletHSVColor(
      alpha: alpha,
      hue: hue < 0 ? hue + 360 : hue,
      saturation: maximum == 0 ? 0 : delta / maximum,
      value: maximum)
  }

  static func parse(_ raw: String?) -> Self? {
    guard let color = parseColor(raw) else { return nil }
    #if os(iOS)
    let platform = UIColor(color)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard platform.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
    #elseif os(macOS)
    guard let platform = NSColor(color).usingColorSpace(.sRGB) else { return nil }
    let red = platform.redComponent, green = platform.greenComponent
    let blue = platform.blueComponent, alpha = platform.alphaComponent
    #endif
    return Self(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
  }
}

struct RufletHSVColor: Equatable, Sendable {
  var alpha: Double
  var hue: Double
  var saturation: Double
  var value: Double

  var rgba: RufletPickerColor {
    let chroma = value * saturation
    let x = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = value - chroma
    let rgb: (Double, Double, Double)
    switch hue {
    case 0 ..< 60: rgb = (chroma, x, 0)
    case 60 ..< 120: rgb = (x, chroma, 0)
    case 120 ..< 180: rgb = (0, chroma, x)
    case 180 ..< 240: rgb = (0, x, chroma)
    case 240 ..< 300: rgb = (x, 0, chroma)
    default: rgb = (chroma, 0, x)
    }
    return RufletPickerColor(red: rgb.0 + m, green: rgb.1 + m, blue: rgb.2 + m, alpha: alpha)
  }

  var valueMap: RufletValue {
    .map([
      "alpha": .double(alpha), "hue": .double(hue),
      "saturation": .double(saturation), "value": .double(value),
    ])
  }

  static func parse(_ value: RufletValue?) -> Self? {
    guard let map = value?.map,
          let alpha = map["alpha"]?.number,
          let hue = map["hue"]?.number,
          let saturation = map["saturation"]?.number,
          let brightness = map["value"]?.number
    else { return nil }
    return Self(alpha: alpha.clamped, hue: min(max(hue, 0), 360), saturation: saturation.clamped, value: brightness.clamped)
  }
}

struct RufletHSLColor: Equatable, Sendable {
  var alpha: Double
  var hue: Double
  var saturation: Double
  var lightness: Double

  init(_ color: RufletPickerColor) {
    let maximum = max(color.red, color.green, color.blue)
    let minimum = min(color.red, color.green, color.blue)
    let delta = maximum - minimum
    lightness = (maximum + minimum) / 2
    saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
    hue = color.hsv.hue
    alpha = color.alpha
  }

  var rgba: RufletPickerColor {
    let chroma = (1 - abs(2 * lightness - 1)) * saturation
    let x = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = lightness - chroma / 2
    let rgb: (Double, Double, Double)
    switch hue {
    case 0 ..< 60: rgb = (chroma, x, 0)
    case 60 ..< 120: rgb = (x, chroma, 0)
    case 120 ..< 180: rgb = (0, chroma, x)
    case 180 ..< 240: rgb = (0, x, chroma)
    case 240 ..< 300: rgb = (x, 0, chroma)
    default: rgb = (chroma, 0, x)
    }
    return RufletPickerColor(red: rgb.0 + m, green: rgb.1 + m, blue: rgb.2 + m, alpha: alpha)
  }
}

enum RufletPaletteType: String, Sendable {
  case hsv, hsvWithHue, hsvWithValue, hsvWithSaturation, hsl, rgb
}

enum RufletColorLabelType: String, Sendable {
  case rgb, hsv, hsl, hex
}

enum RufletColorModel: String, Sendable {
  case rgb, hsv, hsl
}

func pickerColors(_ value: RufletValue?) -> [RufletPickerColor] {
  value?.array?.compactMap { RufletPickerColor.parse($0.text) } ?? []
}

let rufletDefaultPickerColors: [RufletPickerColor] = [
  "#fff44336", "#ffe91e63", "#ff9c27b0", "#ff673ab7", "#ff3f51b5",
  "#ff2196f3", "#ff03a9f4", "#ff00bcd4", "#ff009688", "#ff4caf50",
  "#ff8bc34a", "#ffcddc39", "#ffffeb3b", "#ffffc107", "#ffff9800",
  "#ffff5722", "#ff795548", "#ff9e9e9e", "#ff607d8b", "#ff000000",
].compactMap(RufletPickerColor.parse)

@MainActor
func reportPickerColor(
  control: RufletControl,
  property: String,
  event: String = "color_change",
  color: RufletPickerColor,
  update: Bool = true
) {
  if update { control.updateProperties([property: .string(color.hex)], notify: true) }
  control.triggerEvent(event, data: .string(color.hex))
}

struct RufletSaturationValueField: View {
  @Binding var hsv: RufletHSVColor
  var cornerRadius: Double = 0
  var displayThumbColor = true

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color(hue: hsv.hue / 360, saturation: 1, brightness: 1)
        LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
        Circle()
          .fill(displayThumbColor ? hsv.rgba.swiftUI : .white)
          .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
          .shadow(radius: 1)
          .frame(width: 18, height: 18)
          .position(x: hsv.saturation * proxy.size.width, y: (1 - hsv.value) * proxy.size.height)
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .contentShape(Rectangle())
      .gesture(DragGesture(minimumDistance: 0).onChanged { value in
        hsv.saturation = (value.location.x / max(proxy.size.width, 1)).clamped
        hsv.value = (1 - value.location.y / max(proxy.size.height, 1)).clamped
      })
    }
  }
}

struct RufletHueSaturationField: View {
  @Binding var hsv: RufletHSVColor
  var cornerRadius: Double = 0
  var displayThumbColor = true

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        LinearGradient(
          colors: stride(from: 0.0, through: 1.0, by: 1 / 12).map { Color(hue: $0, saturation: 1, brightness: hsv.value) },
          startPoint: .leading,
          endPoint: .trailing)
        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
        Circle().fill(displayThumbColor ? hsv.rgba.swiftUI : .white)
          .overlay(Circle().strokeBorder(Color.white, lineWidth: 2)).shadow(radius: 1)
          .frame(width: 18, height: 18)
          .position(x: hsv.hue / 360 * proxy.size.width, y: hsv.saturation * proxy.size.height)
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .contentShape(Rectangle())
      .gesture(DragGesture(minimumDistance: 0).onChanged { location in
        hsv.hue = min(max(location.location.x / max(proxy.size.width, 1) * 360, 0), 360)
        hsv.saturation = (location.location.y / max(proxy.size.height, 1)).clamped
      })
    }
  }
}

struct RufletHueValueField: View {
  @Binding var hsv: RufletHSVColor
  var cornerRadius: Double = 0
  var displayThumbColor = true

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        LinearGradient(
          colors: stride(from: 0.0, through: 1.0, by: 1 / 12).map { Color(hue: $0, saturation: hsv.saturation, brightness: 1) },
          startPoint: .leading,
          endPoint: .trailing)
        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
        Circle().fill(displayThumbColor ? hsv.rgba.swiftUI : .white)
          .overlay(Circle().strokeBorder(Color.white, lineWidth: 2)).shadow(radius: 1)
          .frame(width: 18, height: 18)
          .position(x: hsv.hue / 360 * proxy.size.width, y: (1 - hsv.value) * proxy.size.height)
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .contentShape(Rectangle())
      .gesture(DragGesture(minimumDistance: 0).onChanged { location in
        hsv.hue = min(max(location.location.x / max(proxy.size.width, 1) * 360, 0), 360)
        hsv.value = (1 - location.location.y / max(proxy.size.height, 1)).clamped
      })
    }
  }
}

struct RufletHueSlider: View {
  @Binding var hue: Double
  var displayThumbColor = true

  var body: some View {
    RufletPickerSlider(
      value: $hue,
      range: 0 ... 360,
      tint: Color(hue: hue / 360, saturation: 1, brightness: 1),
      thumbColor: displayThumbColor
        ? Color(hue: hue / 360, saturation: 1, brightness: 1) : nil)
      .background(LinearGradient(
        colors: stride(from: 0.0, through: 1.0, by: 1 / 12).map { Color(hue: $0, saturation: 1, brightness: 1) },
        startPoint: .leading,
        endPoint: .trailing).clipShape(Capsule()))
  }
}

struct RufletAlphaSlider: View {
  @Binding var alpha: Double
  let color: RufletPickerColor
  var displayThumbColor = true

  var body: some View {
    RufletPickerSlider(
      value: $alpha,
      range: 0 ... 1,
      tint: color.swiftUI,
      thumbColor: displayThumbColor ? color.swiftUI.opacity(alpha) : nil)
      .background(LinearGradient(
        colors: [color.swiftUI.opacity(0), color.swiftUI.opacity(1)],
        startPoint: .leading,
        endPoint: .trailing).clipShape(Capsule()))
  }
}

struct RufletPickerSlider: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  let tint: Color
  let thumbColor: Color?

  var body: some View {
    GeometryReader { proxy in
      let diameter = min(max(proxy.size.height * 0.7, 14), 24)
      let usableWidth = max(proxy.size.width - diameter, 1)
      let fraction = (value - range.lowerBound)
        / max(range.upperBound - range.lowerBound, .leastNonzeroMagnitude)
      ZStack(alignment: .leading) {
        Capsule().fill(tint.opacity(0.35)).frame(height: max(4, diameter * 0.28))
        Capsule().fill(tint).frame(
          width: max(diameter / 2, usableWidth * fraction),
          height: max(4, diameter * 0.28))
        Circle()
          .fill(thumbColor ?? .white)
          .overlay(Circle().stroke(.white, lineWidth: 2))
          .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
          .frame(width: diameter, height: diameter)
          .offset(x: usableWidth * fraction)
      }
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
        let fraction = min(max((gesture.location.x - diameter / 2) / usableWidth, 0), 1)
        value = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
      })
    }
    .frame(minHeight: 24)
  }
}

struct RufletPickerSwatch: View {
  let color: RufletPickerColor
  var selected = false

  var body: some View {
    Circle()
      .fill(color.swiftUI)
      .overlay(Circle().stroke(selected ? Color.primary : Color.secondary.opacity(0.35), lineWidth: selected ? 3 : 1))
      .overlay { if selected { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(contrastColor) } }
      .accessibilityLabel(color.hex)
  }

  private var contrastColor: Color { color.hsv.value > 0.6 ? .black : .white }
}

extension Double {
  var clamped: Double { min(max(self, 0), 1) }
}
