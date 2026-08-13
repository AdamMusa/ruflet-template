import RufletEngine
import SwiftUI

struct HueRingPickerControl: View {
  @ObservedObject var control: RufletControl
  @State private var hsv = RufletPickerColor.black.hsv
  @State private var suppressReporting = false

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height, pickerHeight)
      let stroke = min(control.number("hue_ring_stroke_width", default: 20) ?? 20, side / 3)
      ZStack {
        Circle()
          .stroke(
            AngularGradient(
              colors: stride(from: 0.0, through: 1.0, by: 1 / 24).map { Color(hue: $0, saturation: 1, brightness: 1) },
              center: .center),
            lineWidth: stroke)
        RufletSaturationValueField(hsv: $hsv, cornerRadius: cornerRadius)
          .frame(width: (side - stroke * 2) / sqrt(2), height: (side - stroke * 2) / sqrt(2))
      }
      .frame(width: side, height: side)
      .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
      .contentShape(Circle())
      .gesture(DragGesture(minimumDistance: 0).onChanged { value in
        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let distance = hypot(dx, dy)
        if distance >= side / 2 - stroke * 1.5 {
          var degrees = atan2(dy, dx) * 180 / .pi + 90
          if degrees < 0 { degrees += 360 }
          hsv.hue = degrees
        }
      })
    }
    .frame(height: pickerHeight)
    .onAppear { synchronize() }
    .onChange(of: hsv) { _ in changed() }
    .onChange(of: control.string("color") ?? "") { _ in synchronize() }
  }

  private var pickerHeight: Double { control.number("color_picker_height", default: 250) ?? 250 }
  private var cornerRadius: Double {
    control.value("picker_area_border_radius")?.number
      ?? control.value("picker_area_border_radius")?.map?["top_left"]?.number
      ?? 0
  }

  private func synchronize() {
    suppressReporting = true
    hsv = (RufletPickerColor.parse(control.string("color")) ?? .black).hsv
    if !control.boolean("enable_alpha", default: false) { hsv.alpha = 1 }
    DispatchQueue.main.async { suppressReporting = false }
  }

  private func changed() {
    guard !suppressReporting else { return }
    reportPickerColor(control: control, property: "color", color: hsv.rgba)
  }
}
