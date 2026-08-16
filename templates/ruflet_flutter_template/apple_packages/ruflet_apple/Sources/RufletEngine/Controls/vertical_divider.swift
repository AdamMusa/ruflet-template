import SwiftUI

@MainActor
public struct VerticalDividerControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        BaseControl(control: control) {
            RufletCornerShape(
                radius: parseBorderRadius(control.dynamicValue("radius"), .zero)!)
                .fill(parseColor(control.string("color")) ?? Color.secondary.opacity(0.35))
                .frame(width: control.number("thickness") ?? 1)
                .padding(.top, control.number("leading_indent") ?? 0)
                .padding(.bottom, control.number("trailing_indent") ?? 0)
                .frame(width: control.number("width").map { CGFloat($0) })
        }
    }
}
