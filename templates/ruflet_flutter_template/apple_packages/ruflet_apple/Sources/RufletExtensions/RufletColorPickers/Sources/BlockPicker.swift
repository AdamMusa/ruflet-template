import RufletEngine
import SwiftUI

struct BlockPickerControl: View {
  @ObservedObject var control: RufletControl
  @State private var selected = RufletPickerColor.black

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 12)], spacing: 12) {
      ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
        Button {
          selected = color
          reportPickerColor(control: control, property: "color", color: color)
        } label: {
          RufletPickerSwatch(color: color, selected: color == selected)
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(8)
    .onAppear { synchronize() }
    .onChange(of: control.string("color") ?? "") { _ in synchronize() }
  }

  private var colors: [RufletPickerColor] {
    let configured = pickerColors(control.value("available_colors"))
    return configured.isEmpty ? rufletDefaultPickerColors : configured
  }

  private func synchronize() {
    selected = RufletPickerColor.parse(control.string("color")) ?? .black
  }
}
