import SwiftUI

@MainActor
public struct IconControl: View {
    @ObservedObject public var control: RufletControl
    @EnvironmentObject private var registry: RufletExtensionRegistry

    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            RufletAppleIconView.registered(
                icon: icon,
                size: control.number("size") ?? 24,
                weight: iconWeight)
                .foregroundStyle(parseColor(control.string("color")) ?? .primary)
                .accessibilityLabel(control.string("semantics_label") ?? "")
        }
    }

    private var icon: RufletAppleIcon {
        guard let code = control.integer("icon"), let icon = registry.appleIcon(for: code) else {
            preconditionFailure("Unknown Ruflet icon: \(control.string("icon") ?? "nil")")
        }
        return icon
    }

    private var iconWeight: Font.Weight {
        guard let weight = control.number("weight") else { return .regular }
        switch weight {
        case ..<250: return .ultraLight
        case ..<350: return .light
        case ..<550: return .regular
        case ..<650: return .semibold
        case ..<750: return .bold
        case ..<850: return .heavy
        default: return .black
        }
    }
}
