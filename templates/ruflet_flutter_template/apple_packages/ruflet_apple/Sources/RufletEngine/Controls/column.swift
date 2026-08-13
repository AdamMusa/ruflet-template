import SwiftUI

@MainActor
public struct ColumnControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            scrollNotified(scrollable(content))
        }
    }

    private var content: AnyView {
        let spacing = control.number("spacing") ?? 10
        let views = control.buildWidgets("controls")
        if control.boolean("wrap", default: false) {
            return AnyView(RufletFlowLayout(
                axis: .vertical,
                spacing: spacing,
                runSpacing: control.number("run_spacing") ?? 10,
                children: views
            ))
        }
        return AnyView(VStack(alignment: horizontalAlignment, spacing: spacing) {
            ForEach(Array(control.children("controls").enumerated()), id: \.element.id) { _, child in
                ControlWidget(control: child)
            }
        }
        .frame(maxHeight: control.boolean("tight", default: false) ? nil : .infinity, alignment: verticalAlignment))
    }

    private func scrollable(_ content: AnyView) -> AnyView {
        AnyView(ScrollableControl(
            control: control,
            scrollDirection: control.boolean("wrap", default: false) ? .horizontal : .vertical,
            wrapIntoScrollableView: true
        ) { content })
    }

    private func scrollNotified(_ content: AnyView) -> AnyView {
        guard control.boolean("on_scroll", default: false) else { return content }
        return AnyView(ScrollNotificationControl(control: control) { content })
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch control.string("horizontal_alignment")?.lowercased() {
        case "end": .trailing
        case "center": .center
        default: .leading
        }
    }

    private var verticalAlignment: Alignment {
        switch control.string("alignment")?.lowercased() {
        case "end": .bottom
        case "center": .center
        default: .top
        }
    }
}
