import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `radio.dart`.
@MainActor
public struct RadioControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletRadioGroupBinding) private var groupSelection
  @FocusState private var focused: Bool
  @State private var hovered = false

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    guard groupSelection != nil else {
      preconditionFailure("Radio must be enclosed within RadioGroup")
    }
    let presentation = RufletRadioPresentation(control: control)
    return AnyView(
      LayoutControl(control: control) {
        Button(action: select) {
          HStack(spacing: 0) {
            if presentation.labelPosition == .left { label(presentation) }
            RufletRadioArtwork(
              control: control,
              presentation: presentation,
              selected: selected,
              focused: focused,
              hovered: hovered)
            if presentation.labelPosition == .right { label(presentation) }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(RufletRadioButtonStyle())
        .disabled(control.disabled)
        .focused($focused)
        .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
        .accessibilityElement(children: .combine)
        .accessibilityValue(selected ? "selected" : "not selected")
        .onAppear {
          if presentation.autofocus { focused = true }
        }
        .onHover { hovered = $0 }
        .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      }
      .modifier(RufletListTileInputToggleModifier(action: selectFromListTile)))
  }

  private var selected: Bool {
    groupSelection?.wrappedValue == control.string("value", default: "")!
  }

  @ViewBuilder
  private func label(_ presentation: RufletRadioPresentation) -> some View {
    if let label = control.string("label"), !label.isEmpty {
      Text(label)
        .modifier(RufletTextStyleModifier(style: presentation.labelStyle))
        .opacity(control.disabled ? 0.55 : 1)
    }
  }

  private func select() {
    guard !control.disabled, let groupSelection else { return }
    rufletActivateRadio(
      selection: groupSelection,
      selected: selected,
      toggleable: control.boolean("toggleable", default: false),
      value: control.string("value", default: "")!)
  }

  /// Pinned `RadioControl._handleTileClick` selects the value directly instead
  /// of running Radio's toggleable transition.
  private func selectFromListTile() {
    guard !control.disabled, let groupSelection else { return }
    rufletSelectRadioFromListTile(
      selection: groupSelection,
      value: control.string("value", default: "")!)
  }
}

@MainActor
private struct RufletRadioArtwork: View {
  @ObservedObject var control: RufletControl
  let presentation: RufletRadioPresentation
  let selected: Bool
  let focused: Bool
  let hovered: Bool
  @Environment(\.rufletRadioPressed) private var pressed

  var body: some View {
    let states = presentation.states(
      selected: selected,
      focused: focused,
      hovered: hovered,
      pressed: pressed,
      disabled: control.disabled)
    let color = presentation.fill(states)

    ZStack {
      Circle().stroke(color, lineWidth: 1.5)
      if selected {
        Circle().fill(color).padding(4)
      }
    }
    .frame(width: 18, height: 18)
    .overlay {
      Circle()
        .fill(presentation.overlay(states))
        .frame(
          width: max(presentation.splashRadius * 2, 18),
          height: max(presentation.splashRadius * 2, 18)
        )
        .allowsHitTesting(false)
    }
    .frame(
      width: presentation.minimumInteractiveDimension,
      height: presentation.minimumInteractiveDimension
    )
    .opacity(
      control.disabled ? 0.55 : 1)
  }
}

struct RufletRadioPresentation {
  let autofocus: Bool
  let activeColor: Color?
  let focusColor: Color?
  let hoverColor: Color?
  let fillColor: RufletWidgetStateProperty<Color>
  let overlayColor: RufletWidgetStateProperty<Color>
  let splashRadius: CGFloat
  let visualDensity: RufletVisualDensity?
  let mouseCursor: String?
  let labelPosition: RufletLabelPosition
  let labelStyle: RufletTextStyle?

  @MainActor
  init(control: RufletControl) {
    autofocus = control.boolean("autofocus", default: false)
    activeColor = parseColor(control.string("active_color"))
    focusColor = parseColor(control.string("focus_color"))
    hoverColor = parseColor(control.string("hover_color"))
    fillColor = RufletWidgetStateProperty(
      control.dynamicValue("fill_color"),
      converter: rufletRadioColor)
    overlayColor = RufletWidgetStateProperty(
      control.dynamicValue("overlay_color"),
      converter: rufletRadioColor)
    splashRadius = CGFloat(control.number("splash_radius") ?? 20)
    visualDensity = parseVisualDensity(control.string("visual_density"))
    mouseCursor = control.string("mouse_cursor")
    labelPosition = parseEnum(
      RufletLabelPosition.self,
      control.string("label_position"),
      .right)!
    labelStyle = parseTextStyle(control.dynamicValue("label_style"))
  }

  var minimumInteractiveDimension: CGFloat {
    switch visualDensity {
    case .compact: 40
    case .comfortable: 44
    case .adaptivePlatformDensity, .standard, nil:
      48
    }
  }

  func states(
    selected: Bool,
    focused: Bool,
    hovered: Bool,
    pressed: Bool,
    disabled: Bool
  ) -> Set<RufletWidgetState> {
    var result = Set<RufletWidgetState>()
    if selected { result.insert(.selected) }
    if focused { result.insert(.focused) }
    if hovered { result.insert(.hovered) }
    if pressed { result.insert(.pressed) }
    if disabled { result.insert(.disabled) }
    return result
  }

  func fill(_ states: Set<RufletWidgetState>) -> Color {
    fillColor.resolve(states)
      ?? (states.contains(.selected) ? activeColor ?? .accentColor : .secondary)
  }

  func overlay(_ states: Set<RufletWidgetState>) -> Color {
    if let resolved = overlayColor.resolve(states) { return resolved }
    if states.contains(.focused), let focusColor { return focusColor.opacity(0.18) }
    if states.contains(.hovered), let hoverColor { return hoverColor.opacity(0.14) }
    if states.contains(.pressed) { return (activeColor ?? .accentColor).opacity(0.18) }
    return .clear
  }
}

private func rufletRadioColor(_ raw: Any?) -> Color? {
  if let string = raw as? String { return parseColor(string) }
  if let value = raw as? RufletValue { return parseColor(value.text) }
  return nil
}

func rufletNextRadioSelection(selected: Bool, toggleable: Bool, value: String) -> String? {
  selected && toggleable ? nil : value
}

@MainActor
func rufletActivateRadio(
  selection: Binding<String?>,
  selected: Bool,
  toggleable: Bool,
  value: String
) {
  selection.wrappedValue = rufletNextRadioSelection(
    selected: selected,
    toggleable: toggleable,
    value: value)
}

@MainActor
func rufletSelectRadioFromListTile(selection: Binding<String?>, value: String) {
  selection.wrappedValue = value
}

private struct RufletRadioPressedKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  fileprivate var rufletRadioPressed: Bool {
    get { self[RufletRadioPressedKey.self] }
    set { self[RufletRadioPressedKey.self] = newValue }
  }
}

private struct RufletRadioButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.environment(\.rufletRadioPressed, configuration.isPressed)
  }
}
