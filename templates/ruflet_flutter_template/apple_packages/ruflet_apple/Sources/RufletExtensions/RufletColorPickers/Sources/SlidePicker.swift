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
            startPoint: rufletSlidePickerAlignment(
              control.value("indicator_alignment_begin"), defaultX: -1, defaultY: -3),
            endPoint: rufletSlidePickerAlignment(
              control.value("indicator_alignment_end"), defaultX: 1, defaultY: 3)))
          .frame(width: indicatorWidth, height: indicatorHeight)
          .onTapGesture { color = originalColor }
          .padding(.bottom, 15)
      } else {
        Color.clear.frame(height: 20)
      }
      switch model {
      case .rgb:
        componentSlider("R", value: binding(\.red), range: 0 ... 1, tint: .red,
          parameter: byteParameter)
        componentSlider("G", value: binding(\.green), range: 0 ... 1, tint: .green,
          parameter: byteParameter)
        componentSlider("B", value: binding(\.blue), range: 0 ... 1, tint: .blue,
          parameter: byteParameter)
      case .hsv:
        hsvSliders
      case .hsl:
        hslSliders
      }
      if control.boolean("enable_alpha", default: true) {
        componentSlider("A", value: binding(\.alpha), range: 0 ... 1, tint: .secondary,
          parameter: percentParameter)
      }
      if control.boolean("show_label", default: true), !labelTypes.isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          ForEach(labelTypes, id: \.rawValue) { label in
            Text(labelText(label))
              .modifier(RufletTextStyleModifier(style: labelStyle))
          }
        }
        .padding(.bottom, 20)
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
      tint: Color(hue: hsl.hue / 360, saturation: 1, brightness: 1),
      parameter: roundedParameter)
    componentSlider("S", value: Binding(
      get: { RufletHSLColor(color).saturation },
      set: { var value = RufletHSLColor(color); value.saturation = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI,
      parameter: percentParameter)
    componentSlider("L", value: Binding(
      get: { RufletHSLColor(color).lightness },
      set: { var value = RufletHSLColor(color); value.lightness = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI,
      parameter: percentParameter)
  }

  @ViewBuilder
  private var hsvSliders: some View {
    let hsv = color.hsv
    componentSlider("H", value: Binding(
      get: { hsv.hue },
      set: { color = RufletHSVColor(alpha: hsv.alpha, hue: $0, saturation: hsv.saturation, value: hsv.value).rgba }),
      range: 0 ... 360,
      tint: Color(hue: hsv.hue / 360, saturation: 1, brightness: 1),
      parameter: roundedParameter)
    componentSlider("S", value: Binding(
      get: { color.hsv.saturation },
      set: { var value = color.hsv; value.saturation = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI,
      parameter: percentParameter)
    componentSlider(model == .hsl ? "L" : "V", value: Binding(
      get: { color.hsv.value },
      set: { var value = color.hsv; value.value = $0; color = value.rgba }),
      range: 0 ... 1,
      tint: color.swiftUI,
      parameter: percentParameter)
  }

  private func componentSlider(
    _ label: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    tint: Color,
    parameter: @escaping (Double) -> String
  ) -> some View {
    HStack {
      if control.boolean("show_slider_text", default: true) {
        Text(label)
          .modifier(RufletTextStyleModifier(
            style: parseTextStyle(control.value("slider_text_style"))))
          .frame(width: 20)
      }
      RufletPickerSlider(
        value: value, range: range, tint: tint,
        thumbColor: displayThumbColor ? color.swiftUI : nil)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      if control.boolean("show_params", default: true) {
        Text(parameter(value.wrappedValue))
          .font(.system(.caption, design: .monospaced))
          .modifier(RufletTextStyleModifier(
            style: parseTextStyle(control.value("slider_text_style"))))
          .frame(width: 45)
      }
    }
    .frame(width: sliderSize.width, height: sliderSize.height)
  }

  private func roundedParameter(_ value: Double) -> String {
    String(Int(value.rounded()))
  }

  private func byteParameter(_ value: Double) -> String {
    roundedParameter(value * 255)
  }

  private func percentParameter(_ value: Double) -> String {
    roundedParameter(value * 100)
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

  private var displayThumbColor: Bool {
    control.boolean("display_thumb_color", default: true)
  }

  private var labelStyle: RufletTextStyle? {
    parseTextStyle(control.value("label_text_style"))
  }

  private var labelTypes: [RufletColorLabelType] {
    control.value("label_types")?.array?.compactMap {
      $0.text.flatMap { RufletColorLabelType(rawValue: $0.lowercased()) }
    } ?? []
  }

  private func labelText(_ type: RufletColorLabelType) -> String {
    let hsv = color.hsv
    switch type {
    case .rgb:
      return String(format: "RGB  %d  %d  %d  A %.2f",
        Int((color.red * 255).rounded()), Int((color.green * 255).rounded()),
        Int((color.blue * 255).rounded()), color.alpha)
    case .hsv:
      return String(format: "HSV  %.0f°  %.0f%%  %.0f%%",
        hsv.hue, hsv.saturation * 100, hsv.value * 100)
    case .hsl:
      let hsl = RufletHSLColor(color)
      return String(format: "HSL  %.0f°  %.0f%%  %.0f%%",
        hsl.hue, hsl.saturation * 100, hsl.lightness * 100)
    case .hex: return "HEX  \(color.hex)"
    }
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
