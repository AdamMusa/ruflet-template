import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `CupertinoSegmentedButtonControl`.
@MainActor
public struct CupertinoSegmentedButtonControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletIndexedSegmentCoordinator

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(wrappedValue: RufletIndexedSegmentCoordinator(
      control: control, defaultIndex: nil, notify: false))
  }

  public var body: some View {
    LayoutControl(control: control) {
      if controls.count < 2 {
        ErrorControl("CupertinoSegmentedButton must have at minimum two visible controls")
      } else {
        HStack(spacing: 0) {
          ForEach(Array(controls.enumerated()), id: \.offset) { index, content in
            RufletCupertinoSegment(
              content: content,
              selected: coordinator.selectedIndex == index,
              enabled: !control.disabled,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              borderColor: borderColor,
              disabledColor: disabledColor,
              disabledTextColor: disabledTextColor,
              pressedColor: pressedColor,
              first: index == 0,
              last: index == controls.count - 1,
              action: { coordinator.select(index) })
          }
        }
        .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
      }
    }
    .onAppear { coordinator.synchronizeFromControl() }
    .onChange(of: control.properties) { _ in coordinator.synchronizeFromControl() }
  }

  private var controls: [AnyView] { control.buildWidgets("controls") }
  private var borderColor: Color { parseColor(control.string("border_color")) ?? .accentColor }
  private var selectedColor: Color { parseColor(control.string("selected_color")) ?? .accentColor }
  private var unselectedColor: Color { parseColor(control.string("unselected_color")) ?? .clear }
  private var pressedColor: Color { parseColor(control.string("click_color")) ?? .accentColor.opacity(0.18) }
  private var disabledColor: Color { parseColor(control.string("disabled_color")) ?? .secondary.opacity(0.12) }
  private var disabledTextColor: Color { parseColor(control.string("disabled_text_color")) ?? .secondary }
}

@MainActor
final class RufletIndexedSegmentCoordinator: ObservableObject {
  @Published private(set) var selectedIndex: Int?
  let control: RufletControl
  private let defaultIndex: Int?
  private let notify: Bool

  init(control: RufletControl, defaultIndex: Int?, notify: Bool) {
    self.control = control
    self.defaultIndex = defaultIndex
    self.notify = notify
    selectedIndex = control.integer("selected_index") ?? defaultIndex
  }

  func synchronizeFromControl() {
    let next = control.integer("selected_index") ?? defaultIndex
    if selectedIndex != next { selectedIndex = next }
  }

  func select(_ index: Int?) {
    guard !control.disabled else { return }
    let next = index ?? defaultIndex ?? 0
    guard selectedIndex != next else { return }
    selectedIndex = next
    control.updateProperties(["selected_index": .int(Int64(next))], notify: notify)
    control.triggerEvent("change", data: .int(Int64(next)))
  }
}

private struct RufletCupertinoSegment: View {
  let content: AnyView
  let selected: Bool
  let enabled: Bool
  let selectedColor: Color
  let unselectedColor: Color
  let borderColor: Color
  let disabledColor: Color
  let disabledTextColor: Color
  let pressedColor: Color
  let first: Bool
  let last: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      content
        .frame(maxWidth: .infinity, minHeight: 28)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    .buttonStyle(RufletCupertinoSegmentButtonStyle(
      selected: selected,
      enabled: enabled,
      selectedColor: selectedColor,
      unselectedColor: unselectedColor,
      borderColor: borderColor,
      disabledColor: disabledColor,
      disabledTextColor: disabledTextColor,
      pressedColor: pressedColor,
      first: first,
      last: last))
    .disabled(!enabled)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct RufletCupertinoSegmentButtonStyle: ButtonStyle {
  let selected: Bool
  let enabled: Bool
  let selectedColor: Color
  let unselectedColor: Color
  let borderColor: Color
  let disabledColor: Color
  let disabledTextColor: Color
  let pressedColor: Color
  let first: Bool
  let last: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(enabled ? (selected ? Color.white : selectedColor) : disabledTextColor)
      .background(
        enabled
          ? (configuration.isPressed ? pressedColor : (selected ? selectedColor : unselectedColor))
          : disabledColor)
      .overlay { Rectangle().stroke(borderColor, lineWidth: 0.75) }
      .clipShape(RufletCupertinoSegmentClip(first: first, last: last))
  }
}

private struct RufletCupertinoSegmentClip: Shape {
  let first: Bool
  let last: Bool

  func path(in rect: CGRect) -> Path {
    RufletCornerShape(radius: RufletBorderRadius(
      topLeft: first ? 8 : 0,
      topRight: last ? 8 : 0,
      bottomLeft: first ? 8 : 0,
      bottomRight: last ? 8 : 0)).path(in: rect)
  }
}
