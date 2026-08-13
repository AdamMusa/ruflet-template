import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `ChipControl`.
@MainActor
public struct ChipControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletChipCoordinator
  @FocusState private var focused: Bool

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(wrappedValue: RufletChipCoordinator(control: control))
  }

  public var body: some View {
    LayoutControl(control: control) {
      if label == nil {
        ErrorControl("Chip.label must be provided and visible")
      } else if coordinator.onSelect && coordinator.onClick {
        ErrorControl("Chip cannot have both on_select and on_click events specified")
      } else {
        chip
      }
    }
    .onAppear {
      coordinator.synchronizeFromControl()
      if control.boolean("autofocus", default: false) { focused = true }
    }
    .onChange(of: control.properties) { _ in coordinator.synchronizeFromControl() }
    .onChange(of: focused) { coordinator.focusChanged($0) }
  }

  private var chip: some View {
    HStack(spacing: 6) {
      Button(action: coordinator.activate) {
        HStack(spacing: 6) {
          if let leading = control.buildWidget("leading") {
            leading.modifier(RufletChipSizeModifier(control.dynamicValue("leading_size_constraints")))
          }
          if coordinator.selected && control.boolean("show_checkmark", default: true) {
            Image(systemName: "checkmark")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(checkColor)
          }
          label
            .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_text_style"))))
            .padding(parsePadding(control.dynamicValue("label_padding")) ?? EdgeInsets())
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(control.disabled || (!coordinator.onSelect && !coordinator.onClick))
      .focused($focused)

      if coordinator.onDelete {
        Button(action: coordinator.delete) {
          if let icon = control.buildWidget("delete_icon") {
            icon
          } else {
            Image(systemName: "xmark.circle.fill")
          }
        }
        .buttonStyle(.plain)
        .foregroundStyle(deleteColor)
        .modifier(RufletChipSizeModifier(control.dynamicValue("delete_icon_size_constraints")))
        .disabled(control.disabled)
        .help(control.string("delete_button_tooltip") ?? "")
        .accessibilityLabel(control.string("delete_button_tooltip") ?? "Delete")
      }
    }
    .padding(parsePadding(control.dynamicValue("padding"))
      ?? EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 8))
    .foregroundStyle(foregroundColor)
    .background(backgroundColor, in: shape)
    .overlay {
      if let border = parseBorderSide(control.dynamicValue("border_side")) {
        shape.stroke(border.color, lineWidth: border.width)
      }
    }
    .shadow(
      color: shadowColor,
      radius: max(control.number("elevation") ?? 0, 0),
      y: max(control.number("elevation") ?? 0, 0) / 2)
    .opacity(control.disabled ? 0.55 : 1)
    .animation(selectionAnimation, value: coordinator.selected)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(coordinator.selected ? .isSelected : [])
  }

  private var label: AnyView? { control.buildTextOrWidget("label") }
  private var checkColor: Color { parseColor(control.string("check_color")) ?? .white }
  private var deleteColor: Color { parseColor(control.string("delete_icon_color")) ?? .secondary }
  private var foregroundColor: Color {
    parseColor(control.string(control.disabled ? "disabled_color" : "color")) ?? .primary
  }
  private var backgroundColor: Color {
    if control.disabled { return parseColor(control.string("disabled_color")) ?? .secondary.opacity(0.16) }
    if coordinator.selected {
      return parseColor(control.string("selected_color")) ?? .accentColor.opacity(0.2)
    }
    return parseColor(control.string("bgcolor")) ?? .secondary.opacity(0.12)
  }
  private var shadowColor: Color {
    parseColor(control.string(coordinator.selected ? "selected_shadow_color" : "shadow_color"))
      ?? .black.opacity(0.15)
  }
  private var shape: RufletCornerShape {
    let radius = parseBorderRadius(control.dynamicValue("shape"))
      ?? RufletBorderRadius(topLeft: 16, topRight: 16, bottomLeft: 16, bottomRight: 16)
    return RufletCornerShape(radius: radius)
  }
  private var selectionAnimation: Animation? {
    parseAnimation(control.dynamicValue("select_animation_style"))?.animation
      ?? .easeInOut(duration: 0.15)
  }
}

@MainActor
final class RufletChipCoordinator: ObservableObject {
  @Published private(set) var selected: Bool
  let control: RufletControl

  init(control: RufletControl) {
    self.control = control
    selected = control.boolean("selected", default: false)
  }

  var onClick: Bool { control.boolean("on_click", default: false) }
  var onDelete: Bool { control.boolean("on_delete", default: false) }
  var onSelect: Bool { control.boolean("on_select", default: false) }

  func synchronizeFromControl() {
    let next = control.boolean("selected", default: false)
    if selected != next { selected = next }
  }

  func activate() {
    guard !control.disabled else { return }
    if onSelect {
      selected.toggle()
      control.updateProperties(["selected": .bool(selected)], notify: true)
      control.triggerEvent("select", data: .bool(selected))
    } else if onClick {
      control.triggerEvent("click")
    }
  }

  func delete() {
    guard onDelete, !control.disabled else { return }
    control.triggerEvent("delete")
  }

  func focusChanged(_ focused: Bool) {
    control.triggerEvent(focused ? "focus" : "blur")
  }
}

private struct RufletChipSizeModifier: ViewModifier {
  let minWidth: CGFloat?
  let maxWidth: CGFloat?
  let minHeight: CGFloat?
  let maxHeight: CGFloat?

  init(_ value: Any?) {
    let details = rufletDictionary(value)
    minWidth = details?["min_width"].flatMap { parseDouble($0) }.map { CGFloat($0) }
    maxWidth = details?["max_width"].flatMap { parseDouble($0) }.map { CGFloat($0) }
    minHeight = details?["min_height"].flatMap { parseDouble($0) }.map { CGFloat($0) }
    maxHeight = details?["max_height"].flatMap { parseDouble($0) }.map { CGFloat($0) }
  }

  func body(content: Content) -> some View {
    content.frame(
      minWidth: minWidth, maxWidth: maxWidth,
      minHeight: minHeight, maxHeight: maxHeight)
  }
}
