import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

@MainActor
public struct FloatingActionButtonControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletPageTheme) private var pageTheme
  @FocusState private var focused: Bool
  @State private var hovered = false

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      if icon == nil && content == nil {
        ErrorControl(
          "FloatingActionButton has nothing to display. Provide at minimum one of these: icon, content"
        )
      } else {
        let presentation = RufletFloatingActionButtonPresentation(
          control: control,
          theme: pageTheme,
          useMaterial3: pageTheme?.useMaterial3WireValue ?? true)
        Button(action: pressed) {
          HStack(spacing: content != nil && icon != nil ? 8 : 0) {
            icon
            content
          }
          .padding(.horizontal, extended ? 18 : 0)
          .frame(width: buttonWidth, height: buttonHeight)
        }
        .buttonStyle(
          RufletFloatingActionButtonStyle(
            presentation: presentation,
            focused: focused,
            hovered: hovered,
            disabled: control.disabled,
            cornerRadius: cornerRadius,
            clipBehavior: control.string("clip_behavior", default: "none") ?? "none")
        )
        .disabled(control.disabled)
        .focused($focused)
        .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor")))
        .onHover { hovered = $0 }
        .onAppear { if control.boolean("autofocus", default: false) { focused = true } }
      }
    }
  }

  private var icon: AnyView? { control.buildIconOrWidget("icon") }
  private var content: AnyView? { control.buildTextOrWidget("content") }
  private var extended: Bool { icon != nil && content != nil }
  private var buttonHeight: CGFloat { control.boolean("mini", default: false) ? 40 : 56 }
  private var buttonWidth: CGFloat? { extended ? nil : buttonHeight }
  private var cornerRadius: CGFloat {
    parseBorderRadius(control.dynamicValue("shape"))?.uniform
      ?? ((pageTheme?.useMaterial3WireValue ?? true)
        ? (control.boolean("mini", default: false) ? 12 : 16)
        : buttonHeight / 2)
  }

  private func pressed() {
    guard !control.disabled else { return }
    if control.boolean("enable_feedback") ?? true { performFloatingActionButtonFeedback() }
    if let url = parseURL(control.dynamicValue("url")) { Task { await openURL(url) } }
    control.triggerEvent("click")
  }
}

private struct RufletFloatingActionButtonStyle: ButtonStyle {
  let presentation: RufletFloatingActionButtonPresentation
  let focused: Bool
  let hovered: Bool
  let disabled: Bool
  let cornerRadius: CGFloat
  let clipBehavior: String

  func makeBody(configuration: Configuration) -> some View {
    let state = RufletFloatingActionButtonState(
      focused: focused,
      hovered: hovered,
      pressed: configuration.isPressed,
      disabled: disabled)
    configuration.label
      .foregroundStyle(presentation.foregroundColor)
      .background(presentation.backgroundColor)
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(presentation.overlayColor(for: state))
      }
      .clipShape(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
        style: clipBehavior.lowercased() == "none"
          ? FillStyle(eoFill: false, antialiased: false) : FillStyle()
      )
      .shadow(
        color: .black.opacity(disabled ? 0.08 : 0.22),
        radius: CGFloat(max(presentation.elevation(for: state), 0)),
        y: 1
      )
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .opacity(configuration.isPressed ? 0.82 : 1)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
  }
}

struct RufletFloatingActionButtonState: Equatable {
  let focused: Bool
  let hovered: Bool
  let pressed: Bool
  let disabled: Bool
}

@MainActor
struct RufletFloatingActionButtonPresentation {
  let backgroundColor: Color
  let foregroundColor: Color
  let splashColor: Color?
  let hoverColor: Color?
  let focusColor: Color?
  let elevationValue: Double
  let disabledElevation: Double
  let focusElevation: Double
  let hoverElevation: Double
  let highlightElevation: Double

  init(control: RufletControl, theme: RufletTheme? = nil, useMaterial3: Bool = true) {
    let backgroundRole = useMaterial3 ? "primary_container" : "primary"
    let foregroundRole = useMaterial3 ? "on_primary_container" : "on_primary"
    backgroundColor =
      parseColor(control.string("bgcolor"))
      ?? theme?.colorScheme?[backgroundRole] ?? .accentColor
    foregroundColor =
      parseColor(control.string("foreground_color"))
      ?? theme?.colorScheme?[foregroundRole] ?? .white
    splashColor = parseColor(control.string("splash_color"))
    hoverColor = parseColor(control.string("hover_color"))
    focusColor = parseColor(control.string("focus_color"))
    elevationValue = control.number("elevation") ?? 6
    disabledElevation = control.number("disabled_elevation") ?? 0
    focusElevation = control.number("focus_elevation") ?? 6
    hoverElevation = control.number("hover_elevation") ?? 8
    highlightElevation = control.number("highlight_elevation") ?? 12
  }

  func elevation(for state: RufletFloatingActionButtonState) -> Double {
    if state.disabled { return disabledElevation }
    if state.pressed { return highlightElevation }
    if state.hovered { return hoverElevation }
    if state.focused { return focusElevation }
    return elevationValue
  }

  func overlayColor(for state: RufletFloatingActionButtonState) -> Color {
    if state.disabled { return .clear }
    if state.pressed { return splashColor ?? foregroundColor.opacity(0.16) }
    if state.hovered { return hoverColor ?? foregroundColor.opacity(0.08) }
    if state.focused { return focusColor ?? foregroundColor.opacity(0.10) }
    return .clear
  }
}

private func performFloatingActionButtonFeedback() {
  #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  #elseif canImport(AppKit)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
  #endif
}
