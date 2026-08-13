import SwiftUI

@MainActor
public struct ProgressBarControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        let progress = RufletLinearProgress(
            value: control.number("value"),
            color: parseColor(control.string("color")) ?? .accentColor,
            height: control.number("bar_height").map { CGFloat($0) },
            background: parseColor(control.string("bgcolor")) ?? .clear,
            radius: parseBorderRadius(control.dynamicValue("border_radius"))?.uniform ?? 0,
            label: control.string("semantics_label") ?? "",
            semanticsValue: control.number("semantics_value").map { String($0) } ?? ""
        )
        LayoutControl(control: control, child: progress)
    }
}

private struct RufletLinearProgress: View {
    let value: Double?
    let color: Color
    let height: CGFloat?
    let background: Color
    let radius: Double
    let label: String
    let semanticsValue: String

    var body: some View {
        indicator
            .progressViewStyle(.linear)
            .tint(color)
            .frame(height: height)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .accessibilityLabel(label)
            .accessibilityValue(semanticsValue)
    }

    @ViewBuilder
    private var indicator: some View {
        if let value {
            ProgressView(value: value, total: 1.0)
        } else {
            ProgressView()
        }
    }
}
