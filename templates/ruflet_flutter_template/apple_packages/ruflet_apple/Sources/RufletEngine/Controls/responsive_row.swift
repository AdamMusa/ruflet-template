import SwiftUI

/// Apple-native port of Flet's `ResponsiveRowControl`.
@MainActor
public struct ResponsiveRowControl: View {
    @ObservedObject public var control: RufletControl

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        LayoutControl(control: control) {
            GeometryReader { proxy in
                responsiveContent(width: proxy.size.width)
            }
        }
    }

    private func responsiveContent(width: CGFloat) -> some View {
        let columns = active(control.dynamicValue("columns"), default: 12, width: width)
        let spacing = active(control.dynamicValue("spacing"), default: 10, width: width)
        let runSpacing = active(control.dynamicValue("run_spacing"), default: 10, width: width)
        let columnWidth = columns > 0
            ? (width - spacing * max(columns - 1, 0)) / columns
            : 0
        let children = control.children("controls")
        let spans = children.map { max(active($0.dynamicValue("col"), default: 12, width: width), 0) }
        let views = zip(children, spans).map { child, span in
            AnyView(ControlWidget(control: child)
                .frame(width: max(columnWidth * span + spacing * max(span - 1, 0), 0)))
        }

        if spans.reduce(0, +) > columns {
            return AnyView(RufletFlowLayout(
                axis: .horizontal,
                spacing: Double(max(spacing - 0.1, 0)),
                runSpacing: Double(runSpacing),
                children: views
            ))
        }

        return AnyView(HStack(alignment: verticalAlignment, spacing: max(spacing - 0.1, 0)) {
            ForEach(Array(views.enumerated()), id: \.offset) { _, view in view }
        }
        .frame(maxWidth: .infinity, alignment: swiftUIAlignment))
    }

    private func active(_ value: Any?, default defaultValue: Double, width: CGFloat) -> CGFloat {
        CGFloat(getBreakpointNumber(
            parseResponsiveNumber(value, defaultValue),
            width: Double(width),
            breakpoints: breakpoints
        ))
    }

    private var breakpoints: [String: Double] {
        let defaults = [
            "xs": 0.0, "sm": 576.0, "md": 768.0,
            "lg": 992.0, "xl": 1200.0, "xxl": 1400.0,
        ]
        guard let raw = rufletDictionary(control.dynamicValue("breakpoints")) else { return defaults }
        var result: [String: Double] = [:]
        for (key, value) in raw {
            if let number = parseDouble(value) { result[key] = number }
        }
        return result
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch control.string("alignment")?.lowercased() {
        case "end": .trailing
        case "center", "spacearound", "spacebetween", "spaceevenly": .center
        default: .leading
        }
    }

    private var verticalAlignment: VerticalAlignment {
        switch control.string("vertical_alignment")?.lowercased() {
        case "end": .bottom
        case "center": .center
        default: .top
        }
    }

    private var swiftUIAlignment: Alignment {
        switch horizontalAlignment {
        case .trailing: .trailing
        case .center: .center
        default: .leading
        }
    }
}
