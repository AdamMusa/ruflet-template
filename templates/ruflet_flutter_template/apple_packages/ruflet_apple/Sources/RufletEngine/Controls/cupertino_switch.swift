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

  func activate() {
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
    let presentation = RufletCupertinoSwitchPresentation(control: control, states: states)
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
        .frame(width: 51, height: 31)
        .overlay(alignment: value ? .leading : .trailing) {
          Image(systemName: value ? "checkmark" : "xmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(value ? presentation.onLabelColor : presentation.offLabelColor)
            .padding(.horizontal, 7)
        }
      Circle()
        .fill(presentation.thumbColor)
        .frame(width: 27, height: 27)
        .shadow(color: .black.opacity(0.18), radius: pressed ? 2 : 1.5, y: 1)
        .overlay {
          if let source = presentation.thumbImageSource {
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
          } else if let icon = presentation.thumbIcon {
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
struct RufletCupertinoSwitchPresentation {
  let activeTrackColor: Color?
  let inactiveTrackColor: Color?
  let inactiveThumbColor: Color?
  let thumbColor: Color
  let trackColor: Color
  let trackOutlineColor: Color
  let trackOutlineWidth: CGFloat
  let thumbIcon: RufletAppleIcon?
  let activeThumbImageSource: RufletImageSource?
  let inactiveThumbImageSource: RufletImageSource?
  let focusColor: Color
  let onLabelColor: Color
  let offLabelColor: Color
  private let selected: Bool

  init(control: RufletControl, states: Set<RufletWidgetState>) {
    selected = states.contains(.selected)
    activeTrackColor = parseColor(control.string("active_track_color"))
    inactiveTrackColor = parseColor(control.string("inactive_track_color"))
    inactiveThumbColor = parseColor(control.string("inactive_thumb_color"))

    // Pinned CupertinoSwitch resolves thumb_color with an empty state set.
    let defaultThumbColor = rufletSwitchStateColor(
      control.dynamicValue("thumb_color"), states: [])
    let outlineColor = rufletSwitchStateColor(
      control.dynamicValue("track_outline_color"), states: states)
    let outlineWidth = rufletSwitchStateDouble(
      control.dynamicValue("track_outline_width"), states: states)
    let iconCode = rufletSwitchStateInteger(
      control.dynamicValue("thumb_icon"), states: states)

    activeThumbImageSource = parseImageSource(
      control.dynamicValue("active_thumb_image_src"), backend: control.backend)
    inactiveThumbImageSource = parseImageSource(
      control.dynamicValue("inactive_thumb_image_src"), backend: control.backend)
    // Preserve the pinned 0.80.5 lookup spelling exactly.
    focusColor = parseColor(control.string("focusColor")) ?? .accentColor
    onLabelColor = parseColor(control.string("on_label_color")) ?? .white
    offLabelColor = parseColor(control.string("off_label_color")) ?? .secondary

    thumbColor = defaultThumbColor
      ?? (selected ? nil : inactiveThumbColor)
      ?? .white
    trackColor = (selected ? activeTrackColor : inactiveTrackColor)
      ?? (selected ? .green : .secondary.opacity(0.28))
    trackOutlineColor = outlineColor ?? .clear
    trackOutlineWidth = CGFloat(outlineWidth ?? 0)
    thumbIcon = iconCode.flatMap(control.backend.extensionRegistry.appleIcon(for:))
  }

  var thumbImageSource: RufletImageSource? {
    selected ? activeThumbImageSource : inactiveThumbImageSource
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
