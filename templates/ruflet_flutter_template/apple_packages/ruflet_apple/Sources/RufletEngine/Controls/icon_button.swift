import SwiftUI

@MainActor
public struct IconButtonControl: View {
  @ObservedObject public var control: RufletControl
  @FocusState private var focused: Bool
  @StateObject private var focusCoordinator = RufletIconButtonFocusCoordinator()

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      if let label {
        Button(action: pressed) { label }
          .buttonStyle(style)
          .disabled(control.disabled)
          .focused($focused)
          .simultaneousGesture(LongPressGesture().onEnded { _ in
            if !control.disabled { control.triggerEvent("long_press") }
          })
          .onHover { hovering in
            if !control.disabled { control.triggerEvent("hover", data: .bool(hovering)) }
          }
          .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
          .onChange(of: focusCoordinator.focusRequest) { _ in focused = true }
          .onAppear {
            focusCoordinator.attach(to: control)
            if control.boolean("autofocus", default: false) { focused = true }
          }
          .onDisappear { focusCoordinator.detach(from: control) }
      } else {
        ErrorControl("IconButton must have either icon or a visible content specified.")
      }
    }
  }

  private var label: AnyView? {
    if control.boolean("selected") == true,
       let selected = control.buildIconOrWidget(
         "selected_icon",
         color: parseColor(control.string("selected_icon_color"))) {
      return selected
    }
    if let icon = control.buildIconOrWidget("icon", color: parseColor(control.string("icon_color"))) {
      return icon
    }
    return control.buildWidget("content")
  }

  private var style: RufletAppleIconButtonStyle {
    RufletAppleIconButtonStyle(
      variant: RufletIconButtonVariant(control.type),
      size: CGFloat(control.number("icon_size") ?? 24),
      padding: parsePadding(control.dynamicValue("padding"))
        ?? EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
      foreground: parseColor(control.string(control.disabled ? "disabled_color" : "icon_color"))
        ?? .accentColor,
      selected: control.boolean("selected") == true,
      selectedForeground: parseColor(control.string("selected_icon_color")),
      background: parseColor(rufletDictionary(control.internals?["style"].map(rufletAny))?["bgcolor"] as? String))
  }

  private func pressed() {
    guard !control.disabled else { return }
    if let url = parseURL(control.dynamicValue("url")) { Task { await openURL(url) } }
    control.triggerEvent("click")
  }
}

private enum RufletIconButtonVariant {
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

private struct RufletAppleIconButtonStyle: ButtonStyle {
  let variant: RufletIconButtonVariant
  let size: CGFloat
  let padding: EdgeInsets
  let foreground: Color
  let selected: Bool
  let selectedForeground: Color?
  let background: Color?

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: size))
      .foregroundStyle(selected ? (selectedForeground ?? foreground) : foreground)
      .padding(padding)
      .frame(minWidth: 44, minHeight: 44)
      .background(backgroundColor(configuration: configuration))
      .clipShape(Circle())
      .overlay {
        if variant == .outlined { Circle().stroke(foreground.opacity(0.55), lineWidth: 1) }
      }
      .scaleEffect(configuration.isPressed ? 0.92 : 1)
      .opacity(configuration.isPressed ? 0.72 : 1)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
  }

  private func backgroundColor(configuration: Configuration) -> Color {
    if let background { return background }
    switch variant {
    case .filled: return foreground
    case .tonal: return foreground.opacity(configuration.isPressed ? 0.28 : 0.16)
    case .outlined, .plain: return configuration.isPressed ? foreground.opacity(0.12) : .clear
    }
  }
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
