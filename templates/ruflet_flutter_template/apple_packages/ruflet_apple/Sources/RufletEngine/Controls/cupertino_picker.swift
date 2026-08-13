import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `cupertino_picker.dart`.
@MainActor
public struct CupertinoPickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var selectedIndex: Int

  public init(control: RufletControl) {
    self.control = control
    _selectedIndex = State(initialValue: control.integer("selected_index", default: 0) ?? 0)
  }

  public var body: some View {
    LayoutControl(control: control) {
      ZStack {
        picker
        selectionOverlay.allowsHitTesting(false)
      }
      .frame(minHeight: CGFloat(control.number("item_extent", default: 32) ?? 32) * 5)
      .background(parseColor(control.string("bgcolor")) ?? .clear)
      .clipped()
    }
    .onChange(of: selectedIndex, perform: selected)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  @ViewBuilder
  private var picker: some View {
    #if os(iOS)
    Picker("", selection: $selectedIndex) {
      pickerItems
    }
    .pickerStyle(.wheel)
    .labelsHidden()
    #elseif os(macOS)
    Picker("", selection: $selectedIndex) {
      pickerItems
    }
    .pickerStyle(.menu)
    .labelsHidden()
    #endif
  }

  @ViewBuilder
  private var pickerItems: some View {
    ForEach(Array(controls.enumerated()), id: \.element.id) { index, child in
      ControlWidget(control: child)
        .frame(maxWidth: .infinity, alignment: .center)
        .tag(index)
    }
  }

  @ViewBuilder
  private var selectionOverlay: some View {
    if let overlay = control.buildWidget("selection_overlay") {
      overlay
    } else {
      RoundedRectangle(cornerRadius: 8)
        .fill(parseColor(control.string("default_selection_overlay_bgcolor")) ?? .secondary.opacity(0.14))
        .frame(height: CGFloat(control.number("item_extent", default: 32) ?? 32))
        .padding(.horizontal, 8)
    }
  }

  private func selected(_ index: Int) {
    guard controls.indices.contains(index), control.integer("selected_index") != index else { return }
    control.updateProperties(["selected_index": .int(Int64(index))])
    control.triggerEvent("change", data: .int(Int64(index)))
  }

  private func synchronizeFromControl() {
    let requested = control.integer("selected_index", default: 0) ?? 0
    let clamped = controls.isEmpty ? 0 : min(max(requested, 0), controls.count - 1)
    if selectedIndex != clamped { selectedIndex = clamped }
  }

  private var controls: [RufletControl] { control.children("controls") }
}
