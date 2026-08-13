import RufletProtocol
import SwiftUI

@MainActor
public struct SwitchControl: View {
  @ObservedObject public var control: RufletControl
  @FocusState private var focused: Bool
  @State private var hovered = false

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      Button(action: activate) {
        HStack(spacing: 6) {
          if labelPosition == .left { label }
          RufletMaterialSwitchArtwork(control: control, focused: focused, hovered: hovered)
          if labelPosition == .right { label }
        }
        .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
        .contentShape(Rectangle())
      }
      .buttonStyle(RufletSwitchPressStyle())
      .disabled(control.disabled)
      .focused($focused)
      .onAppear {
        if control.boolean("autofocus", default: false) { focused = true }
      }
      .onHover { hovered = $0 }
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor")))
    }
    .modifier(RufletListTileInputToggleModifier(action: activate))
  }

  @ViewBuilder
  private var label: some View {
    if let label = control.buildTextOrWidget("label") {
      label.modifier(
        RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_text_style"))))
    }
  }

  private var labelPosition: RufletLabelPosition {
    parseEnum(RufletLabelPosition.self, control.string("label_position"), .right)!
  }

  private func activate() {
    guard !control.disabled else { return }
    let next = !control.boolean("value", default: false)
    control.updateProperties(["value": .bool(next)], notify: true)
    control.triggerEvent("change", data: .bool(next))
  }
}

@MainActor
private struct RufletMaterialSwitchArtwork: View {
  @ObservedObject var control: RufletControl
  let focused: Bool
  let hovered: Bool
  @Environment(\.rufletSwitchPressed) private var pressed

  var body: some View {
    ZStack {
      Capsule()
        .fill(trackColor)
        .overlay(
          Capsule().stroke(
            focused ? focusColor : trackOutlineColor,
            lineWidth: focused ? max(trackOutlineWidth, 2) : trackOutlineWidth)
        )
        .overlay(overlayColor)
        .frame(width: 51, height: 31)
        .shadow(color: overlayColor, radius: pressed ? splashRadius : 0)
      Circle()
        .fill(thumbColor)
        .frame(width: 27, height: 27)
        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
        .overlay {
          if let icon = thumbIcon {
            RufletAppleIconView.registered(icon: icon, size: 15)
              .foregroundStyle(value ? Color.white : Color.secondary)
          }
        }
        .offset(x: value ? 10 : -10)
        .animation(.easeInOut(duration: 0.2), value: value)
    }
    .accessibilityValue(value ? "on" : "off")
  }

  private var value: Bool { control.boolean("value", default: false) }

  private var states: Set<RufletWidgetState> {
    var result: Set<RufletWidgetState> = value ? [.selected] : []
    if control.disabled { result.insert(.disabled) }
    if focused { result.insert(.focused) }
    if hovered { result.insert(.hovered) }
    if pressed { result.insert(.pressed) }
    return result
  }

  private var thumbColor: Color {
    widgetStateColor("thumb_color")
      ?? parseColor(control.string(value ? "active_color" : "inactive_thumb_color"))
      ?? .white
  }

  private var trackColor: Color {
    widgetStateColor("track_color")
      ?? parseColor(control.string(value ? "active_track_color" : "inactive_track_color"))
      ?? (value ? .accentColor : .secondary.opacity(0.28))
  }

  private var trackOutlineColor: Color {
    widgetStateColor("track_outline_color") ?? .clear
  }

  private var focusColor: Color { parseColor(control.string("focus_color")) ?? .accentColor }
  private var splashRadius: CGFloat { CGFloat(control.number("splash_radius") ?? 0) }

  private var trackOutlineWidth: CGFloat {
    CGFloat(widgetStateDouble("track_outline_width") ?? 0)
  }

  private var overlayColor: Color {
    widgetStateColor("overlay_color")
      ?? (hovered ? (parseColor(control.string("hover_color")) ?? .clear) : .clear)
  }

  private var thumbIcon: RufletAppleIcon? {
    guard let code = widgetStateInteger("thumb_icon") else { return nil }
    return control.backend.extensionRegistry.appleIcon(for: code)
  }

  private func widgetStateColor(_ property: String) -> Color? {
    RufletWidgetStateProperty(
      control.dynamicValue(property),
      converter: { raw in
        if let string = raw as? String { return parseColor(string) }
        if let value = raw as? RufletValue { return parseColor(value.text) }
        return nil
      }
    )
    .resolve(states)
  }

  private func widgetStateDouble(_ property: String) -> Double? {
    RufletWidgetStateProperty(control.dynamicValue(property), converter: { parseDouble($0) })
      .resolve(states)
  }

  private func widgetStateInteger(_ property: String) -> Int? {
    RufletWidgetStateProperty(
      control.dynamicValue(property),
      converter: { raw in
        if let value = raw as? RufletValue { return value.integer }
        return parseInt(raw)
      }
    ).resolve(states)
  }
}

private struct RufletSwitchPressedKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  fileprivate var rufletSwitchPressed: Bool {
    get { self[RufletSwitchPressedKey.self] }
    set { self[RufletSwitchPressedKey.self] = newValue }
  }
}

private struct RufletSwitchPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.environment(\.rufletSwitchPressed, configuration.isPressed)
  }
}
