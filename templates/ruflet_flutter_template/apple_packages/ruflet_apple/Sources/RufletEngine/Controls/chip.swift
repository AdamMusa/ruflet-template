import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `ChipControl`.
@MainActor
public struct ChipControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletChipCoordinator
  @FocusState private var focused: Bool
  @State private var hovered = false

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
    let presentation = RufletChipPresentation(
      control: control,
      selected: coordinator.selected,
      focused: focused,
      hovered: hovered)
    return HStack(spacing: 6) {
      Button(action: coordinator.activate) {
        HStack(spacing: 6) {
          if let leading = control.buildWidget("leading") {
            leading
              .modifier(RufletChipSizeModifier(control.dynamicValue("leading_size_constraints")))
              .transition(.scale.animation(presentation.leadingDrawerAnimation))
          }
          if coordinator.selected && control.boolean("show_checkmark", default: true) {
            Image(systemName: "checkmark")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(checkColor)
          }
          label
            .modifier(
              RufletTextStyleModifier(
                style: parseTextStyle(control.dynamicValue("label_text_style")))
            )
            .padding(
              parsePadding(control.dynamicValue("label_padding"))
                ?? RufletLayoutDefaults.chipLabel)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(
        RufletChipActivationButtonStyle(
          pressElevation: presentation.pressElevation,
          shadowColor: presentation.shadowColor)
      )
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
        .transition(.scale.animation(presentation.deleteDrawerAnimation))
        .disabled(control.disabled)
        .help(presentation.deleteTooltip ?? "")
        .accessibilityLabel(presentation.deleteTooltip ?? "Delete")
      }
    }
    .padding(presentation.padding)
    .foregroundStyle(.primary)
    .background(presentation.backgroundColor, in: shape)
    .overlay {
      if let border = parseBorderSide(control.dynamicValue("border_side")) {
        shape.stroke(border.color, lineWidth: border.width)
      }
    }
    .shadow(
      color: presentation.shadowColor,
      radius: max(control.number("elevation") ?? 0, 0),
      y: max(control.number("elevation") ?? 0, 0) / 2
    )
    .modifier(RufletChipClipModifier(shape: shape, behavior: presentation.clipBehavior))
    .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor")))
    .padding(presentation.densityPadding)
    .opacity(control.disabled ? 0.55 : 1)
    .animation(presentation.selectionAnimation, value: coordinator.selected)
    .animation(presentation.enableAnimation, value: control.disabled)
    .onHover { hovered = $0 }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(coordinator.selected ? .isSelected : [])
  }

  private var label: AnyView? { control.buildTextOrWidget("label") }
  private var checkColor: Color { parseColor(control.string("check_color")) ?? .white }
  private var deleteColor: Color { parseColor(control.string("delete_icon_color")) ?? .secondary }
  private var shape: RufletCornerShape {
    let radius =
      parseBorderRadius(control.dynamicValue("shape"))
      ?? RufletBorderRadius(topLeft: 16, topRight: 16, bottomLeft: 16, bottomRight: 16)
    return RufletCornerShape(radius: radius)
  }
}

@MainActor
struct RufletChipPresentation {
  let backgroundColor: Color
  let shadowColor: Color
  let pressElevation: Double
  let padding: EdgeInsets
  let densityPadding: EdgeInsets
  let clipBehavior: String
  let deleteTooltip: String?
  let enableAnimation: Animation
  let selectionAnimation: Animation
  let leadingDrawerAnimation: Animation
  let deleteDrawerAnimation: Animation

  init(control: RufletControl, selected: Bool, focused: Bool, hovered: Bool) {
    var states = Set<RufletWidgetState>()
    if selected { states.insert(.selected) }
    if focused { states.insert(.focused) }
    if hovered { states.insert(.hovered) }
    if control.disabled { states.insert(.disabled) }
    let stateColor = RufletWidgetStateProperty<Color>(
      control.dynamicValue("color"),
      converter: { raw in
        if let text = raw as? String { return parseColor(text) }
        if let value = raw as? RufletValue { return parseColor(value.text) }
        return nil
      }
    ).resolve(states)

    if control.disabled {
      backgroundColor =
        parseColor(control.string("disabled_color"))
        ?? stateColor ?? .secondary.opacity(0.16)
    } else if selected {
      backgroundColor =
        parseColor(control.string("selected_color"))
        ?? stateColor ?? .accentColor.opacity(0.2)
    } else {
      backgroundColor =
        stateColor
        ?? parseColor(control.string("bgcolor")) ?? .secondary.opacity(0.12)
    }
    if selected {
      shadowColor = parseColor(control.string("selected_shadow_color")) ?? .black.opacity(0.15)
    } else {
      shadowColor = parseColor(control.string("shadow_color")) ?? .black.opacity(0.15)
    }
    pressElevation = control.number("elevation_on_click") ?? 0
    padding =
      parsePadding(control.dynamicValue("padding"))
      ?? RufletLayoutDefaults.chip
    switch parseVisualDensity(control.string("visual_density")) {
    case .compact:
      densityPadding = EdgeInsets(top: -4, leading: -4, bottom: -4, trailing: -4)
    case .comfortable:
      densityPadding = EdgeInsets(top: -2, leading: -2, bottom: -2, trailing: -2)
    case .adaptivePlatformDensity, .standard, nil:
      densityPadding = EdgeInsets()
    }
    clipBehavior = control.string("clip_behavior", default: "none") ?? "none"
    deleteTooltip =
      control.string("delete_icon_tooltip")
      ?? control.string("delete_button_tooltip")
    enableAnimation =
      parseAnimation(control.dynamicValue("enable_animation_style"))?.animation
      ?? .easeInOut(duration: 0.15)
    selectionAnimation =
      parseAnimation(control.dynamicValue("select_animation_style"))?.animation
      ?? .easeInOut(duration: 0.15)
    leadingDrawerAnimation =
      parseAnimation(
        control.dynamicValue("leading_drawer_animation_style"))?.animation
      ?? .easeInOut(duration: 0.15)
    deleteDrawerAnimation =
      parseAnimation(
        control.dynamicValue("delete_drawer_animation_style"))?.animation
      ?? .easeInOut(duration: 0.15)
  }
}

private struct RufletChipActivationButtonStyle: ButtonStyle {
  let pressElevation: Double
  let shadowColor: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .shadow(
        color: configuration.isPressed ? shadowColor : .clear,
        radius: configuration.isPressed ? max(pressElevation, 0) : 0,
        y: configuration.isPressed ? max(pressElevation, 0) / 2 : 0)
  }
}

private struct RufletChipClipModifier: ViewModifier {
  let shape: RufletCornerShape
  let behavior: String

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" {
      content
    } else {
      content.clipShape(
        shape,
        style: FillStyle(antialiased: behavior.lowercased() != "hardedge"))
    }
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
