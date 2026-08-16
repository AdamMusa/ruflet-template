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
  let padding: RufletWidgetStateProperty<EdgeInsets>
  let minimumSize: RufletWidgetStateProperty<CGSize>
  let maximumSize: RufletWidgetStateProperty<CGSize>
  let fixedSize: RufletWidgetStateProperty<CGSize>
  let alignment: Alignment
  let focused: Bool
  let hovered: Bool

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }

  func makeBody(configuration: Configuration) -> some View {
    let states = states(configuration: configuration)
    let shape = RoundedRectangle(cornerRadius: radius)
    let disabledHasContainer: Bool = switch variant {
    case .elevated, .filled, .tonal: true
    case .text, .outlined: false
    }
    let effectiveForeground = isEnabled ? foreground : disabledColor.opacity(0.38)
    let effectiveBackground = isEnabled
      ? background.opacity(configuration.isPressed ? 0.72 : 1)
      : (disabledHasContainer ? disabledColor.opacity(0.12) : .clear)
    let resolvedPadding = padding.resolve(states) ?? EdgeInsets()
    let fixed = fixedSize.resolve(states)
    let minimum = minimumSize.resolve(states)
    let maximum = maximumSize.resolve(states)
    configuration.label
      .foregroundStyle(effectiveForeground)
      .padding(resolvedPadding)
      .frame(width: fixed?.width, height: fixed?.height)
      .frame(
        minWidth: minimum?.width,
        maxWidth: maximum?.width,
        minHeight: minimum?.height,
        maxHeight: maximum?.height,
        alignment: alignment)
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
      // Flutter's Material button paints/clips with its configured shape, but
      // GestureDetector hit-tests the complete RenderBox. Keeping the rounded
      // corners as the SwiftUI content shape creates dead pixels in the
      // visible button bounds, which is especially noticeable on a phone.
      .contentShape(Rectangle())
  }

  private func states(configuration: Configuration) -> Set<RufletWidgetState> {
    var result = Set<RufletWidgetState>()
    if configuration.isPressed { result.insert(.pressed) }
    if focused { result.insert(.focused) }
    if hovered { result.insert(.hovered) }
    if !isEnabled { result.insert(.disabled) }
    return result
  }
}

/// Flet only attaches its long-press callback when Ruby subscribed to it.
/// Installing a recognizer unconditionally makes an ordinary iOS tap wait for
/// the long-press recognizer to fail, and a high-priority recognizer can steal
/// the tap altogether.
@MainActor
func rufletButtonLongPressEnabled(_ control: RufletControl) -> Bool {
  !control.disabled && control.hasEventHandler("long_press")
}

struct RufletButtonLongPressModifier: ViewModifier {
  let enabled: Bool
  let highPriority: Bool
  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled, highPriority {
      content.highPriorityGesture(
        LongPressGesture().onEnded { _ in action() })
    } else if enabled {
      content.simultaneousGesture(
        LongPressGesture().onEnded { _ in action() })
    } else {
      content
    }
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
