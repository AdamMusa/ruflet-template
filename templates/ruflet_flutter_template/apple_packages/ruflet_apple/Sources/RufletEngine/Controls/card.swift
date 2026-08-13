import SwiftUI

enum RufletCardVariant: String, CaseIterable, RufletStringEnum {
    case elevated, filled, outlined
}

@MainActor
public struct CardControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        let shape = rufletDictionary(control.dynamicValue("shape"))
        let radius = parseBorderRadius(shape?["border_radius"], RufletBorderRadius(topLeft: 12, topRight: 12, bottomLeft: 12, bottomRight: 12))!
        let variant = parseEnum(RufletCardVariant.self, control.string("variant"), .elevated)!
        LayoutControl(control: control) {
            control.buildWidget("content")
                .background(background(variant))
                .clipShape(RufletCornerShape(radius: radius))
                .overlay {
                    if variant == .outlined {
                        RufletCornerShape(radius: radius)
                            .stroke(parseColor(control.string("shadow_color")) ?? .secondary.opacity(0.5))
                    }
                }
                .shadow(
                    color: variant == .elevated ? (parseColor(control.string("shadow_color")) ?? .black.opacity(0.2)) : .clear,
                    radius: control.number("elevation") ?? (variant == .elevated ? 1 : 0)
                )
                .padding(parseMargin(control.dynamicValue("margin")) ?? EdgeInsets())
                .accessibilityElement(children: control.boolean("semantic_container", default: true) ? .contain : .ignore)
        }
    }

    private func background(_ variant: RufletCardVariant) -> Color {
        parseColor(control.string("bgcolor")) ?? (variant == .filled ? .secondary.opacity(0.12) : .rufletSystemBackground)
    }
}
