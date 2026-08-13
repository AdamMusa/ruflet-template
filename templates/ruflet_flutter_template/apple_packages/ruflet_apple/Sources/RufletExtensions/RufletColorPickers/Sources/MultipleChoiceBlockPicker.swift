import RufletEngine
import RufletProtocol
import SwiftUI

struct MultipleChoiceBlockPickerControl: View {
  @ObservedObject var control: RufletControl
  @State private var selected: [RufletPickerColor] = [.black]

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 12)], spacing: 12) {
      ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
        Button { toggle(color) } label: {
          RufletPickerSwatch(color: color, selected: selected.contains(color))
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(8)
    .onAppear { synchronize() }
    .onChange(of: String(describing: control.value("colors"))) { _ in synchronize() }
  }

  private var colors: [RufletPickerColor] {
    let configured = pickerColors(control.value("available_colors"))
    return configured.isEmpty ? rufletDefaultPickerColors : configured
  }

  private func toggle(_ color: RufletPickerColor) {
    if let index = selected.firstIndex(of: color) { selected.remove(at: index) }
    else { selected.append(color) }
    let value = RufletValue.array(selected.map { .string($0.hex) })
    control.updateProperties(["colors": value], notify: true)
    control.triggerEvent("colors_change", data: value)
  }

  private func synchronize() {
    let configured = pickerColors(control.value("colors"))
    selected = configured.isEmpty ? [.black] : configured
  }
}
