import RufletEngine
import RufletProtocol
import SwiftUI

struct ColorPickerControl: View {
  @ObservedObject var control: RufletControl
  @State private var hsv = RufletPickerColor.black.hsv
  @State private var hexInput = RufletPickerColor.black.hex
  @State private var history: [RufletPickerColor] = []
  @State private var suppressReporting = false

  var body: some View {
    VStack(spacing: 12) {
      palette
      if control.boolean("enable_alpha", default: true) {
        RufletAlphaSlider(
          alpha: $hsv.alpha, color: hsv.rgba,
          displayThumbColor: displayThumbColor)
      }
      if control.boolean("hex_input_bar", default: true) {
        HStack {
          RoundedRectangle(cornerRadius: 4).fill(hsv.rgba.swiftUI).frame(width: 30, height: 24)
          TextField("#aarrggbb", text: $hexInput, onCommit: commitHex)
            .textFieldStyle(.roundedBorder)
          Button { addToHistory() } label: { Image(systemName: "clock.arrow.circlepath") }
            .buttonStyle(.borderless)
            .help("Add color to history")
        }
      }
      labelRows
      if !history.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(Array(history.enumerated()), id: \.offset) { _, color in
              Button { hsv = color.hsv } label: {
                RufletPickerSwatch(color: color, selected: color.hex == hsv.rgba.hex).frame(width: 28, height: 28)
              }.buttonStyle(.plain)
            }
          }
        }
      }
    }
    .frame(width: control.number("color_picker_width", default: 300) ?? 300)
    .onAppear { synchronize() }
    .onChange(of: hsv) { _ in changed() }
    .onChange(of: configurationIdentity) { _ in synchronize() }
  }

  @ViewBuilder
  private var palette: some View {
    switch paletteType {
    case .hsv, .hsvWithHue:
      RufletSaturationValueField(
        hsv: $hsv, cornerRadius: pickerRadius,
        displayThumbColor: displayThumbColor).frame(height: pickerAreaHeight)
      RufletHueSlider(hue: $hsv.hue, displayThumbColor: displayThumbColor)
    case .hsvWithValue:
      RufletHueSaturationField(
        hsv: $hsv, cornerRadius: pickerRadius,
        displayThumbColor: displayThumbColor).frame(height: pickerAreaHeight)
      RufletPickerSlider(
        value: $hsv.value, range: 0 ... 1, tint: hsv.rgba.swiftUI,
        thumbColor: displayThumbColor ? hsv.rgba.swiftUI : nil)
    case .hsvWithSaturation:
      RufletHueValueField(
        hsv: $hsv, cornerRadius: pickerRadius,
        displayThumbColor: displayThumbColor).frame(height: pickerAreaHeight)
      RufletPickerSlider(
        value: $hsv.saturation, range: 0 ... 1, tint: hsv.rgba.swiftUI,
        thumbColor: displayThumbColor ? hsv.rgba.swiftUI : nil)
    case .hsl:
      RufletHueSaturationField(
        hsv: $hsv, cornerRadius: pickerRadius,
        displayThumbColor: displayThumbColor).frame(height: pickerAreaHeight)
      RufletPickerSlider(
        value: $hsv.value, range: 0 ... 1, tint: hsv.rgba.swiftUI,
        thumbColor: displayThumbColor ? hsv.rgba.swiftUI : nil)
    case .rgb:
      rgbSlider("R", value: Binding(get: { hsv.rgba.red }, set: { var c = hsv.rgba; c.red = $0; hsv = c.hsv }), tint: .red)
      rgbSlider("G", value: Binding(get: { hsv.rgba.green }, set: { var c = hsv.rgba; c.green = $0; hsv = c.hsv }), tint: .green)
      rgbSlider("B", value: Binding(get: { hsv.rgba.blue }, set: { var c = hsv.rgba; c.blue = $0; hsv = c.hsv }), tint: .blue)
    }
  }

  private func rgbSlider(_ name: String, value: Binding<Double>, tint: Color) -> some View {
    HStack {
      Text(name).frame(width: 20)
      RufletPickerSlider(
        value: value, range: 0 ... 1, tint: tint,
        thumbColor: displayThumbColor ? hsv.rgba.swiftUI : nil)
      Text(String(Int((value.wrappedValue * 255).rounded()))).font(.system(.caption, design: .monospaced)).frame(width: 32)
    }
  }

  @ViewBuilder
  private var labelRows: some View {
    if !labelTypes.isEmpty {
      VStack(alignment: .leading, spacing: 3) {
        ForEach(labelTypes, id: \.rawValue) { label in
          Text(labelText(label))
            .font(.system(.caption, design: .monospaced))
            .modifier(RufletTextStyleModifier(
              style: parseTextStyle(control.value("label_text_style"))))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private var labelTypes: [RufletColorLabelType] {
    guard let raw = control.value("label_types")?.array else { return [.rgb, .hsv, .hsl] }
    return raw.compactMap { $0.text.flatMap { RufletColorLabelType(rawValue: $0.lowercased()) } }
  }

  private var paletteType: RufletPaletteType {
    switch control.string("palette_type")?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "hsv": .hsv
    case "hsvwithvalue": .hsvWithValue
    case "hsvwithsaturation": .hsvWithSaturation
    case "hsl": .hsl
    case "rgb": .rgb
    default: .hsvWithHue
    }
  }
  private var pickerAreaHeight: Double {
    220 * (control.number("picker_area_height_percent", default: 1) ?? 1)
  }
  private var pickerRadius: Double {
    control.value("picker_area_border_radius")?.number
      ?? control.value("picker_area_border_radius")?.map?["top_left"]?.number
      ?? 0
  }
  private var displayThumbColor: Bool {
    control.boolean("display_thumb_color", default: true)
  }

  private var configurationIdentity: String {
    ["color", "hsv_color", "color_history"]
      .map { String(describing: control.value($0)) }.joined(separator: "\u{1f}")
  }

  private func synchronize() {
    suppressReporting = true
    if let configuredHSV = RufletHSVColor.parse(control.value("hsv_color")) {
      hsv = configuredHSV
    } else {
      hsv = (RufletPickerColor.parse(control.string("color")) ?? .black).hsv
    }
    history = pickerColors(control.value("color_history"))
    hexInput = hsv.rgba.hex
    DispatchQueue.main.async { suppressReporting = false }
  }

  private func changed() {
    guard !suppressReporting else { return }
    let color = hsv.rgba
    hexInput = color.hex
    control.updateProperties([
      "picker_color": .string(color.hex),
      "hsv_color": hsv.valueMap,
    ], notify: true)
    control.triggerEvent("color_change", data: .string(color.hex))
    control.triggerEvent("hsv_color_change", data: hsv.valueMap)
  }

  private func commitHex() {
    if let color = RufletPickerColor.parse(hexInput) { hsv = color.hsv }
    else { hexInput = hsv.rgba.hex }
  }

  private func addToHistory() {
    let color = hsv.rgba
    history.removeAll { $0 == color }
    history.insert(color, at: 0)
    let value = RufletValue.array(history.map { .string($0.hex) })
    control.updateProperties(["color_history": value], notify: true)
    control.triggerEvent("history_change", data: value)
  }

  private func labelText(_ type: RufletColorLabelType) -> String {
    switch type {
    case .rgb:
      return String(format: "RGB  %d  %d  %d  A %.2f", Int((hsv.rgba.red * 255).rounded()), Int((hsv.rgba.green * 255).rounded()), Int((hsv.rgba.blue * 255).rounded()), hsv.alpha)
    case .hsv:
      return String(format: "HSV  %.0f°  %.0f%%  %.0f%%", hsv.hue, hsv.saturation * 100, hsv.value * 100)
    case .hsl:
      let lightness = (max(hsv.rgba.red, hsv.rgba.green, hsv.rgba.blue) + min(hsv.rgba.red, hsv.rgba.green, hsv.rgba.blue)) / 2
      return String(format: "HSL  %.0f°  %.0f%%  %.0f%%", hsv.hue, hsv.saturation * 100, lightness * 100)
    case .hex: return "HEX  \(hsv.rgba.hex)"
    }
  }
}
