import RufletEngine
import RufletProtocol
import SwiftUI

struct SlidePickerControl: View {
  @ObservedObject var control: RufletControl
  @State private var color = RufletPickerColor.black
  @State private var originalColor = RufletPickerColor.black
  @State private var suppressReporting = false

  var body: some View {
    VStack(spacing: 10) {
      if control.boolean("show_indicator", default: true) {
        RoundedRectangle(cornerRadius: indicatorRadius)
          .fill(LinearGradient(
            stops: [
              .init(color: originalColor.swiftUI, location: 0),
              .init(color: originalColor.swiftUI, location: 0.5),
              .init(color: color.swiftUI, location: 0.5),
              .init(color: color.swiftUI, location: 1),
            ],
            startPoint: indicatorAlignment("indicator_alignment_begin", x: -1, y: -3),
            endPoint: indicatorAlignment("indicator_alignment_end", x: 1, y: 3)))
          .frame(width: indicatorWidth, height: indicatorHeight)
          .overlay {
            if control.boolean("show_slider_text", default: true) {
              Text(color.hex).foregroundStyle(color.hsv.value > 0.6 ? .black : .white)
            }
          }
          .onTapGesture { color = originalColor }
      }
      switch model {
      case .rgb:
        componentSlider("R", value: binding(\.red), range: 0 ... 1, tint: .red)
        componentSlider("G", value: binding(\.green), range: 0 ... 1, tint: .green)
        componentSlider("B", value: binding(\.blue), range: 0 ... 1, tint: .blue)
      case .hsv:
        hsvSliders
      case .hsl:
        hslSliders
      }
      if control.boolean("enable_alpha", default: true) {
        componentSlider("A", value: binding(\.alpha), range: 0 ... 1, tint: .secondary)
      }
    }
    .onAppear { synchronize() }
    .onChange(of: color) { _ in
      if !suppressReporting { reportPickerColor(control: control, property: "color", color: color, update: false) }
    }
    .onChange(of: control.string("color") ?? "") { _ in synchronize() }
  }

  @ViewBuilder
  private var hslSliders: some View {
    let hsl = RufletHSLColor(color)
    componentSlider("H", value: Binding(
      get: { hsl.hue },
      set: { var value = RufletHSLColor(color); value.hue = $0; color = value.rgba }),
      range: 0 ... 360,
      tint: Color(hue: hsl.hue / 360, saturation: 1, brightness: 1))
    componentSlider("S", value: Binding(
      get: { RufletHSLColor(color).saturation },
      set: { var value = RufletHSLColor(color); value.saturation = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI)
    componentSlider("L", value: Binding(
      get: { RufletHSLColor(color).lightness },
      set: { var value = RufletHSLColor(color); value.lightness = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI)
  }

  @ViewBuilder
  private var hsvSliders: some View {
    let hsv = color.hsv
    componentSlider("H", value: Binding(
      get: { hsv.hue },
      set: { color = RufletHSVColor(alpha: hsv.alpha, hue: $0, saturation: hsv.saturation, value: hsv.value).rgba }),
      range: 0 ... 360,
      tint: Color(hue: hsv.hue / 360, saturation: 1, brightness: 1))
    componentSlider("S", value: Binding(
      get: { color.hsv.saturation },
      set: { var value = color.hsv; value.saturation = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI)
    componentSlider(model == .hsl ? "L" : "V", value: Binding(
      get: { color.hsv.value },
      set: { var value = color.hsv; value.value = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI)
  }

  private func componentSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, tint: Color) -> some View {
    HStack {
      if control.boolean("show_label", default: true) { Text(label).frame(width: 20) }
      Slider(value: value, in: range).tint(tint)
        .frame(width: sliderSize.width, height: sliderSize.height)
      if control.boolean("show_params", default: true) {
        Text(String(format: range.upperBound > 1 ? "%.0f" : "%.2f", value.wrappedValue))
          .font(.system(.caption, design: .monospaced)).frame(width: 45)
      }
    }
  }

  private func binding(_ path: WritableKeyPath<RufletPickerColor, Double>) -> Binding<Double> {
    Binding(get: { color[keyPath: path] }, set: { color[keyPath: path] = $0 })
  }

  private var model: RufletColorModel { RufletColorModel(rawValue: control.string("color_model")?.lowercased() ?? "") ?? .rgb }
  private var sliderSize: CGSize {
    rufletSlidePickerSize(control.value("slider_size"), default: CGSize(width: 260, height: 40))
  }
  private var indicatorSize: CGSize {
    rufletSlidePickerSize(
      control.value("indicator_size"), default: CGSize(width: 280, height: 50))
  }
  private var indicatorWidth: Double { indicatorSize.width }
  private var indicatorHeight: Double { indicatorSize.height }
  private var indicatorRadius: Double {
    control.value("indicator_border_radius")?.number
      ?? control.value("indicator_border_radius")?.map?["top_left"]?.number
      ?? 0
  }

  private func indicatorAlignment(_ property: String, x: Double, y: Double) -> UnitPoint {
    rufletSlidePickerAlignment(control.value(property), defaultX: x, defaultY: y)
  }

  private func synchronize() {
    suppressReporting = true
    let serverColor = RufletPickerColor.parse(control.string("color")) ?? .black
    originalColor = serverColor
    color = serverColor
    DispatchQueue.main.async { suppressReporting = false }
  }
}

func rufletSlidePickerSize(_ value: RufletValue?, default defaultSize: CGSize) -> CGSize {
  CGSize(
    width: value?.map?["width"]?.number ?? defaultSize.width,
    height: value?.map?["height"]?.number ?? defaultSize.height)
}

func rufletSlidePickerAlignment(
  _ value: RufletValue?, defaultX: Double, defaultY: Double
) -> UnitPoint {
  let alignment = parseAlignment(value, RufletAlignment(x: defaultX, y: defaultY))!
  return UnitPoint(x: (alignment.x + 1) / 2, y: (alignment.y + 1) / 2)
}
