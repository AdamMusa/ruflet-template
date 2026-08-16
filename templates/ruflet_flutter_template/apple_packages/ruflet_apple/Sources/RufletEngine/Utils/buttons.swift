import SwiftUI

enum RufletButtonVariant: Sendable {
  case elevated
  case filled
  case tonal
  case text
  case outlined
}

struct RufletAppleButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  let variant: RufletButtonVariant
  let foreground: Color
  let background: Color
  let radius: Double
  let border: RufletBorderSide?
  let elevation: Double
  let clipBehavior: String
  let disabledColor: Color

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }

  func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius)
    let disabledHasContainer: Bool = switch variant {
    case .elevated, .filled, .tonal: true
    case .text, .outlined: false
    }
    let effectiveForeground = isEnabled ? foreground : disabledColor.opacity(0.38)
    let effectiveBackground = isEnabled
      ? background.opacity(configuration.isPressed ? 0.72 : 1)
      : (disabledHasContainer ? disabledColor.opacity(0.12) : .clear)
    configuration.label
      .foregroundStyle(effectiveForeground)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(effectiveBackground, in: shape)
      .modifier(RufletButtonClipModifier(shape: shape, style: self))
      .overlay {
        if let border {
          shape.stroke(isEnabled ? border.color : disabledColor.opacity(0.12), lineWidth: border.width)
        }
      }
      .shadow(
        color: variant == .elevated && isEnabled ? .black.opacity(0.2) : .clear,
        radius: variant == .elevated && isEnabled ? elevation : 0,
        y: variant == .elevated && isEnabled ? elevation / 2 : 0
      )
      .contentShape(shape)
  }
}

private struct RufletButtonClipModifier: ViewModifier {
  let shape: RoundedRectangle
  let style: RufletAppleButtonStyle

  @ViewBuilder
  func body(content: Content) -> some View {
    if style.clipsContent {
      content.clipShape(shape, style: FillStyle(antialiased: style.antialiasedClip))
    } else {
      content
    }
  }
}
