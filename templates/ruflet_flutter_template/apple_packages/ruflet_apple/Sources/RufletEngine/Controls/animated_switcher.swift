import SwiftUI

/// Apple-native port of Flet's `AnimatedSwitcherControl`.
@MainActor
public struct AnimatedSwitcherControl: View {
    @ObservedObject public var control: RufletControl

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        if let content = control.child("content") {
            LayoutControl(control: control) {
                ZStack {
                    ControlWidget(control: content)
                        .id(contentSignature(content))
                        .transition(asymmetricTransition)
                }
                .animation(inAnimation, value: contentSignature(content))
                .onAppear { content.notifyParent = true }
            }
        } else {
            ErrorControl("AnimatedSwitcher.content must be provided and visible")
        }
    }

    private var asymmetricTransition: AnyTransition {
        .asymmetric(
            insertion: baseTransition.animation(inAnimation),
            removal: baseTransition.animation(outAnimation)
        )
    }

    private var baseTransition: AnyTransition {
        switch control.string("transition")?.lowercased() {
        case "rotation":
            return .modifier(
                active: RufletSwitcherRotation(angle: -.pi * 2),
                identity: RufletSwitcherRotation(angle: 0)
            )
        case "scale": return .scale(scale: 0, anchor: .center)
        default: return .opacity
        }
    }

    private var inAnimation: Animation {
        parseCurve(control.string("switch_in_curve"), .linear)!
            .animation(duration: parseDuration(control.dynamicValue("duration"), 1)!)
    }

    private var outAnimation: Animation {
        parseCurve(control.string("switch_out_curve"), .linear)!
            .animation(duration: parseDuration(control.dynamicValue("reverse_duration"), 1)!)
    }

    private func contentSignature(_ content: RufletControl) -> String {
        "\(content.id):\(rufletStableValueDescription(content.valueMap))"
    }
}

private struct RufletSwitcherRotation: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content.rotationEffect(.radians(angle))
    }
}
