import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
func rufletActivateIconButton(_ control: RufletControl) {
  guard !control.disabled else { return }
  if let url = parseURL(control.dynamicValue("url")) {
    Task { await openURL(url) }
  }
  control.triggerEvent("click")
}

/// Apple-native port of pinned Flet `icon_button.dart`, shared by all four
/// IconButton wire variants.
@MainActor
public struct IconButtonControl: View {
  @ObservedObject public var control: RufletControl
  @FocusState private var focused: Bool
  @State private var hovered = false
  @StateObject private var focusCoordinator = RufletIconButtonFocusCoordinator()

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      if let label {
        button(label)
      } else {
        ErrorControl("IconButton must have either icon or a visible content specified.")
      }
    }
  }

  private func button(_ label: AnyView) -> some View {
    let presentation = RufletIconButtonPresentation(control: control)
    return Button(action: pressed) { label }
      .buttonStyle(
        RufletAppleIconButtonStyle(
          presentation: presentation,
          focused: focused,
          hovered: hovered,
          disabled: control.disabled))
      .disabled(control.disabled)
      .focused($focused)
      .modifier(
        RufletMouseCursorModifier(
          cursor: presentation.mouseCursor
            ?? presentation.styleMouseCursor(focused: focused, hovered: hovered, disabled: control.disabled)))
      .modifier(
        RufletButtonLongPressModifier(
          enabled: rufletButtonLongPressEnabled(control),
          highPriority: true,
          action: { control.triggerEvent("long_press") })
      )
      .onHover(perform: hoverChanged)
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      .onChange(of: focusCoordinator.focusRequest) { _ in focused = true }
      .onAppear {
        focusCoordinator.attach(to: control)
        if control.boolean("autofocus", default: false) { focused = true }
      }
      .onDisappear { focusCoordinator.detach(from: control) }
  }

  private var label: AnyView? {
    if control.boolean("selected") == true,
       let selected = control.buildIconOrWidget("selected_icon") {
      return AnyView(selected.foregroundStyle(resolvedLabelColor))
    }
    if let icon = control.buildIconOrWidget("icon") {
      return AnyView(icon.foregroundStyle(resolvedLabelColor))
    }
    return control.buildWidget("content")
  }

  private var resolvedLabelColor: Color {
    let presentation = RufletIconButtonPresentation(control: control)
    return presentation.foreground(presentation.states(
      focused: focused,
      hovered: hovered,
      pressed: false,
      disabled: control.disabled))
  }

  private func pressed() {
    let presentation = RufletIconButtonPresentation(control: control)
    if presentation.enableFeedback { performIconButtonFeedback() }
    rufletActivateIconButton(control)
  }

  private func hoverChanged(_ value: Bool) {
    hovered = value
    guard !control.disabled else { return }
    control.triggerEvent("hover", data: .bool(value))
  }
}

enum RufletIconButtonVariant: String, Equatable {
  case plain, filled, tonal, outlined

  init(_ type: String) {
    switch type {
    case "FilledIconButton": self = .filled
    case "FilledTonalIconButton": self = .tonal
    case "OutlinedIconButton": self = .outlined
    default: self = .plain
    }
  }
}

enum RufletIconButtonShapeKind: String, Equatable {
  case circle, stadium, roundedRectangle, beveledRectangle, continuousRectangle
}

struct RufletIconButtonShapeDescription: Equatable {
  let kind: RufletIconButtonShapeKind
  let radius: RufletBorderRadius

  init(_ value: Any?, defaultKind: RufletIconButtonShapeKind = .circle) {
    let details = rufletDictionary(value)
    switch (details?["_type"] as? String)?.lowercased() {
    case "stadium": kind = .stadium
    case "roundedrectangle": kind = .roundedRectangle
    case "beveledrectangle": kind = .beveledRectangle
    case "continuousrectangle": kind = .continuousRectangle
    case "circle": kind = .circle
    default: kind = defaultKind
    }
    radius = parseBorderRadius(
      details?["radius"] ?? details?["border_radius"],
      RufletBorderRadius(topLeft: 8, topRight: 8, bottomLeft: 8, bottomRight: 8))!
  }
}

struct RufletIconButtonConstraints: Equatable {
  let minWidth: CGFloat?
  let maxWidth: CGFloat?
  let minHeight: CGFloat?
  let maxHeight: CGFloat?

  init(_ value: Any?) {
    let details = rufletDictionary(value)
    minWidth = parseDouble(details?["min_width"]).map { CGFloat($0) }
    maxWidth = parseDouble(details?["max_width"]).map { CGFloat($0) }
    minHeight = parseDouble(details?["min_height"]).map { CGFloat($0) }
    maxHeight = parseDouble(details?["max_height"]).map { CGFloat($0) }
  }
}

struct RufletIconButtonPresentation {
  let variant: RufletIconButtonVariant
  let adaptive: Bool
  let selected: Bool
  let directIconColor: Color?
  let selectedIconColor: Color?
  let disabledColor: Color?
  let highlightColor: Color?
  let hoverColor: Color?
  let splashColor: Color?
  let focusColor: Color?
  let iconSize: CGFloat?
  let splashRadius: CGFloat?
  let padding: EdgeInsets?
  let alignment: Alignment?
  let mouseCursor: String?
  let sizeConstraints: RufletIconButtonConstraints
  let enableFeedback: Bool
  let animationDuration: TimeInterval
  let styleShape: RufletWidgetStateProperty<RufletIconButtonShapeDescription>
  let styleForeground: RufletWidgetStateProperty<Color>
  let styleBackground: RufletWidgetStateProperty<Color>
  let styleOverlay: RufletWidgetStateProperty<Color>
  let styleShadow: RufletWidgetStateProperty<Color>
  let styleElevation: RufletWidgetStateProperty<Double>
  let stylePadding: RufletWidgetStateProperty<EdgeInsets>
  let styleSide: RufletWidgetStateProperty<RufletBorderSide>
  let styleIconColor: RufletWidgetStateProperty<Color>
  let styleIconSize: RufletWidgetStateProperty<Double>
  let styleText: RufletWidgetStateProperty<RufletTextStyle>
  let styleMouseCursor: RufletWidgetStateProperty<String>
  let styleFixedSize: RufletWidgetStateProperty<CGSize>
  let styleMaximumSize: RufletWidgetStateProperty<CGSize>
  let styleMinimumSize: RufletWidgetStateProperty<CGSize>
  let styleAlignment: Alignment?
  let styleVisualDensity: RufletVisualDensity?
  let appBarLeadingMinimumSize: CGSize?

  @MainActor
  init(control: RufletControl) {
    variant = RufletIconButtonVariant(control.type)
    adaptive = control.adaptive == true
    selected = control.boolean("selected") == true
    directIconColor = parseColor(control.string("icon_color"))
    selectedIconColor = parseColor(control.string("selected_icon_color"))
    disabledColor = parseColor(control.string("disabled_color"))
    highlightColor = parseColor(control.string("highlight_color"))
    hoverColor = parseColor(control.string("hover_color"))
    splashColor = parseColor(control.string("splash_color"))
    focusColor = parseColor(control.string("focus_color"))
    iconSize = control.number("icon_size").map { CGFloat($0) }
    splashRadius = control.number("splash_radius").map { CGFloat($0) }
    padding = parsePadding(control.dynamicValue("padding"))
    alignment = parseAlignment(control.dynamicValue("alignment"))?.swiftUI
    mouseCursor = control.string("mouse_cursor")
    sizeConstraints = RufletIconButtonConstraints(control.dynamicValue("size_constraints"))
    appBarLeadingMinimumSize = Self.leadingMinimumSize(control)

    let details = rufletDictionary(
      control.internals?["style"].map(rufletAny) ?? control.dynamicValue("style")) ?? [:]
    styleForeground = .init(details["color"], converter: { parseColor($0 as? String) })
    styleBackground = .init(details["bgcolor"], converter: { parseColor($0 as? String) })
    styleOverlay = .init(details["overlay_color"], converter: { parseColor($0 as? String) })
    styleShadow = .init(details["shadow_color"], converter: { parseColor($0 as? String) })
    styleElevation = .init(details["elevation"], converter: { parseDouble($0) })
    stylePadding = .init(details["padding"], converter: { parsePadding($0) })
    styleSide = .init(
      details["side"], converter: { parseBorderSide($0) },
      defaultValue: parseBorderSide(rufletDictionary(details["shape"])?["side"]))
    styleIconColor = .init(details["icon_color"], converter: { parseColor($0 as? String) })
    styleIconSize = .init(details["icon_size"], converter: { parseDouble($0) })
    styleText = .init(details["text_style"], converter: { parseTextStyle($0) })
    styleMouseCursor = .init(details["mouse_cursor"], converter: { $0 as? String })
    styleFixedSize = .init(details["fixed_size"], converter: { parseSize($0) })
    styleMaximumSize = .init(details["maximum_size"], converter: { parseSize($0) })
    styleMinimumSize = .init(details["minimum_size"], converter: { parseSize($0) })
    styleAlignment = parseAlignment(details["alignment"])?.swiftUI
    styleVisualDensity = parseVisualDensity(details["visual_density"] as? String)
    animationDuration = parseDuration(details["animation_duration"], 0.08) ?? 0.08
    let defaultShape = RufletIconButtonShapeDescription(
      nil,
      defaultKind: adaptive ? .roundedRectangle : (details.isEmpty ? .circle : .stadium))
    styleShape = .init(
      details["shape"],
      converter: { RufletIconButtonShapeDescription($0) },
      defaultValue: defaultShape)
    enableFeedback = control.boolean("enable_feedback")
      ?? parseBool(details["enable_feedback"])
      ?? true
  }

  func states(focused: Bool, hovered: Bool, pressed: Bool, disabled: Bool) -> Set<RufletWidgetState> {
    var states = Set<RufletWidgetState>()
    if focused { states.insert(.focused) }
    if hovered { states.insert(.hovered) }
    if pressed { states.insert(.pressed) }
    if disabled { states.insert(.disabled) }
    if selected { states.insert(.selected) }
    return states
  }

  func foreground(_ states: Set<RufletWidgetState>) -> Color {
    if let styled = styleIconColor.resolve(states) ?? styleForeground.resolve(states) { return styled }
    if states.contains(.disabled), let disabledColor { return disabledColor }
    if selected, let selectedIconColor { return selectedIconColor }
    if let directIconColor { return directIconColor }
    if adaptive { return .accentColor }
    return variant == .filled ? .white : .accentColor
  }

  func background(_ states: Set<RufletWidgetState>) -> Color {
    if let styled = styleBackground.resolve(states) { return styled }
    if adaptive { return .clear }
    switch variant {
    case .filled: return .accentColor
    case .tonal: return .accentColor.opacity(0.16)
    case .outlined, .plain: return .clear
    }
  }

  func interactionOverlay(_ states: Set<RufletWidgetState>) -> Color {
    if let styled = styleOverlay.resolve(states) { return styled }
    if states.contains(.pressed) { return highlightColor ?? splashColor ?? foreground(states).opacity(0.15) }
    if states.contains(.hovered) { return hoverColor ?? foreground(states).opacity(0.08) }
    if states.contains(.focused) { return focusColor ?? foreground(states).opacity(0.10) }
    return .clear
  }

  func resolvedIconSize(_ states: Set<RufletWidgetState>) -> CGFloat {
    CGFloat(styleIconSize.resolve(states) ?? Double(iconSize ?? 24))
  }

  func resolvedPadding(_ states: Set<RufletWidgetState>) -> EdgeInsets {
    padding ?? stylePadding.resolve(states)
      ?? (adaptive
        ? EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        : EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
  }

  func resolvedShape(_ states: Set<RufletWidgetState>) -> RufletIconButtonShapeDescription {
    styleShape.resolve(states) ?? RufletIconButtonShapeDescription(nil)
  }

  func styleMouseCursor(focused: Bool, hovered: Bool, disabled: Bool) -> String? {
    styleMouseCursor.resolve(states(
      focused: focused, hovered: hovered, pressed: false, disabled: disabled))
  }

  var densityMinimum: CGFloat {
    guard !adaptive else { return 44 }
    switch styleVisualDensity {
    case .compact: return 36
    case .comfortable: return 40
    case .adaptivePlatformDensity, .standard, nil: return 44
    }
  }

  @MainActor
  private static func leadingMinimumSize(_ control: RufletControl) -> CGSize? {
    guard let parent = control.parentControl,
      parent.child("leading", visibleOnly: false)?.id == control.id
    else { return nil }
    let cupertino = parent.type.lowercased().contains("cupertino")
    let width = parent.number("leading_width") ?? (cupertino ? 44 : 56)
    let height = parent.number("toolbar_height") ?? (cupertino ? 44 : 56)
    return CGSize(width: width, height: height)
  }
}

private struct RufletAppleIconButtonStyle: ButtonStyle {
  let presentation: RufletIconButtonPresentation
  let focused: Bool
  let hovered: Bool
  let disabled: Bool

  func makeBody(configuration: Configuration) -> some View {
    let states = presentation.states(
      focused: focused,
      hovered: hovered,
      pressed: configuration.isPressed,
      disabled: disabled)
    let fixed = presentation.styleFixedSize.resolve(states)
    let minimum = presentation.styleMinimumSize.resolve(states)
    let maximum = presentation.styleMaximumSize.resolve(states)
    let elevation = max(presentation.styleElevation.resolve(states) ?? 0, 0)
    let shadow = presentation.styleShadow.resolve(states) ?? .clear
    let side = presentation.styleSide.resolve(states)
    let splashDiameter = presentation.splashRadius.map { max($0 * 2, 0) }
    let nativeMinimum = max(presentation.densityMinimum, splashDiameter ?? 0)
    let shape = presentation.resolvedShape(states)

    return configuration.label
      .modifier(RufletTextStyleModifier(style: presentation.styleText.resolve(states)))
      .font(.system(size: presentation.resolvedIconSize(states)))
      .foregroundStyle(presentation.foreground(states))
      .padding(presentation.resolvedPadding(states))
      .frame(width: fixed?.width, height: fixed?.height)
      .frame(
        minWidth: max(minimum?.width ?? 0, nativeMinimum),
        maxWidth: maximum?.width,
        minHeight: max(minimum?.height ?? 0, nativeMinimum),
        maxHeight: maximum?.height,
        alignment: presentation.alignment ?? presentation.styleAlignment ?? .center)
      .frame(
        minWidth: presentation.sizeConstraints.minWidth,
        maxWidth: presentation.sizeConstraints.maxWidth,
        minHeight: presentation.sizeConstraints.minHeight,
        maxHeight: presentation.sizeConstraints.maxHeight)
      .background(presentation.background(states))
      .background(presentation.interactionOverlay(states))
      .clipShape(RufletIconButtonShape(description: shape))
      .overlay {
        if let side {
          RufletIconButtonShape(description: shape)
            .stroke(side.color, lineWidth: side.width)
        } else if presentation.variant == .outlined && !presentation.adaptive {
          RufletIconButtonShape(description: shape)
            .stroke(presentation.foreground(states).opacity(0.55), lineWidth: 1)
        }
      }
      .shadow(color: shadow, radius: elevation, y: elevation / 2)
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .opacity(configuration.isPressed && presentation.adaptive ? 0.4 : (disabled ? 0.45 : 1))
      // The background/splash keeps the requested circle or rounded shape,
      // while the tap target remains the full rectangular control bounds like
      // Flutter's RenderBox and UIKit controls.
      .frame(
        minWidth: presentation.appBarLeadingMinimumSize?.width,
        minHeight: presentation.appBarLeadingMinimumSize?.height)
      .contentShape(Rectangle())
      .animation(.easeOut(duration: presentation.animationDuration), value: configuration.isPressed)
  }
}

private struct RufletIconButtonShape: Shape {
  let description: RufletIconButtonShapeDescription

  func path(in rect: CGRect) -> Path {
    switch description.kind {
    case .circle:
      return Path(ellipseIn: rect)
    case .stadium:
      return RoundedRectangle(cornerRadius: min(rect.width, rect.height) / 2).path(in: rect)
    case .roundedRectangle:
      return RufletCornerShape(radius: description.radius).path(in: rect)
    case .continuousRectangle:
      return RoundedRectangle(
        cornerRadius: description.radius.uniform ?? 8,
        style: .continuous).path(in: rect)
    case .beveledRectangle:
      let amount = min(
        CGFloat(description.radius.uniform ?? 8),
        min(rect.width, rect.height) / 2)
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
    }
  }
}

private func performIconButtonFeedback() {
  #if canImport(UIKit)
  UIImpactFeedbackGenerator(style: .light).impactOccurred()
  #elseif canImport(AppKit)
  NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
  #endif
}

@MainActor
private final class RufletIconButtonFocusCoordinator: ObservableObject {
  @Published var focusRequest = 0
  private var token: UUID?

  func attach(to control: RufletControl) {
    guard token == nil else { return }
    token = control.addInvokeMethodListener { [weak self] name, _ in
      guard name == "focus" else { throw RufletControlError.noMethodListener }
      self?.focusRequest += 1
      return .null
    }
  }

  func detach(from control: RufletControl) {
    guard let token else { return }
    control.removeInvokeMethodListener(token)
    self.token = nil
  }
}
