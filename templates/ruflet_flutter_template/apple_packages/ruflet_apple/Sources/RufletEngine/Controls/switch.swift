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
          RufletStandardSwitchArtwork(control: control, focused: focused, hovered: hovered)
          if labelPosition == .right { label }
        }
        .padding(
          parsePadding(control.dynamicValue("padding"))
            ?? RufletLayoutDefaults.materialSwitch)
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

  func activate() {
    guard !control.disabled else { return }
    let next = !control.boolean("value", default: false)
    control.updateProperties(["value": .bool(next)], notify: true)
    control.triggerEvent("change", data: .bool(next))
  }
}

@MainActor
private struct RufletStandardSwitchArtwork: View {
  @ObservedObject var control: RufletControl
  let focused: Bool
  let hovered: Bool
  @Environment(\.rufletSwitchPressed) private var pressed

  var body: some View {
    let presentation = RufletStandardSwitchPresentation(control: control, states: states)
    ZStack {
      Capsule()
        .fill(presentation.trackColor)
        .overlay(
          Capsule().stroke(
            focused ? presentation.focusColor : presentation.trackOutlineColor,
            lineWidth: focused
              ? max(presentation.trackOutlineWidth, 2)
              : presentation.trackOutlineWidth)
        )
        .overlay(presentation.overlayColor)
        .frame(width: 51, height: 31)
        .shadow(
          color: presentation.overlayColor,
          radius: pressed ? presentation.splashRadius : 0)
      Circle()
        .fill(presentation.thumbColor)
        .frame(width: 27, height: 27)
        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
        .overlay {
          if let icon = presentation.thumbIcon {
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

}

@MainActor
struct RufletStandardSwitchPresentation {
  let activeThumbColor: Color?
  let activeTrackColor: Color?
  let inactiveThumbColor: Color?
  let inactiveTrackColor: Color?
  let thumbColor: Color
  let trackColor: Color
  let overlayColor: Color
  let trackOutlineColor: Color
  let trackOutlineWidth: CGFloat
  let thumbIcon: RufletAppleIcon?
  let focusColor: Color
  let hoverColor: Color?
  let splashRadius: CGFloat

  init(control: RufletControl, states: Set<RufletWidgetState>) {
    activeThumbColor = parseColor(control.string("active_color"))
    activeTrackColor = parseColor(control.string("active_track_color"))
    inactiveThumbColor = parseColor(control.string("inactive_thumb_color"))
    inactiveTrackColor = parseColor(control.string("inactive_track_color"))
    let stateThumbColor = rufletSwitchStateColor(
      control.dynamicValue("thumb_color"), states: states)
    let stateTrackColor = rufletSwitchStateColor(
      control.dynamicValue("track_color"), states: states)
    let stateOverlayColor = rufletSwitchStateColor(
      control.dynamicValue("overlay_color"), states: states)
    let stateTrackOutlineColor = rufletSwitchStateColor(
      control.dynamicValue("track_outline_color"), states: states)
    let stateTrackOutlineWidth = rufletSwitchStateDouble(
      control.dynamicValue("track_outline_width"), states: states)
    let stateThumbIcon = rufletSwitchStateInteger(
      control.dynamicValue("thumb_icon"), states: states)
    focusColor = parseColor(control.string("focus_color")) ?? .accentColor
    hoverColor = parseColor(control.string("hover_color"))
    splashRadius = CGFloat(control.number("splash_radius") ?? 0)

    let selected = states.contains(.selected)
    thumbColor = stateThumbColor
      ?? (selected ? activeThumbColor : inactiveThumbColor)
      ?? .white
    trackColor = stateTrackColor
      ?? (selected ? activeTrackColor : inactiveTrackColor)
      ?? (selected ? .accentColor : .secondary.opacity(0.28))
    overlayColor = stateOverlayColor
      ?? (states.contains(.hovered) ? hoverColor?.opacity(0.14) : nil)
      ?? .clear
    trackOutlineColor = stateTrackOutlineColor ?? .clear
    trackOutlineWidth = CGFloat(stateTrackOutlineWidth ?? 0)
    thumbIcon = stateThumbIcon.flatMap(control.backend.extensionRegistry.appleIcon(for:))
  }
}

func rufletSwitchStateColor(
  _ raw: Any?,
  states: Set<RufletWidgetState>
) -> Color? {
  RufletWidgetStateProperty(raw, converter: { value in
    if let string = value as? String { return parseColor(string) }
    if let value = value as? RufletValue { return parseColor(value.text) }
    return nil
  }).resolve(states)
}

func rufletSwitchStateDouble(
  _ raw: Any?,
  states: Set<RufletWidgetState>
) -> Double? {
  RufletWidgetStateProperty(raw, converter: { parseDouble($0) }).resolve(states)
}

func rufletSwitchStateInteger(
  _ raw: Any?,
  states: Set<RufletWidgetState>
) -> Int? {
  RufletWidgetStateProperty(raw, converter: { value in
    if let value = value as? RufletValue { return value.integer }
    return parseInt(value)
  }).resolve(states)
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
