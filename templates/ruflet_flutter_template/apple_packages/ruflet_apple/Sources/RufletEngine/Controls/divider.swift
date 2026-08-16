import SwiftUI

@MainActor
public struct DividerControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        BaseControl(control: control) {
            RufletCornerShape(
                radius: parseBorderRadius(control.dynamicValue("radius"), .zero)!)
                .fill(parseColor(control.string("color")) ?? Color.secondary.opacity(0.35))
                .frame(height: control.number("thickness") ?? 1)
                .padding(.leading, control.number("leading_indent") ?? 0)
                .padding(.trailing, control.number("trailing_indent") ?? 0)
                .frame(height: control.number("height").map { CGFloat($0) })
        }
    }
}
