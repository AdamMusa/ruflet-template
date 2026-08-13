import SwiftUI

/// Apple-native port of Flet's `GridViewControl`.
@MainActor
public struct GridViewControl: View {
    @ObservedObject public var control: RufletControl

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        LayoutControl(control: control) {
            notified(grid)
        }
    }

    private var grid: AnyView {
        let scroll = ScrollView(horizontal ? .horizontal : .vertical, showsIndicators: showsIndicators) {
            gridContent
                .padding(padding)
        }

        if clipBehavior == "none" {
            return AnyView(scroll)
        }
        return AnyView(scroll.clipped(antialiased: clipBehavior == "antialias" || clipBehavior == "antialiaswithsavelayer"))
    }

    @ViewBuilder
    private var gridContent: some View {
        if horizontal {
            LazyHGrid(rows: tracks, spacing: spacing) {
                items
            }
        } else {
            LazyVGrid(columns: tracks, spacing: spacing) {
                items
            }
        }
    }

    @ViewBuilder
    private var items: some View {
        ForEach(orderedControls, id: \.id) { child in
            ControlWidget(control: child)
                .aspectRatio(horizontal ? 1 / childAspectRatio : childAspectRatio, contentMode: .fit)
                .id(child.string("key") ?? String(child.id))
        }
    }

    private func notified(_ content: AnyView) -> AnyView {
        guard control.boolean("on_scroll", default: false) else { return content }
        return AnyView(ScrollNotificationControl(control: control) { content })
    }

    private var tracks: [GridItem] {
        let item = GridItem(
            maxExtent.map { .adaptive(minimum: CGFloat($0), maximum: CGFloat($0)) }
                ?? .flexible(minimum: 0),
            spacing: runSpacing,
            alignment: .center
        )
        if maxExtent != nil {
            return [item]
        }
        return Array(repeating: item, count: max(runsCount, 1))
    }

    private var orderedControls: [RufletControl] {
        let controls = control.children("controls")
        return reverse ? Array(controls.reversed()) : controls
    }

    private var horizontal: Bool { control.boolean("horizontal", default: false) }
    private var reverse: Bool { control.boolean("reverse", default: false) }
    private var runsCount: Int { control.integer("runs_count", default: 1) ?? 1 }
    private var maxExtent: Double? { control.number("max_extent") }
    private var spacing: CGFloat { CGFloat(control.number("spacing", default: 10) ?? 10) }
    private var runSpacing: CGFloat { CGFloat(control.number("run_spacing", default: 10) ?? 10) }
    private var childAspectRatio: CGFloat { CGFloat(control.number("child_aspect_ratio", default: 1) ?? 1) }
    private var padding: EdgeInsets { parsePadding(control.dynamicValue("padding")) ?? EdgeInsets() }
    private var clipBehavior: String { control.string("clip_behavior", default: "hardEdge")!.lowercased() }

    private var showsIndicators: Bool {
        let mode = parseEnum(RufletScrollMode.self, control.string("scroll"), RufletScrollMode.none)!
        return mode != .none && mode != .hidden
    }
}
