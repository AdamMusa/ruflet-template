import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `checkbox.dart`.
@MainActor
public struct CheckboxControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    RufletCheckboxBody(
      control: control,
      kind: .standard,
      value: rufletCheckboxValue(control: control))
  }
}

enum RufletCheckboxKind: Equatable {
  case standard
  case cupertino
}

@MainActor
struct RufletCheckboxBody: View {
  @ObservedObject var control: RufletControl
  let kind: RufletCheckboxKind
  let value: Bool?
  @FocusState private var focused: Bool
  @State private var hovered = false

  var body: some View {
    let presentation = RufletCheckboxPresentation(control: control, kind: kind)
    LayoutControl(control: control) {
      Button(action: toggle) {
        HStack(spacing: presentation.spacing) {
          if presentation.labelPosition == .left { label(presentation) }
          RufletCheckboxArtwork(
            control: control,
            kind: kind,
            value: value,
            focused: focused,
            hovered: hovered)
            .frame(
              width: presentation.tapTargetSize,
              height: presentation.tapTargetSize)
          if presentation.labelPosition == .right { label(presentation) }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(RufletCheckboxButtonStyle())
      .disabled(control.disabled)
      .focused($focused)
      .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(presentation.semanticsLabel ?? control.string("label") ?? "")
      .accessibilityValue(accessibilityValue)
      .onAppear {
        if presentation.autofocus { focused = true }
      }
      .onHover { hovered = $0 }
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
    }
    .modifier(RufletListTileInputToggleModifier(action: toggle))
  }

  @ViewBuilder
  private func label(_ presentation: RufletCheckboxPresentation) -> some View {
    if let label = control.buildTextOrWidget("label") {
      label
        .modifier(RufletTextStyleModifier(style: presentation.labelStyle))
        .opacity(control.disabled ? 0.55 : 1)
    }
  }

  private var currentValue: Bool? {
    value
  }

  private var accessibilityValue: String {
    switch currentValue {
    case true: return "true"
    case false: return "false"
    case nil: return "mixed"
    }
  }

  private func toggle() {
    guard !control.disabled else { return }
    rufletActivateCheckbox(
      control: control,
      current: currentValue,
      tristate: control.boolean("tristate", default: false))
  }
}

@MainActor
private struct RufletCheckboxArtwork: View {
  @ObservedObject var control: RufletControl
  let kind: RufletCheckboxKind
  let value: Bool?
  let focused: Bool
  let hovered: Bool
  @Environment(\.rufletCheckboxPressed) private var pressed

  var body: some View {
    let presentation = RufletCheckboxPresentation(control: control, kind: kind)
    let states = presentation.states(
      value: value,
      focused: focused,
      hovered: hovered,
      pressed: pressed,
      disabled: control.disabled)
    let shape = RufletCheckboxShape(presentation.shape)
    let side = presentation.borderSide(states)

    ZStack {
      shape.fill(presentation.fill(states))
      shape.stroke(
        focused ? (presentation.focusColor ?? side.color) : side.color,
        lineWidth: focused ? max(side.width, 2) : side.width)
      mark(presentation, states: states)
    }
    .frame(width: presentation.controlSize, height: presentation.controlSize)
    .overlay {
      Circle()
        .fill(presentation.overlay(states))
        .frame(
          width: max(presentation.splashRadius * 2, presentation.controlSize),
          height: max(presentation.splashRadius * 2, presentation.controlSize))
        .allowsHitTesting(false)
    }
    .opacity(control.disabled ? 0.55 : 1)
  }

  @ViewBuilder
  private func mark(
    _ presentation: RufletCheckboxPresentation,
    states: Set<RufletWidgetState>
  ) -> some View {
    if value == true {
      Image(systemName: "checkmark")
        .font(.system(size: presentation.markSize, weight: .bold))
        .foregroundStyle(presentation.checkColor(states))
    } else if value == nil {
      Image(systemName: "minus")
        .font(.system(size: presentation.markSize, weight: .bold))
        .foregroundStyle(presentation.checkColor(states))
    }
  }
}

struct RufletCheckboxPresentation {
  let kind: RufletCheckboxKind
  let autofocus: Bool
  let activeColor: Color?
  let directCheckColor: Color?
  let focusColor: Color?
  let hoverColor: Color?
  let fillColor: RufletWidgetStateProperty<Color>
  let overlayColor: RufletWidgetStateProperty<Color>
  let borderSide: RufletWidgetStateProperty<RufletBorderSide>
  let shape: RufletCheckboxShapeDescription
  let splashRadius: CGFloat
  let visualDensity: RufletVisualDensity?
  let mouseCursor: String?
  let labelPosition: RufletLabelPosition
  let labelStyle: RufletTextStyle?
  let semanticsLabel: String?
  let spacing: CGFloat
  let isError: Bool

  @MainActor
  init(control: RufletControl, kind: RufletCheckboxKind) {
    self.kind = kind
    autofocus = control.boolean("autofocus", default: false)
    activeColor = parseColor(control.string("active_color"))
    directCheckColor = parseColor(control.string("check_color"))
    focusColor = parseColor(control.string("focus_color"))
    hoverColor = kind == .standard ? parseColor(control.string("hover_color")) : nil
    fillColor = RufletWidgetStateProperty(
      control.dynamicValue("fill_color"),
      converter: rufletCheckboxColor)
    overlayColor = RufletWidgetStateProperty(
      kind == .standard ? control.dynamicValue("overlay_color") : nil,
      converter: rufletCheckboxColor)
    borderSide = RufletWidgetStateProperty(
      control.dynamicValue("border_side"),
      converter: { parseBorderSide($0) })
    shape = RufletCheckboxShapeDescription(control.dynamicValue("shape"))
    splashRadius = kind == .standard
      ? CGFloat(control.number("splash_radius") ?? 20)
      : 0
    visualDensity = kind == .standard
      ? parseVisualDensity(control.string("visual_density"))
      : nil
    mouseCursor = control.string("mouse_cursor")
    labelPosition = parseEnum(
      RufletLabelPosition.self,
      control.string("label_position"),
      .right)!
    labelStyle = kind == .standard
      ? parseTextStyle(control.dynamicValue("label_style"))
      : nil
    semanticsLabel = control.string("semantics_label")
    spacing = kind == .cupertino
      ? CGFloat(control.number("spacing") ?? 10)
      : 0
    isError = kind == .standard && control.boolean("error", default: false)
  }

  var controlSize: CGFloat { kind == .cupertino ? 20 : 18 }
  var markSize: CGFloat { kind == .cupertino ? 12 : 11 }

  var tapTargetSize: CGFloat {
    guard kind == .standard else { return controlSize }
    switch visualDensity {
    case .compact: return 40
    case .comfortable: return 44
    case .adaptivePlatformDensity:
      #if os(macOS)
        return 40
      #else
        return 48
      #endif
    case .standard, nil: return 48
    }
  }

  func states(
    value: Bool?,
    focused: Bool,
    hovered: Bool,
    pressed: Bool,
    disabled: Bool
  ) -> Set<RufletWidgetState> {
    var result = Set<RufletWidgetState>()
    if value != false { result.insert(.selected) }
    if focused { result.insert(.focused) }
    if hovered { result.insert(.hovered) }
    if pressed { result.insert(.pressed) }
    if disabled { result.insert(.disabled) }
    if isError { result.insert(.error) }
    return result
  }

  func fill(_ states: Set<RufletWidgetState>) -> Color {
    if let resolved = fillColor.resolve(states) { return resolved }
    if states.contains(.error) { return states.contains(.selected) ? .red : .clear }
    if states.contains(.selected) { return activeColor ?? defaultActiveColor }
    return .clear
  }

  func checkColor(_: Set<RufletWidgetState>) -> Color {
    directCheckColor ?? .white
  }

  func borderSide(_ states: Set<RufletWidgetState>) -> RufletBorderSide {
    borderSide.resolve(states)
      ?? shape.side
      ?? RufletBorderSide(
        width: 1.5,
        color: states.contains(.error) ? .red : .secondary)
  }

  func overlay(_ states: Set<RufletWidgetState>) -> Color {
    guard kind == .standard else { return .clear }
    if let resolved = overlayColor.resolve(states) { return resolved }
    if states.contains(.focused), let focusColor { return focusColor.opacity(0.18) }
    if states.contains(.hovered), let hoverColor { return hoverColor.opacity(0.14) }
    if states.contains(.pressed) { return defaultActiveColor.opacity(0.18) }
    return .clear
  }

  private var defaultActiveColor: Color { .accentColor }
}

enum RufletCheckboxShapeKind: String, Equatable {
  case roundedRectangle
  case stadium
  case circle
  case beveledRectangle
  case continuousRectangle
}

struct RufletCheckboxShapeDescription: @unchecked Sendable {
  let kind: RufletCheckboxShapeKind
  let radius: RufletBorderRadius
  let eccentricity: Double
  let side: RufletBorderSide?

  init(_ value: Any?) {
    let details = rufletDictionary(value)
    switch (details?["_type"] as? String)?.lowercased() {
    case "stadium": kind = .stadium
    case "circle": kind = .circle
    case "beveledrectangle": kind = .beveledRectangle
    case "continuousrectangle": kind = .continuousRectangle
    default: kind = .roundedRectangle
    }
    radius = parseBorderRadius(
      details?["radius"],
      RufletBorderRadius(topLeft: 3, topRight: 3, bottomLeft: 3, bottomRight: 3))!
    eccentricity = parseDouble(details?["eccentricity"], 0)!
    side = parseBorderSide(details?["side"])
  }
}

private struct RufletCheckboxShape: Shape {
  let description: RufletCheckboxShapeDescription

  init(_ description: RufletCheckboxShapeDescription) {
    self.description = description
  }

  func path(in rect: CGRect) -> Path {
    switch description.kind {
    case .circle:
      // Checkbox artwork is square, so Flutter's CircleBorder eccentricity
      // still resolves to a circle at this size.
      return Circle().path(in: rect)
    case .stadium:
      return Capsule().path(in: rect)
    case .beveledRectangle:
      let amount = min(description.radius.topLeft, min(rect.width, rect.height) / 2)
      var path = Path()
      path.move(to: CGPoint(x: rect.minX + amount, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + amount))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - amount))
      path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX + amount, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - amount))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + amount))
      path.closeSubpath()
      return path
    case .roundedRectangle, .continuousRectangle:
      return RufletCornerShape(radius: description.radius).path(in: rect)
    }
  }
}

private func rufletCheckboxColor(_ raw: Any?) -> Color? {
  if let string = raw as? String { return parseColor(string) }
  if let value = raw as? RufletValue { return parseColor(value.text) }
  return nil
}

@MainActor
func rufletCheckboxValue(control: RufletControl) -> Bool? {
  if control.value("value")?.isNull == true,
    control.boolean("tristate", default: false)
  {
    return nil
  }
  return control.boolean("value", default: false)
}

@MainActor
func rufletActivateCheckbox(control: RufletControl, current: Bool?, tristate: Bool) {
  let next = rufletNextCheckboxValue(current: current, tristate: tristate)
  control.updateProperties(["value": next], notify: true)
  control.triggerEvent("change", data: next)
}

func rufletNextCheckboxValue(current: Bool?, tristate: Bool) -> RufletValue {
  if !tristate { return .bool(!(current ?? false)) }
  if current == nil { return .bool(false) }
  if current == false { return .bool(true) }
  return .null
}

private struct RufletCheckboxPressedKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  fileprivate var rufletCheckboxPressed: Bool {
    get { self[RufletCheckboxPressedKey.self] }
    set { self[RufletCheckboxPressedKey.self] = newValue }
  }
}

private struct RufletCheckboxButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.environment(\.rufletCheckboxPressed, configuration.isPressed)
  }
}
