import Foundation
import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Native implementation of the six controls exported by Flet's
/// `flet_color_pickers` package.
///
/// The values and events in this file deliberately follow the vendored Dart
/// controls. In particular, ColorPicker writes `picker_color`, the simple
/// pickers write `color`, and SlidePicker only emits `color_change`.
public struct RufletColorPickerControlView: View {
  public let node: ControlNode

  @Environment(\.rufletEvents) private var events
  @State private var color = RGBAColor.black
  @State private var initialColor = RGBAColor.black
  @State private var selectedColors: [RGBAColor] = [.black]
  @State private var history: [RGBAColor] = []
  @State private var materialPrimaryIndex = 0

  public init(node: ControlNode) {
    self.node = node
  }

  public var body: some View {
    Group {
      switch node.type {
      case "ColorPicker": colorPicker
      case "HueRingPicker": hueRingPicker
      case "SlidePicker": slidePicker
      case "MaterialPicker": materialPicker
      case "BlockPicker": blockPicker(multiple: false)
      case "MultipleChoiceBlockPicker": blockPicker(multiple: true)
      default: EmptyView()
      }
    }
    .onAppear(perform: synchronizeFromNode)
    .onChange(of: node.props) { _ in synchronizeFromNode() }
    .disabled(node.bool("disabled") == true)
  }

  // MARK: - ColorPicker

  private var colorPicker: some View {
    let width = CGFloat(node.double("color_picker_width") ?? 300)
    let areaHeight = width * CGFloat(node.double("picker_area_height_percent") ?? 1)
    let enableAlpha = node.bool("enable_alpha") ?? true
    let showThumbColor = node.bool("display_thumb_color") ?? true
    let paletteType = node.string("palette_type")?.lowercased() ?? "hsvwithhue"

    return VStack(alignment: .leading, spacing: 12) {
      ColorSpectrum(
        color: $color,
        mode: spectrumMode(paletteType),
        displaysThumbColor: showThumbColor,
        changed: commitColorPickerColor)
        .frame(width: width, height: areaHeight)
        .clipShape(RoundedRectangle(cornerRadius: pickerAreaRadius))

      HStack(spacing: 10) {
        Circle()
          .fill(color.swiftUIColor)
          .frame(width: 40, height: 40)
          .onTapGesture(perform: appendCurrentColorToHistory)
        paletteSlider(paletteType, width: max(0, width - 75), changed: commitColorPickerColor)
      }
      if enableAlpha {
        alphaSlider(width: max(0, width - 75), changed: commitColorPickerColor)
      }
      if node.bool("hex_input_bar") ?? true {
        HexColorField(color: $color, changed: commitColorPickerColor)
          .frame(width: width)
      }
      colorLabels
      if !history.isEmpty {
        colorHistory
      }
    }
  }

  @ViewBuilder
  private var colorLabels: some View {
    let raw = node.array("label_types")
    let labels = raw?.compactMap(\.stringValue) ?? ["rgb", "hsv", "hsl"]
    if !labels.isEmpty {
      VStack(alignment: .leading, spacing: 3) {
        ForEach(labels, id: \.self) { label in
          Text(labelValue(label))
            .rufletTextStyle(RufletTextStyle(map: node.map("label_text_style") ?? [:]))
        }
      }
    }
  }

  private var colorHistory: some View {
    HStack(spacing: 6) {
      ForEach(Array(history.enumerated()), id: \.offset) { _, item in
        Button {
          color = item
          commitColorPickerColor(item)
          let updated = [item] + history.filter { $0 != item }
          updateHistory(Array(updated.prefix(20)))
        } label: {
          Circle().fill(item.swiftUIColor).frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
          LongPressGesture().onEnded { _ in
            updateHistory(history.filter { $0 != item })
          })
      }
    }
  }

  // MARK: - HueRingPicker

  private var hueRingPicker: some View {
    let height = CGFloat(node.double("color_picker_height") ?? 250)
    let stroke = CGFloat(node.double("hue_ring_stroke_width") ?? 20)
    let alpha = node.bool("enable_alpha") ?? false

    return VStack(spacing: 12) {
      ZStack {
        HueRing(
          color: $color,
          strokeWidth: stroke,
          displaysThumbColor: node.bool("display_thumb_color") ?? true,
          changed: commitSimpleColor)
        ColorSpectrum(
          color: $color,
          mode: .hsv,
          displaysThumbColor: node.bool("display_thumb_color") ?? true,
          changed: commitSimpleColor)
          .frame(width: height / 1.6, height: height / 1.6)
          .clipShape(Circle())
      }
        .frame(width: height, height: height)
        .padding(15)
        .clipShape(RoundedRectangle(cornerRadius: pickerAreaRadius))
      if alpha {
        alphaSlider(width: height, changed: commitSimpleColor)
      }
    }
  }

  // MARK: - SlidePicker

  private var slidePicker: some View {
    let model = node.string("color_model")?.lowercased() ?? "rgb"
    let slider = parsedSize(node.map("slider_size"), fallback: CGSize(width: 260, height: 40))
    let indicator = parsedSize(
      node.map("indicator_size"), fallback: CGSize(width: 280, height: 50))

    let labelTypes = node.array("label_types")?.compactMap(\.stringValue) ?? []
    let sliderTextStyle = RufletTextStyle(map: node.map("slider_text_style") ?? [:])

    return VStack(alignment: .center, spacing: 8) {
      if node.bool("show_indicator") ?? true {
        RoundedRectangle(cornerRadius: indicatorRadius)
          .fill(
            LinearGradient(
              stops: [
                .init(color: initialColor.swiftUIColor, location: 0),
                .init(color: initialColor.swiftUIColor, location: 0.5),
                .init(color: color.swiftUIColor, location: 0.5),
                .init(color: color.swiftUIColor, location: 1),
              ],
              startPoint: parsedUnitPoint(node.map("indicator_alignment_begin"), fallback: .topLeading),
              endPoint: parsedUnitPoint(node.map("indicator_alignment_end"), fallback: .bottomTrailing)))
          .frame(width: indicator.width, height: indicator.height)
          .onTapGesture {
            color = initialColor
            commitSlideColor(initialColor)
          }
      }

      ForEach(slideChannels(model), id: \.name) { channel in
        HStack(spacing: 8) {
          if node.bool("show_slider_text") ?? true {
            Text(String(channel.name.prefix(1)).uppercased())
              .rufletTextStyle(sliderTextStyle)
          }
          Slider(
            value: channel.binding,
            in: channel.range,
            onEditingChanged: { _ in })
          if node.bool("show_params") ?? true {
            Text(channel.value())
              .monospacedDigit()
              .rufletTextStyle(sliderTextStyle)
          }
        }
        .frame(width: slider.width, height: slider.height)
      }
      if node.bool("show_label") ?? true, !labelTypes.isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          ForEach(labelTypes, id: \.self) { label in
            Text(labelValue(label))
              .rufletTextStyle(RufletTextStyle(map: node.map("label_text_style") ?? [:]))
          }
        }
      }
    }
  }

  // MARK: - Material / block pickers

  private var materialPicker: some View {
    let primaries = ColorPickerDefaults.materialPrimaries
    let selectedIndex = materialPrimaryIndex.clamped(to: 0...(primaries.count - 1))
    let selectedPrimary = primaries[selectedIndex]
    return HStack(spacing: 12) {
      ScrollView {
        VStack(spacing: 14) {
          ForEach(Array(primaries.enumerated()), id: \.offset) { index, primary in
            Button {
              materialPrimaryIndex = index
              events.fire(node, "primary_change", data: .string(primary.hexARGB))
            } label: {
              Circle()
                .fill(primary.swiftUIColor)
                .frame(width: 25, height: 25)
                .shadow(color: index == selectedIndex ? primary.swiftUIColor : .clear, radius: 5)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 7)
      }
      .frame(width: 60, height: 500)

      ScrollView {
        VStack(spacing: 14) {
          ForEach(Array(selectedPrimary.materialShades.enumerated()), id: \.offset) { index, shade in
            Button {
              color = shade
              commitSimpleColor(shade)
            } label: {
              RoundedRectangle(cornerRadius: 2)
                .fill(shade.swiftUIColor)
                .frame(width: shade == color ? 250 : 230, height: 50)
                .overlay(alignment: .leading) {
                  if node.bool("enable_label") ?? false {
                    HStack {
                      Text(index == 5 ? "500" : String(index * 100))
                      Spacer()
                      Text(shade.hexRGB.uppercased())
                    }
                    .font(.caption.bold())
                    .foregroundStyle(shade.contrastingText)
                    .padding(.horizontal, 8)
                  }
                }
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .frame(width: 350, height: 500)
  }

  private func blockPicker(multiple: Bool) -> some View {
    let palette = parsedColors(node.array("available_colors"))
    let available = palette.isEmpty ? ColorPickerDefaults.blockColors : palette

    return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
      ForEach(available, id: \.hexARGB) { item in
        colorButton(
          item,
          selected: multiple ? selectedColors.contains(item) : item == color
        ) {
          if multiple {
            if let index = selectedColors.firstIndex(of: item) {
              selectedColors.remove(at: index)
            } else {
              selectedColors.append(item)
            }
            commitMultipleColors()
          } else {
            color = item
            commitSimpleColor(item)
          }
        }
      }
    }
    .frame(width: 300, height: 360, alignment: .top)
  }

  private func colorButton(
    _ item: RGBAColor,
    selected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Circle()
        .fill(item.swiftUIColor)
        .frame(minWidth: 42, minHeight: 42)
        .padding(7)
        .shadow(color: item.swiftUIColor.opacity(0.8), radius: 5, x: 1, y: 2)
        .overlay {
          if selected {
            Image(systemName: "checkmark").bold().foregroundStyle(item.contrastingText)
          }
        }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Shared sliders

  private func hueSlider(
    width: CGFloat,
    changed: @escaping (RGBAColor) -> Void
  ) -> some View {
    Slider(
      value: Binding(
        get: { color.hsva.hue },
        set: {
          color = RGBAColor(hue: $0, saturation: color.hsva.saturation,
                            brightness: color.hsva.brightness, alpha: color.alpha)
          changed(color)
        }),
      in: 0...360,
      onEditingChanged: { if !$0 { changed(color) } })
      .tint(color.swiftUIColor)
      .frame(width: width)
  }

  private func alphaSlider(
    width: CGFloat,
    changed: @escaping (RGBAColor) -> Void
  ) -> some View {
    Slider(
      value: Binding(
        get: { color.alpha },
        set: { color.alpha = $0; changed(color) }),
      in: 0...1,
      onEditingChanged: { if !$0 { changed(color) } })
      .frame(width: width)
  }

  private func valueSlider(
    width: CGFloat,
    changed: @escaping (RGBAColor) -> Void
  ) -> some View {
    Slider(
      value: Binding(
        get: { color.hsva.brightness },
        set: {
          color = RGBAColor(hue: color.hsva.hue, saturation: color.hsva.saturation,
                            brightness: $0, alpha: color.alpha)
          changed(color)
        }),
      in: 0...1)
      .frame(width: width)
  }

  private func saturationSlider(
    width: CGFloat,
    changed: @escaping (RGBAColor) -> Void
  ) -> some View {
    Slider(
      value: Binding(
        get: { color.hsva.saturation },
        set: {
          color = RGBAColor(hue: color.hsva.hue, saturation: $0,
                            brightness: color.hsva.brightness, alpha: color.alpha)
          changed(color)
        }),
      in: 0...1)
      .frame(width: width)
  }

  private func lightnessSlider(
    width: CGFloat,
    changed: @escaping (RGBAColor) -> Void
  ) -> some View {
    Slider(
      value: Binding(
        get: { color.hsla.lightness },
        set: {
          let hsl = color.hsla
          color = RGBAColor(hue: hsl.hue, saturation: hsl.saturation,
                            lightness: $0, alpha: color.alpha)
          changed(color)
        }),
      in: 0...1)
      .frame(width: width)
  }

  private func rgbSlider(
    _ keyPath: WritableKeyPath<RGBAColor, Double>,
    width: CGFloat,
    changed: @escaping (RGBAColor) -> Void
  ) -> some View {
    Slider(
      value: Binding(
        get: { color[keyPath: keyPath] * 255 },
        set: { color[keyPath: keyPath] = $0 / 255; changed(color) }),
      in: 0...255)
      .frame(width: width)
  }

  // MARK: - Wire synchronization

  private func synchronizeFromNode() {
    if node.type == "ColorPicker", let hsv = node.map("hsv_color"),
      let parsed = RGBAColor(hsv: hsv)
    {
      color = parsed
    } else if let parsed = RGBAColor(token: node.string("color")) {
      color = parsed
    }
    initialColor = color

    if node.type == "MultipleChoiceBlockPicker" {
      let parsed = parsedColors(node.array("colors"))
      selectedColors = parsed.isEmpty ? [.black] : parsed
    }
    history = parsedColors(node.array("color_history"))
    if let index = ColorPickerDefaults.materialPrimaries.firstIndex(where: {
      $0.materialShades.contains(color)
    }) {
      materialPrimaryIndex = index
    }
  }

  private func commitColorPickerColor(_ value: RGBAColor) {
    color = value
    let hex = value.hexARGB
    events.setLocal(node.id, "picker_color", .string(hex))
    events.update(node.id, ["picker_color": .string(hex)])
    events.fire(node, "color_change", data: .string(hex))

    let hsv = value.hsva.mapValue
    events.setLocal(node.id, "hsv_color", .map(hsv))
    events.update(node.id, ["hsv_color": .map(hsv)])
    events.fire(node, "hsv_color_change", data: .map(hsv))
  }

  private func commitSimpleColor(_ value: RGBAColor) {
    let hex = value.hexARGB
    events.setLocal(node.id, "color", .string(hex))
    events.update(node.id, ["color": .string(hex)])
    events.fire(node, "color_change", data: .string(hex))
  }

  private func commitSlideColor(_ value: RGBAColor) {
    // This intentionally does not update `color`: the upstream SlidePicker
    // control only triggers the event.
    events.fire(node, "color_change", data: .string(value.hexARGB))
  }

  private func commitMultipleColors() {
    let values = selectedColors.map { RufletValue.string($0.hexARGB) }
    events.setLocal(node.id, "colors", .array(values))
    events.update(node.id, ["colors": .array(values)])
    events.fire(node, "colors_change", data: .array(values))
  }

  private func updateHistory(_ updated: [RGBAColor]) {
    history = updated
    let values = updated.map { RufletValue.string($0.hexARGB) }
    events.setLocal(node.id, "color_history", .array(values))
    events.update(node.id, ["color_history": .array(values)])
    events.fire(node, "history_change", data: .array(values))
  }

  private func appendCurrentColorToHistory() {
    guard !history.contains(color) else { return }
    updateHistory(history + [color])
  }

  // MARK: - Values

  private var pickerAreaRadius: CGFloat {
    borderRadius(node.map("picker_area_border_radius"))
  }

  private var indicatorRadius: CGFloat {
    borderRadius(node.map("indicator_border_radius"))
  }

  private func borderRadius(_ value: [String: RufletValue]?) -> CGFloat {
    guard let value else { return 0 }
    return value["all"]?.doubleValue
      ?? value["top_left"]?.doubleValue
      ?? value["topLeft"]?.doubleValue
      ?? 0
  }

  private func parsedColors(_ values: [RufletValue]?) -> [RGBAColor] {
    values?.compactMap { RGBAColor(token: $0.stringValue) } ?? []
  }

  private func parsedSize(_ value: [String: RufletValue]?, fallback: CGSize) -> CGSize {
    guard let value else { return fallback }
    return CGSize(
      width: CGFloat(value["width"]?.doubleValue ?? Double(fallback.width)),
      height: CGFloat(value["height"]?.doubleValue ?? Double(fallback.height)))
  }

  private func parsedUnitPoint(
    _ value: [String: RufletValue]?, fallback: UnitPoint
  ) -> UnitPoint {
    guard let value else { return fallback }
    let x = (value["x"]?.doubleValue ?? 0) / 2 + 0.5
    let y = (value["y"]?.doubleValue ?? 0) / 2 + 0.5
    return UnitPoint(x: x, y: y)
  }

  private func gridColumns(minimum: CGFloat) -> [GridItem] {
    [GridItem(.adaptive(minimum: minimum), spacing: 8)]
  }

  private func spectrumMode(_ type: String) -> ColorSpectrum.Mode {
    switch type.replacingOccurrences(of: "_", with: "") {
    case "hsl", "hslwithhue": return .hsl
    case "rgb", "rgbwithblue", "rgbwithgreen", "rgbwithred": return .rgb
    default: return .hsv
    }
  }

  private func paletteSlider(
    _ type: String,
    width: CGFloat,
    changed: @escaping (RGBAColor) -> Void
  ) -> some View {
    switch type.replacingOccurrences(of: "_", with: "") {
    case "hsvwithvalue", "huewheel":
      return AnyView(valueSlider(width: width, changed: changed))
    case "hsvwithsaturation", "hslwithsaturation":
      return AnyView(saturationSlider(width: width, changed: changed))
    case "hslwithlightness":
      return AnyView(lightnessSlider(width: width, changed: changed))
    case "rgbwithred": return AnyView(rgbSlider(\.red, width: width, changed: changed))
    case "rgbwithgreen": return AnyView(rgbSlider(\.green, width: width, changed: changed))
    case "rgbwithblue": return AnyView(rgbSlider(\.blue, width: width, changed: changed))
    default: return AnyView(hueSlider(width: width, changed: changed))
    }
  }

  private func labelValue(_ label: String) -> String {
    let hsv = color.hsva
    switch label.lowercased() {
    case "hex": return color.hexARGB
    case "hsv":
      return String(format: "HSV %.0f°, %.0f%%, %.0f%%", hsv.hue,
                    hsv.saturation * 100, hsv.brightness * 100)
    case "hsl":
      let hsl = color.hsla
      return String(format: "HSL %.0f°, %.0f%%, %.0f%%", hsl.hue,
                    hsl.saturation * 100, hsl.lightness * 100)
    default:
      return "RGB \(Int((color.red * 255).rounded())), \(Int((color.green * 255).rounded())), \(Int((color.blue * 255).rounded()))"
    }
  }

  private func slideChannels(_ model: String) -> [SlideChannel] {
    var channels: [SlideChannel]
    switch model {
    case "hsv":
      channels = [
        SlideChannel(name: "Hue", range: 0...360,
          binding: Binding(get: { color.hsva.hue }, set: {
            color = RGBAColor(hue: $0, saturation: color.hsva.saturation,
                              brightness: color.hsva.brightness, alpha: color.alpha)
            commitSlideColor(color)
          }), value: { String(format: "%.0f°", color.hsva.hue) }),
        SlideChannel(name: "Saturation", range: 0...1,
          binding: Binding(get: { color.hsva.saturation }, set: {
            color = RGBAColor(hue: color.hsva.hue, saturation: $0,
                              brightness: color.hsva.brightness, alpha: color.alpha)
            commitSlideColor(color)
          }), value: { String(format: "%.0f%%", color.hsva.saturation * 100) }),
        SlideChannel(name: "Value", range: 0...1,
          binding: Binding(get: { color.hsva.brightness }, set: {
            color = RGBAColor(hue: color.hsva.hue, saturation: color.hsva.saturation,
                              brightness: $0, alpha: color.alpha)
            commitSlideColor(color)
          }), value: { String(format: "%.0f%%", color.hsva.brightness * 100) }),
      ]
    case "hsl":
      channels = [
        SlideChannel(name: "Hue", range: 0...360,
          binding: Binding(get: { color.hsla.hue }, set: {
            let hsl = color.hsla
            color = RGBAColor(hue: $0, saturation: hsl.saturation,
                              lightness: hsl.lightness, alpha: color.alpha)
            commitSlideColor(color)
          }), value: { String(format: "%.0f°", color.hsla.hue) }),
        SlideChannel(name: "Saturation", range: 0...1,
          binding: Binding(get: { color.hsla.saturation }, set: {
            let hsl = color.hsla
            color = RGBAColor(hue: hsl.hue, saturation: $0,
                              lightness: hsl.lightness, alpha: color.alpha)
            commitSlideColor(color)
          }), value: { String(format: "%.0f%%", color.hsla.saturation * 100) }),
        SlideChannel(name: "Lightness", range: 0...1,
          binding: Binding(get: { color.hsla.lightness }, set: {
            let hsl = color.hsla
            color = RGBAColor(hue: hsl.hue, saturation: hsl.saturation,
                              lightness: $0, alpha: color.alpha)
            commitSlideColor(color)
          }), value: { String(format: "%.0f%%", color.hsla.lightness * 100) }),
      ]
    default:
      channels = [
        rgbChannel("Red", keyPath: \.red),
        rgbChannel("Green", keyPath: \.green),
        rgbChannel("Blue", keyPath: \.blue),
      ]
    }
    if node.bool("enable_alpha") ?? true {
      channels.append(SlideChannel(
        name: "Alpha", range: 0...1,
        binding: Binding(get: { color.alpha }, set: {
          color.alpha = $0
          commitSlideColor(color)
        }), value: { String(format: "%.0f%%", color.alpha * 100) }))
    }
    return channels
  }

  private func rgbChannel(_ name: String, keyPath: WritableKeyPath<RGBAColor, Double>) -> SlideChannel {
    SlideChannel(
      name: name,
      range: 0...255,
      binding: Binding(
        get: { color[keyPath: keyPath] * 255 },
        set: {
          color[keyPath: keyPath] = $0 / 255
          commitSlideColor(color)
        }),
      value: { String(Int((color[keyPath: keyPath] * 255).rounded())) })
  }
}

private struct SlideChannel {
  let name: String
  let range: ClosedRange<Double>
  let binding: Binding<Double>
  let value: () -> String
}

// MARK: - Spectrum

private struct ColorSpectrum: View {
  enum Mode { case hsv, hsl, rgb }

  @Binding var color: RGBAColor
  let mode: Mode
  let displaysThumbColor: Bool
  let changed: (RGBAColor) -> Void

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        LinearGradient(colors: [.white, hueColor], startPoint: .leading, endPoint: .trailing)
        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
        Circle()
          .fill(displaysThumbColor ? color.swiftUIColor : .white)
          .overlay(Circle().stroke(.white, lineWidth: 2))
          .shadow(radius: 1)
          .frame(width: 20, height: 20)
          .position(x: CGFloat(color.hsva.saturation) * proxy.size.width,
                    y: CGFloat(1 - color.hsva.brightness) * proxy.size.height)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { apply($0.location, in: proxy.size); changed(color) }
          .onEnded { value in
            apply(value.location, in: proxy.size)
            changed(color)
          })
    }
  }

  private var hueColor: Color {
    RGBAColor(hue: color.hsva.hue, saturation: 1, brightness: 1, alpha: 1).swiftUIColor
  }

  private func apply(_ location: CGPoint, in size: CGSize) {
    let horizontal = Double(max(0, min(1, location.x / max(1, size.width))))
    let vertical = Double(max(0, min(1, 1 - location.y / max(1, size.height))))
    switch mode {
    case .hsv:
      color = RGBAColor(hue: color.hsva.hue, saturation: horizontal,
                        brightness: vertical, alpha: color.alpha)
    case .hsl:
      color = RGBAColor(hue: color.hsla.hue, saturation: horizontal,
                        lightness: vertical, alpha: color.alpha)
    case .rgb:
      color = RGBAColor(red: horizontal, green: vertical, blue: color.blue,
                        alpha: color.alpha)
    }
  }
}

private struct HueRing: View {
  @Binding var color: RGBAColor
  let strokeWidth: CGFloat
  let displaysThumbColor: Bool
  let changed: (RGBAColor) -> Void

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      ZStack {
        Circle()
          .stroke(
            AngularGradient(
              colors: stride(from: 0.0, through: 360.0, by: 30).map {
                RGBAColor(hue: $0, saturation: 1, brightness: 1, alpha: 1).swiftUIColor
              }, center: .center),
            lineWidth: strokeWidth)
        Circle()
          .fill(displaysThumbColor ? color.swiftUIColor : .clear)
          .padding(strokeWidth * 1.4)
      }
      .frame(width: side, height: side)
      .contentShape(Circle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { apply($0.location, side: side); changed(color) }
          .onEnded { value in apply(value.location, side: side); changed(color) })
    }
  }

  private func apply(_ point: CGPoint, side: CGFloat) {
    let delta = CGPoint(x: point.x - side / 2, y: point.y - side / 2)
    var degrees = atan2(delta.y, delta.x) * 180 / .pi + 90
    if degrees < 0 { degrees += 360 }
    color = RGBAColor(hue: degrees, saturation: color.hsva.saturation,
                      brightness: color.hsva.brightness, alpha: color.alpha)
  }
}

private struct HexColorField: View {
  @Binding var color: RGBAColor
  let changed: (RGBAColor) -> Void
  @State private var text = ""

  var body: some View {
    TextField("#AARRGGBB", text: $text, onCommit: commit)
      .textFieldStyle(.roundedBorder)
      .monospaced()
      .onAppear { text = color.hexARGB }
      .onChange(of: color) { text = $0.hexARGB }
  }

  private func commit() {
    guard let parsed = RGBAColor(token: text) else { return }
    color = parsed
    changed(parsed)
  }
}

// MARK: - Color model

public struct RGBAColor: Equatable, Hashable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double
  public var alpha: Double

  public static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)

  public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
    self.red = max(0, min(1, red))
    self.green = max(0, min(1, green))
    self.blue = max(0, min(1, blue))
    self.alpha = max(0, min(1, alpha))
  }

  public init?(token: String?) {
    guard var digits = token?.trimmingCharacters(in: .whitespacesAndNewlines), !digits.isEmpty
    else { return nil }
    if digits.hasPrefix("#") { digits.removeFirst() }
    if digits.lowercased().hasPrefix("0x") { digits.removeFirst(2) }
    if digits.count == 6 { digits = "ff" + digits }
    if digits.count == 3 {
      digits = "ff" + digits.map { "\($0)\($0)" }.joined()
    }
    if digits.count != 8 || UInt32(digits, radix: 16) == nil {
      guard let parsed = Self.components(from: token) else { return nil }
      self = parsed
      return
    }
    guard let value = UInt32(digits, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 0xff) / 255,
      green: Double((value >> 8) & 0xff) / 255,
      blue: Double(value & 0xff) / 255,
      alpha: Double((value >> 24) & 0xff) / 255)
  }

  public init?(hsv: [String: RufletValue]) {
    guard let alpha = hsv["alpha"]?.doubleValue,
      let hue = hsv["hue"]?.doubleValue,
      let saturation = hsv["saturation"]?.doubleValue,
      let value = hsv["value"]?.doubleValue
    else { return nil }
    self.init(hue: hue, saturation: saturation, brightness: value, alpha: alpha)
  }

  public init(hue: Double, saturation: Double, brightness: Double, alpha: Double) {
    let normalizedHue = ((hue.truncatingRemainder(dividingBy: 360)) + 360)
      .truncatingRemainder(dividingBy: 360) / 60
    let chroma = brightness * saturation
    let x = chroma * (1 - abs(normalizedHue.truncatingRemainder(dividingBy: 2) - 1))
    let m = brightness - chroma
    let components: (Double, Double, Double)
    switch normalizedHue {
    case 0..<1: components = (chroma, x, 0)
    case 1..<2: components = (x, chroma, 0)
    case 2..<3: components = (0, chroma, x)
    case 3..<4: components = (0, x, chroma)
    case 4..<5: components = (x, 0, chroma)
    default: components = (chroma, 0, x)
    }
    self.init(red: components.0 + m, green: components.1 + m,
              blue: components.2 + m, alpha: alpha)
  }

  public init(hue: Double, saturation: Double, lightness: Double, alpha: Double) {
    let chroma = (1 - abs(2 * lightness - 1)) * saturation
    let normalizedHue = ((hue.truncatingRemainder(dividingBy: 360)) + 360)
      .truncatingRemainder(dividingBy: 360) / 60
    let x = chroma * (1 - abs(normalizedHue.truncatingRemainder(dividingBy: 2) - 1))
    let m = lightness - chroma / 2
    let components: (Double, Double, Double)
    switch normalizedHue {
    case 0..<1: components = (chroma, x, 0)
    case 1..<2: components = (x, chroma, 0)
    case 2..<3: components = (0, chroma, x)
    case 3..<4: components = (0, x, chroma)
    case 4..<5: components = (x, 0, chroma)
    default: components = (chroma, 0, x)
    }
    self.init(red: components.0 + m, green: components.1 + m,
              blue: components.2 + m, alpha: alpha)
  }

  public var swiftUIColor: Color {
    Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }

  public var hexARGB: String {
    String(format: "#%02x%02x%02x%02x", byte(alpha), byte(red), byte(green), byte(blue))
  }

  public var hexRGB: String {
    String(format: "#%02x%02x%02x", byte(red), byte(green), byte(blue))
  }

  public var hsva: HSVA {
    let maximum = max(red, max(green, blue))
    let minimum = min(red, min(green, blue))
    let delta = maximum - minimum
    var hue = 0.0
    if delta != 0 {
      if maximum == red { hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6) }
      else if maximum == green { hue = 60 * ((blue - red) / delta + 2) }
      else { hue = 60 * ((red - green) / delta + 4) }
    }
    if hue < 0 { hue += 360 }
    return HSVA(alpha: alpha, hue: hue,
                saturation: maximum == 0 ? 0 : delta / maximum,
                brightness: maximum)
  }

  public var hsla: HSLA {
    let maximum = max(red, max(green, blue))
    let minimum = min(red, min(green, blue))
    let lightness = (maximum + minimum) / 2
    let delta = maximum - minimum
    let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
    return HSLA(hue: hsva.hue, saturation: saturation, lightness: lightness)
  }

  public var contrastingText: Color {
    (0.299 * red + 0.587 * green + 0.114 * blue) > 0.55 ? .black : .white
  }

  public var materialShades: [RGBAColor] {
    [0.88, 0.72, 0.52, 0.32, 0.12].map { amount in
      RGBAColor(
        red: red + (1 - red) * amount,
        green: green + (1 - green) * amount,
        blue: blue + (1 - blue) * amount,
        alpha: alpha)
    } + [self] + [0.12, 0.28, 0.44, 0.6].map { amount in
      RGBAColor(red: red * (1 - amount), green: green * (1 - amount),
                blue: blue * (1 - amount), alpha: alpha)
    }
  }

  private func byte(_ value: Double) -> Int { Int((value * 255).rounded()).clamped(to: 0...255) }

  private static func components(from token: String?) -> RGBAColor? {
    guard let swiftColor = MaterialPalette.color(token) else { return nil }
    #if os(iOS)
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      guard UIColor(swiftColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
      else { return nil }
      return RGBAColor(red: Double(red), green: Double(green), blue: Double(blue),
                       alpha: Double(alpha))
    #elseif os(macOS)
      guard let native = NSColor(swiftColor).usingColorSpace(.sRGB) else { return nil }
      return RGBAColor(red: Double(native.redComponent), green: Double(native.greenComponent),
                       blue: Double(native.blueComponent), alpha: Double(native.alphaComponent))
    #endif
  }
}

public struct HSVA: Equatable, Sendable {
  public let alpha: Double
  public let hue: Double
  public let saturation: Double
  public let brightness: Double

  public var mapValue: [String: RufletValue] {
    ["alpha": .double(alpha), "hue": .double(hue),
     "saturation": .double(saturation), "value": .double(brightness)]
  }
}

public struct HSLA: Equatable, Sendable {
  public let hue: Double
  public let saturation: Double
  public let lightness: Double
}

private enum ColorPickerDefaults {
  static let blockColors = [
    "#fff44336", "#ffe91e63", "#ff9c27b0", "#ff673ab7", "#ff3f51b5",
    "#ff2196f3", "#ff03a9f4", "#ff00bcd4", "#ff009688", "#ff4caf50",
    "#ff8bc34a", "#ffcddc39", "#ffffeb3b", "#ffffc107", "#ffff9800",
    "#ffff5722", "#ff795548", "#ff9e9e9e", "#ff607d8b", "#ff000000",
  ].compactMap(RGBAColor.init(token:))

  static let materialPrimaries = [
    "#fff44336", "#ffe91e63", "#ff9c27b0", "#ff673ab7", "#ff3f51b5",
    "#ff2196f3", "#ff03a9f4", "#ff00bcd4", "#ff009688", "#ff4caf50",
    "#ff8bc34a", "#ffcddc39", "#ffffeb3b", "#ffffc107", "#ffff9800",
    "#ffff5722", "#ff795548", "#ff9e9e9e", "#ff607d8b",
  ].compactMap(RGBAColor.init(token:))
}

private extension Int {
  func clamped(to range: ClosedRange<Int>) -> Int {
    Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
  }
}
