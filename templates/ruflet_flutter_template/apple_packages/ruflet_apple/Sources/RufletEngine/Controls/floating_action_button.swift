import SwiftUI

@MainActor
public struct FloatingActionButtonControl: View {
  @ObservedObject public var control: RufletControl
  @FocusState private var focused: Bool

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      if icon == nil && content == nil {
        ErrorControl(
          "FloatingActionButton has nothing to display. Provide at minimum one of these: icon, content")
      } else {
        Button(action: pressed) {
          HStack(spacing: content != nil && icon != nil ? 8 : 0) {
            icon
            content
          }
          .padding(.horizontal, extended ? 18 : 0)
          .frame(width: buttonWidth, height: buttonHeight)
          .foregroundStyle(parseColor(control.string("foreground_color")) ?? .white)
          .background(parseColor(control.string("bgcolor")) ?? .accentColor)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
          .shadow(
            color: .black.opacity(control.disabled ? 0.08 : 0.22),
            radius: CGFloat(control.number(control.disabled ? "disabled_elevation" : "elevation") ?? 3),
            y: 1)
        }
        .buttonStyle(RufletFloatingActionButtonStyle())
        .disabled(control.disabled)
        .focused($focused)
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
    parseBorderRadius(control.dynamicValue("shape"))?.uniform ?? buttonHeight / 2
  }

  private func pressed() {
    guard !control.disabled else { return }
    if let url = parseURL(control.dynamicValue("url")) { Task { await openURL(url) } }
    control.triggerEvent("click")
  }
}

private struct RufletFloatingActionButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .opacity(configuration.isPressed ? 0.82 : 1)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
  }
}
