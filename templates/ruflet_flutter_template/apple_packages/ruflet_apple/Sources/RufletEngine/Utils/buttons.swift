import SwiftUI

enum RufletButtonVariant: Sendable {
  case elevated
  case filled
  case tonal
  case text
  case outlined
}

struct RufletAppleButtonStyle: ButtonStyle {
  let variant: RufletButtonVariant
  let foreground: Color
  let background: Color
  let radius: Double
  let border: RufletBorderSide?
  let elevation: Double
  let clipBehavior: String

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }

  func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius)
    configuration.label
      .foregroundStyle(foreground)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(background.opacity(configuration.isPressed ? 0.72 : 1), in: shape)
      .modifier(RufletButtonClipModifier(shape: shape, style: self))
      .overlay {
        if let border {
          shape.stroke(border.color, lineWidth: border.width)
        }
      }
      .shadow(
        color: variant == .elevated ? .black.opacity(0.2) : .clear,
        radius: variant == .elevated ? elevation : 0,
        y: variant == .elevated ? elevation / 2 : 0
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
