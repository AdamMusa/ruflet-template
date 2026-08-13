import SwiftUI
import UniformTypeIdentifiers

/// Apple-native port of Flet's `ReorderableListViewControl`.
@MainActor
public struct ReorderableListViewControl: View {
    @ObservedObject public var control: RufletControl
    @StateObject private var coordinator: RufletReorderCoordinator
    @State private var prototypeExtent: CGFloat?

    public init(control: RufletControl) {
        self.control = control
        _coordinator = StateObject(
            wrappedValue: RufletReorderCoordinator(
                initialIDs: control.children("controls").map(\.id)))
    }

    public var body: some View {
        LayoutControl(control: control) {
            notified(AnyView(ScrollableControl(
                control: control,
                scrollDirection: horizontal ? .horizontal : .vertical
            ) { list }))
        }
        .onAppear { coordinator.mount(control: control) }
        .onChange(of: control.children("controls").map(\.id)) {
            coordinator.synchronize(ids: $0)
        }
        .onDisappear { coordinator.unmount() }
    }

    private var list: AnyView {
        let scroll = ScrollView(horizontal ? .horizontal : .vertical, showsIndicators: showsIndicators) {
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
        if reverse {
            if let footer = control.buildWidget("footer") { footer }
            reorderableItems
            if let header = control.buildWidget("header") { header }
        } else {
            if let header = control.buildWidget("header") { header }
            reorderableItems
            if let footer = control.buildWidget("footer") { footer }
        }
    }

    @ViewBuilder
    private var reorderableItems: some View {
        ForEach(displayedEntries) { entry in
            item(entry.control, index: entry.logicalIndex)
        }
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
        .id(rufletReorderIdentity(child))
        .onDrop(
            of: [UTType.text],
            delegate: RufletReorderDropDelegate(
                targetID: child.id,
                coordinator: coordinator
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
        guard let id = coordinator.beginDragging(at: index) else { return NSItemProvider() }
        return NSItemProvider(object: NSString(string: String(id)))
    }

    private func notified(_ content: AnyView) -> AnyView {
        guard control.boolean("on_scroll", default: false) else { return content }
        return AnyView(ScrollNotificationControl(control: control) { content })
    }

    private var sourceControls: [RufletControl] { control.children("controls") }
    private var orderedControls: [RufletControl] {
        let indexed = Dictionary(uniqueKeysWithValues: sourceControls.map { ($0.id, $0) })
        return coordinator.orderedIDs.compactMap { indexed[$0] }
    }
    private var displayedEntries: [RufletReorderDisplayEntry] {
        let entries = orderedControls.enumerated().map {
            RufletReorderDisplayEntry(
                control: $0.element,
                logicalIndex: $0.offset,
                id: rufletReorderIdentity($0.element))
        }
        return reverse ? Array(entries.reversed()) : entries
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

/// Pinned `_buildItem` uses the user key's scalar value, falling back to the
/// child control ID. Keeping the scalar (rather than stringifying it) preserves
/// Flutter's distinction between `1`, `1.0`, `true`, and `"1"` ValueKeys.
@MainActor
func rufletReorderIdentity(_ child: RufletControl) -> ControlKeyValue {
    parseKey(child.value("key"))?.rawValue ?? .integer(child.id)
}

private struct RufletReorderDisplayEntry: Identifiable {
    let control: RufletControl
    let logicalIndex: Int
    let id: ControlKeyValue
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
    let coordinator: RufletReorderCoordinator

    func dropEntered(info: DropInfo) {
        withAnimation { coordinator.enter(targetID: targetID) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        coordinator.performDrop()
    }
}

/// Stateful half of pinned Flet's reorderable list. The Dart control keeps a
/// local child order, replaces it on every server update, and preserves the
/// native callback order (`start`, then `end`, then `reorder` when moved).
/// Keeping that contract out of the
/// DropDelegate also makes one native drag session own exactly one lifecycle.
@MainActor
final class RufletReorderCoordinator: ObservableObject {
    @Published private(set) var orderedIDs: [Int]

    private weak var control: RufletControl?
    private var updateListener: UUID?
    private var draggingID: Int?
    private var originalIndex: Int?

    init(initialIDs: [Int]) {
        orderedIDs = initialIDs
    }

    func mount(control: RufletControl) {
        if self.control !== control { unmount() }
        self.control = control
        synchronize(with: control)
        guard updateListener == nil else { return }
        updateListener = control.addListener { [weak self, weak control] in
            guard let self, let control else { return }
            synchronize(with: control)
        }
    }

    func unmount() {
        if let control, let updateListener {
            control.removeListener(updateListener)
        }
        updateListener = nil
        control = nil
        draggingID = nil
        originalIndex = nil
    }

    @discardableResult
    func beginDragging(at index: Int) -> Int? {
        guard let control, !control.disabled, orderedIDs.indices.contains(index) else {
            return nil
        }
        let id = orderedIDs[index]
        draggingID = id
        originalIndex = index
        control.triggerEvent("reorder_start", data: [
            "old_index": .int(Int64(index))
        ])
        return id
    }

    func enter(targetID: Int) {
        guard let draggingID, draggingID != targetID,
              let from = orderedIDs.firstIndex(of: draggingID),
              let to = orderedIDs.firstIndex(of: targetID) else { return }
        orderedIDs.move(
            fromOffsets: IndexSet(integer: from),
            toOffset: to > from ? to + 1 : to)
    }

    @discardableResult
    func performDrop() -> Bool {
        guard let control, let draggingID,
              let newIndex = orderedIDs.firstIndex(of: draggingID) else { return false }
        let oldIndex = originalIndex ?? newIndex
        // Flutter's SliverReorderableList reports its insertion index to
        // onReorderEnd before onReorder. Flet then adjusts a downward insertion
        // by one before mutating its local controls and emitting `reorder`.
        let insertionIndex = oldIndex < newIndex ? newIndex + 1 : newIndex
        control.triggerEvent("reorder_end", data: [
            "new_index": .int(Int64(insertionIndex))
        ])
        if oldIndex != insertionIndex {
            control.triggerEvent("reorder", data: [
                "old_index": .int(Int64(oldIndex)),
                "new_index": .int(Int64(newIndex)),
            ])
        }
        self.draggingID = nil
        originalIndex = nil
        return true
    }

    func synchronize(ids: [Int]) {
        orderedIDs = ids
        if let draggingID, !orderedIDs.contains(draggingID) {
            self.draggingID = nil
            originalIndex = nil
        }
    }

    private func synchronize(with control: RufletControl) {
        synchronize(ids: control.children("controls").map(\.id))
    }
}
