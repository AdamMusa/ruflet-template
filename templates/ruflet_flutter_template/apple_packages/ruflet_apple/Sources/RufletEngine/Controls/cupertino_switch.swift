import RufletProtocol
import SwiftUI

@MainActor
public struct CupertinoSwitchControl: View {
  @ObservedObject public var control: RufletControl
  @FocusState private var focused: Bool
  @State private var hovered = false

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      Button(action: activate) {
        HStack(spacing: 6) {
          if labelPosition == .left { label }
          RufletCupertinoSwitchArtwork(control: control, focused: focused, hovered: hovered)
          if labelPosition == .right { label }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(RufletCupertinoSwitchPressStyle())
      .disabled(control.disabled)
      .focused($focused)
      .onAppear {
        if control.boolean("autofocus", default: false) { focused = true }
      }
      .onHover { hovered = $0 }
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
    }
    .modifier(RufletListTileInputToggleModifier(action: activate))
  }

  @ViewBuilder
  private var label: some View {
    if let label = control.string("label"), !label.isEmpty { Text(label) }
  }

  private var labelPosition: RufletLabelPosition {
    parseEnum(RufletLabelPosition.self, control.string("label_position"), .right)!
  }

  private func activate() {
    guard !control.disabled else { return }
    let next = !control.boolean("value", default: false)
    control.updateProperties(["value": .bool(next)], notify: true)
    control.triggerEvent("change")
  }
}

@MainActor
private struct RufletCupertinoSwitchArtwork: View {
  @ObservedObject var control: RufletControl
  let focused: Bool
  let hovered: Bool
  @Environment(\.rufletCupertinoSwitchPressed) private var pressed

  var body: some View {
    ZStack {
      Capsule()
        .fill(trackColor)
        .overlay(
          Capsule().stroke(
            focused ? focusColor : trackOutlineColor,
            lineWidth: focused ? max(trackOutlineWidth, 2) : trackOutlineWidth)
        )
        .frame(width: 51, height: 31)
        .overlay(alignment: value ? .leading : .trailing) {
          Image(systemName: value ? "checkmark" : "xmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(value ? onLabelColor : offLabelColor)
            .padding(.horizontal, 7)
        }
      Circle()
        .fill(thumbColor)
        .frame(width: 27, height: 27)
        .shadow(color: .black.opacity(0.18), radius: pressed ? 2 : 1.5, y: 1)
        .overlay {
          if let source = thumbImageSource {
            RufletImageSourceView(
              source: source,
              contentMode: .fill,
              onError: {
                control.triggerEvent(
                  "image_error", data: .string("Unable to load switch thumb image"))
              }
            )
            .clipShape(Circle())
            .allowsHitTesting(false)
          } else if let icon = thumbIcon {
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

  private var trackColor: Color {
    parseColor(control.string(value ? "active_track_color" : "inactive_track_color"))
      ?? (value ? .green : .secondary.opacity(0.28))
  }

  private var thumbColor: Color {
    widgetStateColor("thumb_color")
      ?? parseColor(control.string(value ? "active_thumb_color" : "inactive_thumb_color"))
      ?? .white
  }

  private var trackOutlineColor: Color {
    widgetStateColor("track_outline_color") ?? .clear
  }

  private var focusColor: Color {
    parseColor(control.string("focus_color") ?? control.string("focusColor")) ?? .accentColor
  }

  private var trackOutlineWidth: CGFloat {
    CGFloat(widgetStateDouble("track_outline_width") ?? 0)
  }

  private var onLabelColor: Color { parseColor(control.string("on_label_color")) ?? .white }
  private var offLabelColor: Color { parseColor(control.string("off_label_color")) ?? .secondary }

  private var thumbImageSource: RufletImageSource? {
    let sourceProperty = value ? "active_thumb_image_src" : "inactive_thumb_image_src"
    let aliasProperty = value ? "active_thumb_image" : "inactive_thumb_image"
    return parseImageSource(
      control.dynamicValue(sourceProperty) ?? control.dynamicValue(aliasProperty),
      backend: control.backend)
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

private struct RufletCupertinoSwitchPressedKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  fileprivate var rufletCupertinoSwitchPressed: Bool {
    get { self[RufletCupertinoSwitchPressedKey.self] }
    set { self[RufletCupertinoSwitchPressedKey.self] = newValue }
  }
}

private struct RufletCupertinoSwitchPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.environment(\.rufletCupertinoSwitchPressed, configuration.isPressed)
  }
}
