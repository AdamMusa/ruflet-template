import RufletEngine
import SwiftUI

struct MaterialPickerControl: View {
  @ObservedObject var control: RufletControl
  @State private var selected = RufletPickerColor.black

  var body: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: portraitOnly ? 5 : 10)
    LazyVGrid(columns: columns, spacing: 6) {
      ForEach(Array(palette.enumerated()), id: \.offset) { index, color in
        Button {
          selected = color
          reportPickerColor(control: control, property: "color", color: color)
          if index.isMultiple(of: 10) { control.triggerEvent("primary_change", data: .string(color.hex)) }
        } label: {
          RoundedRectangle(cornerRadius: 5)
            .fill(color.swiftUI)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
              if selected == color { Image(systemName: "checkmark").foregroundStyle(color.hsv.value > 0.6 ? .black : .white) }
            }
            .overlay(alignment: .bottom) {
              if control.boolean("enable_label", default: false) {
                Text(String(index % 10)).font(.system(size: 7)).foregroundStyle(color.hsv.value > 0.6 ? .black : .white)
              }
            }
        }
        .buttonStyle(.plain)
      }
    }
    .onAppear { synchronize() }
    .onChange(of: control.string("color") ?? "") { _ in synchronize() }
  }

  private var portraitOnly: Bool { control.boolean("portrait_only", default: false) }

  private var palette: [RufletPickerColor] {
    let primaryHues = stride(from: 0.0, to: 360.0, by: 36).map { $0 }
    return primaryHues.flatMap { hue in
      stride(from: 0.25, through: 0.97, by: 0.08).map { brightness in
        RufletHSVColor(alpha: 1, hue: hue, saturation: 0.78, value: brightness).rgba
      }
    }
  }

  private func synchronize() {
    selected = RufletPickerColor.parse(control.string("color")) ?? .black
  }
}
