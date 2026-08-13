import SwiftUI

@MainActor
public struct StackControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            ZStack(alignment: parseAlignment(control.dynamicValue("alignment"), RufletAlignment(x: -1, y: -1))!.swiftUI) {
                ForEach(control.children("controls"), id: \.id) { child in
                    ControlWidget(control: child)
                        .modifier(RufletPositionedChild(control: child))
                }
            }
            .modifier(RufletStackFitModifier(fit: control.string("fit")))
            .clipped(antialiased: control.string("clip_behavior")?.lowercased() == "antialias")
        }
    }
}

@MainActor
private struct RufletPositionedChild: ViewModifier {
    @ObservedObject var control: RufletControl

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.leading, control.number("left") ?? 0)
            .padding(.top, control.number("top") ?? 0)
            .padding(.trailing, control.number("right") ?? 0)
            .padding(.bottom, control.number("bottom") ?? 0)
            .animation(parseAnimation(control.dynamicValue("animate_position"))?.animation, value: positionSignature)
    }

    private var alignment: Alignment {
        let horizontal: HorizontalAlignment = control.number("right") != nil && control.number("left") == nil ? .trailing : .leading
        let vertical: VerticalAlignment = control.number("bottom") != nil && control.number("top") == nil ? .bottom : .top
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private var positionSignature: String {
        ["left", "top", "right", "bottom"].map { String(control.number($0) ?? .nan) }.joined(separator: ":")
    }
}

private struct RufletStackFitModifier: ViewModifier {
    let fit: String?

    func body(content: Content) -> some View {
        switch fit?.lowercased() {
        case "expand": content.frame(maxWidth: .infinity, maxHeight: .infinity)
        case "passthrough": content.fixedSize()
        default: content
        }
    }
}
