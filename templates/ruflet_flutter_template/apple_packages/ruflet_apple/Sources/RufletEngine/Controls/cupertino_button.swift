import SwiftUI

@MainActor
public struct CupertinoButtonControl: View {
    @ObservedObject public var control: RufletControl
    @FocusState private var focused: Bool
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            Button(action: pressed) {
                HStack(spacing: 8) {
                    control.buildIconOrWidget("icon", color: parseColor(control.string("icon_color")))
                    control.buildTextOrWidget("content")
                }
                .foregroundStyle(parseColor(control.string("color")) ?? foreground)
                .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .frame(
                    minWidth: parseSize(control.dynamicValue("min_size"))?.width,
                    minHeight: parseSize(control.dynamicValue("min_size"))?.height,
                    alignment: parseAlignment(control.dynamicValue("alignment"), .center)!.swiftUI
                )
                .background(background.opacity(control.disabled ? 0.35 : 1))
                .clipShape(RufletCornerShape(radius: parseBorderRadius(control.dynamicValue("border_radius"), RufletBorderRadius(topLeft: 8, topRight: 8, bottomLeft: 8, bottomRight: 8))!))
            }
            .buttonStyle(RufletPressedOpacityStyle(opacity: control.number("opacity_on_click") ?? 0.4))
            .disabled(control.disabled).focused($focused)
            .simultaneousGesture(LongPressGesture().onEnded { _ in if !control.disabled { control.triggerEvent("long_press") } })
            .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
        }
    }

    private var filled: Bool { ["cupertinofilledbutton", "filledbutton"].contains(control.type.lowercased()) }
    private var tinted: Bool { ["cupertinotintedbutton", "filledtonalbutton"].contains(control.type.lowercased()) }
    private var background: Color {
        parseColor(control.string("bgcolor")) ?? (filled ? .accentColor : (tinted ? .accentColor.opacity(0.16) : .clear))
    }
    private var foreground: Color { filled ? .white : .accentColor }
    private func pressed() {
        if let url = parseURL(control.dynamicValue("url")) { Task { await openURL(url) } }
        control.triggerEvent("click")
    }
}

private struct RufletPressedOpacityStyle: ButtonStyle {
    let opacity: Double
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? opacity : 1)
    }
}
