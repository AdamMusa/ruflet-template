import SwiftUI
import UniformTypeIdentifiers

/// Apple-native port of Flet's `ReorderableListViewControl`.
@MainActor
public struct ReorderableListViewControl: View {
    @ObservedObject public var control: RufletControl
    @State private var orderedIDs: [Int]
    @State private var draggingID: Int?
    @State private var originalIndex: Int?
    @State private var prototypeExtent: CGFloat?

    public init(control: RufletControl) {
        self.control = control
        _orderedIDs = State(initialValue: control.children("controls").map(\.id))
    }

    public var body: some View {
        LayoutControl(control: control) {
            notified(list)
        }
        .onChange(of: control.children("controls").map(\.id)) { orderedIDs = $0 }
    }

    private var list: AnyView {
        let scroll = ScrollView(horizontal ? .horizontal : .vertical, showsIndicators: showsIndicators) {
            listContent
                .padding(padding)
                .background(alignment: .topLeading) { prototypeMeasurement }
        }
        if clipBehavior == "none" {
            return AnyView(scroll)
        }
        return AnyView(scroll.clipped(antialiased: clipBehavior == "antialias" || clipBehavior == "antialiaswithsavelayer"))
    }

    @ViewBuilder
    private var prototypeMeasurement: some View {
        if control.number("item_extent") == nil,
           control.boolean("first_item_prototype", default: false),
           let prototype = sourceControls.first {
            ControlWidget(control: prototype)
                .fixedSize()
                .hidden()
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: RufletReorderPrototypeExtentKey.self,
                            value: horizontal ? proxy.size.width : proxy.size.height
                        )
                    }
                }
                .onPreferenceChange(RufletReorderPrototypeExtentKey.self) { prototypeExtent = $0 }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if horizontal {
            if buildControlsOnDemand {
                LazyHStack(spacing: 0) { contents }
            } else {
                HStack(spacing: 0) { contents }
            }
        } else if buildControlsOnDemand {
            LazyVStack(spacing: 0) { contents }
        } else {
            VStack(spacing: 0) { contents }
        }
    }

    @ViewBuilder
    private var contents: some View {
        if let header = control.buildWidget("header") { header }
        ForEach(Array(displayedControls.enumerated()), id: \.element.id) { _, child in
            let logicalIndex = orderedControls.firstIndex { $0.id == child.id }!
            item(child, index: logicalIndex)
        }
        if let footer = control.buildWidget("footer") { footer }
    }

    private func item(_ child: RufletControl, index: Int) -> some View {
        let actions = RufletReorderItemActions(beginDragging: beginDragging)
        return ReorderableItemScope(index: index, actions: actions) {
            defaultDragHandle(for: child, index: index)
        }
        .frame(
            width: horizontal ? effectiveItemExtent : nil,
            height: horizontal ? nil : effectiveItemExtent
        )
        .id(child.string("key") ?? String(child.id))
        .onDrop(
            of: [UTType.text],
            delegate: RufletReorderDropDelegate(
                targetID: child.id,
                orderedIDs: $orderedIDs,
                draggingID: $draggingID,
                originalIndex: $originalIndex,
                control: control
            )
        )
    }

    @ViewBuilder
    private func defaultDragHandle(for child: RufletControl, index: Int) -> some View {
        if showDefaultDragHandles, !control.disabled {
            #if os(iOS)
            ControlWidget(control: child)
                .onDrag { beginDragging(index) }
                .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor")))
            #elseif os(macOS)
            ZStack(alignment: horizontal ? .bottom : .trailing) {
                ControlWidget(control: child)
                Image(systemName: "line.3.horizontal")
                    .padding(8)
                    .contentShape(Rectangle())
                    .onDrag { beginDragging(index) }
                    .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor", default: "grab")))
            }
            #endif
        } else {
            ControlWidget(control: child)
        }
    }

    private func beginDragging(_ index: Int) -> NSItemProvider {
        guard orderedControls.indices.contains(index) else { return NSItemProvider() }
        let id = orderedControls[index].id
        draggingID = id
        originalIndex = index
        control.triggerEvent("reorder_start", data: ["old_index": .int(Int64(index))])
        return NSItemProvider(object: NSString(string: String(id)))
    }

    private func notified(_ content: AnyView) -> AnyView {
        guard control.boolean("on_scroll", default: false) else { return content }
        return AnyView(ScrollNotificationControl(control: control) { content })
    }

    private var sourceControls: [RufletControl] { control.children("controls") }
    private var orderedControls: [RufletControl] {
        let indexed = Dictionary(uniqueKeysWithValues: sourceControls.map { ($0.id, $0) })
        return orderedIDs.compactMap { indexed[$0] }
    }
    private var displayedControls: [RufletControl] {
        reverse ? Array(orderedControls.reversed()) : orderedControls
    }

    private var horizontal: Bool { control.boolean("horizontal", default: false) }
    private var reverse: Bool { control.boolean("reverse", default: false) }
    private var buildControlsOnDemand: Bool { control.boolean("build_controls_on_demand", default: true) }
    private var showDefaultDragHandles: Bool { control.boolean("show_default_drag_handles", default: true) }
    private var padding: EdgeInsets { parsePadding(control.dynamicValue("padding")) ?? EdgeInsets() }
    private var clipBehavior: String { control.string("clip_behavior", default: "hardEdge")!.lowercased() }
    private var effectiveItemExtent: CGFloat? {
        if let extent = control.number("item_extent") { return CGFloat(extent) }
        return prototypeExtent
    }
    private var showsIndicators: Bool {
        let mode = parseEnum(RufletScrollMode.self, control.string("scroll"), RufletScrollMode.none)!
        return mode != .none && mode != .hidden
    }
}

private struct RufletReorderPrototypeExtentKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

@MainActor
private struct RufletReorderDropDelegate: DropDelegate {
    let targetID: Int
    @Binding var orderedIDs: [Int]
    @Binding var draggingID: Int?
    @Binding var originalIndex: Int?
    let control: RufletControl

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID,
              let from = orderedIDs.firstIndex(of: draggingID),
              let to = orderedIDs.firstIndex(of: targetID) else { return }
        withAnimation {
            orderedIDs.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingID,
              let newIndex = orderedIDs.firstIndex(of: draggingID) else { return false }
        let oldIndex = originalIndex ?? newIndex
        control.triggerEvent("reorder", data: [
            "old_index": .int(Int64(oldIndex)),
            "new_index": .int(Int64(newIndex)),
        ])
        control.triggerEvent("reorder_end", data: ["new_index": .int(Int64(newIndex))])
        self.draggingID = nil
        originalIndex = nil
        return true
    }
}
