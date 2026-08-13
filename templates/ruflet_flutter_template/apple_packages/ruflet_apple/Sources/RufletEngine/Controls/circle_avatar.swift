import SwiftUI

@MainActor
public struct CircleAvatarControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        let radius = control.number("radius")
            ?? max(control.number("min_radius") ?? 20, min(control.number("max_radius") ?? 20, 20))
        LayoutControl(control: control) {
            ZStack {
                Circle().fill(parseColor(control.string("bgcolor")) ?? .secondary.opacity(0.25))
                image(property: "background_image_src", eventData: "background")
                control.buildTextOrWidget("content")
                    .foregroundStyle(parseColor(control.string("color")) ?? .primary)
                image(property: "foreground_image_src", eventData: "foreground")
            }
            .frame(width: radius * 2, height: radius * 2)
            .clipShape(Circle())
        }
    }

    @ViewBuilder
    private func image(property: String, eventData: String) -> some View {
        if let source = parseImageSource(control.dynamicValue(property), backend: control.backend) {
            RufletImageSourceView(source: source, contentMode: .fill) {
                control.triggerEvent("image_error", data: .string(eventData))
            }
        }
    }
}
