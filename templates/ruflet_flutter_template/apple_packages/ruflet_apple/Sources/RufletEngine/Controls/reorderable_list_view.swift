import SwiftUI
import UniformTypeIdentifiers

/// Apple-native port of Flet's `ReorderableListViewControl`.
@MainActor
public struct ReorderableListViewControl: View {
    @ObservedObject public var control: RufletControl
    @StateObject private var coordinator: RufletReorderCoordinator
    @State private var prototypeExtent: CGFloat?
    @State private var viewportExtent: CGFloat = 0

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
        let scroll = ScrollViewReader { proxy in
            ScrollView(horizontal ? .horizontal : .vertical, showsIndicators: showsIndicators) {
                listContent(proxy: proxy)
                    .padding(padding)
                    .background(alignment: .topLeading) { prototypeMeasurement }
                    .overlay(alignment: .topLeading) { RufletScrollViewportAttachment() }
            }
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { updateViewportExtent(geometry.size) }
                        .onChange(of: geometry.size) { updateViewportExtent($0) }
                }
            }
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
    private func listContent(proxy: ScrollViewProxy) -> some View {
        if horizontal {
            if buildControlsOnDemand {
                LazyHStack(spacing: 0) { contents(proxy: proxy) }
            } else {
                HStack(spacing: 0) { contents(proxy: proxy) }
            }
        } else if buildControlsOnDemand {
            LazyVStack(spacing: 0) { contents(proxy: proxy) }
        } else {
            VStack(spacing: 0) { contents(proxy: proxy) }
        }
    }

    @ViewBuilder
    private func contents(proxy: ScrollViewProxy) -> some View {
        anchorSpacer
        if reverse {
            if let footer = control.buildWidget("footer") { footer }
            reorderableItems(proxy: proxy)
            if let header = control.buildWidget("header") { header }
        } else {
            if let header = control.buildWidget("header") { header }
            reorderableItems(proxy: proxy)
            if let footer = control.buildWidget("footer") { footer }
        }
    }

    @ViewBuilder
    private func reorderableItems(proxy: ScrollViewProxy) -> some View {
        ForEach(Array(prefetchGroups.enumerated()), id: \.offset) { _, group in
            if horizontal {
                HStack(spacing: 0) {
                    entries(group, proxy: proxy)
                }
            } else {
                VStack(spacing: 0) {
                    entries(group, proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    private func entries(_ entries: [RufletReorderDisplayEntry], proxy: ScrollViewProxy) -> some View {
        ForEach(entries) { entry in
            item(entry.control, index: entry.logicalIndex, proxy: proxy)
        }
    }

    private func item(_ child: RufletControl, index: Int, proxy: ScrollViewProxy) -> some View {
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
                coordinator: coordinator,
                presentation: presentation,
                displayedIDs: displayedEntries.map(\.control.id),
                itemExtent: effectiveItemExtent ?? 44,
                horizontal: horizontal,
                scroll: { id, anchor, duration in
                    guard let target = displayedEntries.first(where: { $0.control.id == id }) else {
                        return
                    }
                    withAnimation(.linear(duration: duration)) {
                        proxy.scrollTo(rufletReorderIdentity(target.control), anchor: anchor)
                    }
                }
            )
        )
    }

    @ViewBuilder
    private var anchorSpacer: some View {
        let extent = presentation.anchorInset(viewportExtent: viewportExtent)
        if extent > 0 {
            Color.clear.frame(
                width: horizontal ? extent : 0,
                height: horizontal ? 0 : extent)
                .accessibilityHidden(true)
        }
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

    private var presentation: RufletReorderListPresentation {
        RufletReorderListPresentation(control: control)
    }
    private var prefetchGroups: [[RufletReorderDisplayEntry]] {
        displayedEntries.chunked(
            count: presentation.prefetchGroupSize(itemExtent: effectiveItemExtent ?? 44))
    }

    private func updateViewportExtent(_ size: CGSize) {
        let next = horizontal ? size.width : size.height
        if next.isFinite, next >= 0, viewportExtent != next { viewportExtent = next }
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

@MainActor
struct RufletReorderListPresentation {
    let anchor: CGFloat
    let cacheExtent: CGFloat?
    let autoScrollerVelocityScalar: Double?

    init(control: RufletControl) {
        anchor = CGFloat(min(max(control.number("anchor", default: 0) ?? 0, 0), 1))
        cacheExtent = control.number("cache_extent").map { CGFloat(max($0, 0)) }
        if let scalar = control.number("auto_scroller_velocity_scalar"), scalar > 0 {
            autoScrollerVelocityScalar = scalar
        } else {
            autoScrollerVelocityScalar = nil
        }
    }

    func anchorInset(viewportExtent: CGFloat) -> CGFloat {
        max(viewportExtent, 0) * anchor
    }

    func prefetchGroupSize(itemExtent: CGFloat) -> Int {
        guard let cacheExtent, cacheExtent > 0, itemExtent > 0 else { return 1 }
        return max(Int(ceil(cacheExtent / itemExtent)) + 1, 1)
    }
}

private extension Array {
    func chunked(count: Int) -> [[Element]] {
        guard count > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: self.count, by: count).map {
            Array(self[$0..<Swift.min($0 + count, self.count)])
        }
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
    let presentation: RufletReorderListPresentation
    let displayedIDs: [Int]
    let itemExtent: CGFloat
    let horizontal: Bool
    let scroll: (Int, UnitPoint, Double) -> Void

    func dropEntered(info: DropInfo) {
        withAnimation { coordinator.enter(targetID: targetID) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let request = RufletReorderAutoScrollPolicy.request(
            targetID: targetID,
            location: info.location,
            itemExtent: itemExtent,
            horizontal: horizontal,
            displayedIDs: displayedIDs,
            velocityScalar: presentation.autoScrollerVelocityScalar)
        {
            scroll(request.targetID, request.anchor, request.duration)
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        coordinator.performDrop()
    }
}

struct RufletReorderAutoScrollRequest: Equatable {
    let targetID: Int
    let anchor: UnitPoint
    let duration: Double
}

struct RufletReorderAutoScrollPolicy {
    static let defaultVelocityScalar = 50.0

    static func request(
        targetID: Int,
        location: CGPoint,
        itemExtent: CGFloat,
        horizontal: Bool,
        displayedIDs: [Int],
        velocityScalar: Double?
    ) -> RufletReorderAutoScrollRequest? {
        guard itemExtent > 0,
              let index = displayedIDs.firstIndex(of: targetID) else { return nil }
        let position = horizontal ? location.x : location.y
        let edge = min(max(itemExtent * 0.22, 10), itemExtent / 2)
        let direction: Int
        let anchor: UnitPoint
        let overscroll: CGFloat
        if position < edge {
            direction = -1
            anchor = horizontal ? .leading : .top
            overscroll = edge - position
        } else if position > itemExtent - edge {
            direction = 1
            anchor = horizontal ? .trailing : .bottom
            overscroll = position - (itemExtent - edge)
        } else {
            return nil
        }
        let targetIndex = index + direction
        guard displayedIDs.indices.contains(targetIndex) else { return nil }
        let scalar = max(velocityScalar ?? defaultVelocityScalar, 1)
        let velocity = max(Double(overscroll) * scalar, 1)
        return RufletReorderAutoScrollRequest(
            targetID: displayedIDs[targetIndex],
            anchor: anchor,
            duration: max(0.016, Double(itemExtent) / velocity))
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
