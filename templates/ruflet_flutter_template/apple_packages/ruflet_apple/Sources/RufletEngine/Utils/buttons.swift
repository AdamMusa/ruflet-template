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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(border.color, lineWidth: border.width)
                }
            }
            .shadow(
                color: variant == .elevated ? .black.opacity(0.2) : .clear,
                radius: variant == .elevated ? elevation : 0,
                y: variant == .elevated ? elevation / 2 : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}
