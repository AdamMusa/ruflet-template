import SwiftUI

/// Apple-native port of Flet's `ListViewControl`.
@MainActor
public struct ListViewControl: View {
    @ObservedObject public var control: RufletControl
    @State private var prototypeExtent: CGFloat?

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        LayoutControl(control: control) {
            notified(AnyView(ScrollableControl(
                control: control,
                scrollDirection: horizontal ? .horizontal : .vertical
            ) { list }))
        }
    }

    private var list: AnyView {
        let axis: Axis.Set = horizontal ? .horizontal : .vertical
        let scroll = ScrollView(axis, showsIndicators: showsIndicators) {
            listContent
                .padding(padding)
                .background(alignment: .topLeading) { prototypeMeasurement }
                .overlay(alignment: .topLeading) { RufletScrollViewportAttachment() }
        }

        if clipBehavior == "none" {
            return AnyView(scroll)
        }
        return AnyView(scroll.clipped(antialiased: clipBehavior == "antialias" || clipBehavior == "antialiaswithsavelayer"))
    }

    @ViewBuilder
    private var listContent: some View {
        if horizontal {
            if buildControlsOnDemand {
                LazyHStack(spacing: 0) { listItems }
            } else {
                HStack(spacing: 0) { listItems }
            }
        } else if buildControlsOnDemand {
            LazyVStack(spacing: 0) { listItems }
        } else {
            VStack(spacing: 0) { listItems }
        }
    }

    @ViewBuilder
    private var listItems: some View {
        ForEach(Array(orderedControls.enumerated()), id: \.element.id) { index, child in
            item(child)
            if index < orderedControls.count - 1, spacing > 0 {
                separator
            }
        }
    }

    private func item(_ child: RufletControl) -> some View {
        ControlWidget(control: child)
            .frame(
                width: horizontal ? effectiveItemExtent : nil,
                height: horizontal ? nil : effectiveItemExtent
            )
            .id(child.string("key") ?? String(child.id))
    }

    @ViewBuilder
    private var prototypeMeasurement: some View {
        if spacing == 0, itemExtent == nil, let prototypeControl {
            ControlWidget(control: prototypeControl)
                .fixedSize()
                .hidden()
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: RufletListPrototypeExtentKey.self,
                            value: horizontal ? proxy.size.width : proxy.size.height
                        )
                    }
                }
                .onPreferenceChange(RufletListPrototypeExtentKey.self) { prototypeExtent = $0 }
        }
    }

    @ViewBuilder
    private var separator: some View {
        if horizontal {
            if dividerThickness == 0 {
                Color.clear.frame(width: spacing)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: dividerThickness)
                    .frame(width: spacing)
            }
        } else if dividerThickness == 0 {
            Color.clear.frame(height: spacing)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: dividerThickness)
                .frame(height: spacing)
        }
    }

    private func notified(_ content: AnyView) -> AnyView {
        guard control.boolean("on_scroll", default: false) else { return content }
        return AnyView(ScrollNotificationControl(control: control) { content })
    }

    private var orderedControls: [RufletControl] {
        let controls = control.children("controls")
        return reverse ? Array(controls.reversed()) : controls
    }

    private var horizontal: Bool { control.boolean("horizontal", default: false) }
    private var reverse: Bool { control.boolean("reverse", default: false) }
    private var spacing: CGFloat { CGFloat(control.number("spacing", default: 0) ?? 0) }
    private var dividerThickness: CGFloat { CGFloat(control.number("divider_thickness", default: 0) ?? 0) }
    private var itemExtent: Double? { control.number("item_extent") }
    private var effectiveItemExtent: CGFloat? {
        guard spacing == 0 else { return nil }
        return itemExtent.map { CGFloat($0) } ?? prototypeExtent
    }
    private var prototypeControl: RufletControl? {
        if let prototype = control.child("prototype_item") { return prototype }
        if control.boolean("first_item_prototype", default: false) { return control.children("controls").first }
        return nil
    }
    private var buildControlsOnDemand: Bool { control.boolean("build_controls_on_demand", default: true) }
    private var padding: EdgeInsets { parsePadding(control.dynamicValue("padding")) ?? EdgeInsets() }
    private var clipBehavior: String { control.string("clip_behavior", default: "hardEdge")!.lowercased() }

    private var showsIndicators: Bool {
        let mode = parseEnum(RufletScrollMode.self, control.string("scroll"), RufletScrollMode.none)!
        return mode != .none && mode != .hidden
    }
}

private struct RufletListPrototypeExtentKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}
