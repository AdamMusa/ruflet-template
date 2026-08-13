import SwiftUI

@MainActor
public struct ProgressRingControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        let progress = RufletCircularProgress(
            value: control.number("value"),
            color: parseColor(control.string("color")) ?? .accentColor,
            padding: parsePadding(control.dynamicValue("padding")) ?? EdgeInsets(),
            background: parseColor(control.string("bgcolor")) ?? .clear,
            label: control.string("semantics_label") ?? "",
            semanticsValue: control.number("semantics_value").map { String($0) } ?? ""
        )
        LayoutControl(control: control, child: progress)
    }
}

private struct RufletCircularProgress: View {
    let value: Double?
    let color: Color
    let padding: EdgeInsets
    let background: Color
    let label: String
    let semanticsValue: String

    var body: some View {
        indicator
            .progressViewStyle(.circular)
            .tint(color)
            .padding(padding)
            .background(background)
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
