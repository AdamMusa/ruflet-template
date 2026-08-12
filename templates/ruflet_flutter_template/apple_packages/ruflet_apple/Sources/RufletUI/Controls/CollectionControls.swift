import RufletEngine
import RufletProtocol
import SwiftUI
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// `ListView` — a scrolling list, horizontal when `horizontal` is set.
///
/// `on_scroll` reports offsets the way Flet does, so a Ruby handler watching
/// for the end of the list still fires.
struct ListViewControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var measuredPrototypeExtent: CGFloat?
  @StateObject private var scrollDriver = CollectionNativeScrollDriver()

  init(node: ControlNode) {
    self.node = node
    _measuredPrototypeExtent = State(initialValue: nil)
  }

  var body: some View {
    let config = CollectionDefaults.listView(node)
    let horizontal = config.horizontal
    let axis: LayoutAxis = horizontal ? .horizontal : .vertical
    let children = CollectionVisibleChildren.ids(
      node.childIDs, in: store.nodes, reverse: config.reverse)
    let explicitPrototype = CollectionVisibleChildren.visibleID(
      config.prototypeItemID, in: store.nodes)
    let prototypeID = explicitPrototype ?? (config.firstItemPrototype ? children.first : nil)
    let usesPrototype = config.spacing == 0 && prototypeID != nil

    ScrollView(
      horizontal ? .horizontal : .vertical,
      showsIndicators: config.showsIndicators
    ) {
      Group {
        if horizontal, config.lazy {
          LazyHStack(spacing: 0) {
            rows(axis: axis, usesPrototype: usesPrototype, children: children,
              explicitPrototypeID: explicitPrototype)
          }
        } else if horizontal {
          HStack(spacing: 0) {
            rows(axis: axis, usesPrototype: usesPrototype, children: children,
              explicitPrototypeID: explicitPrototype)
          }
        } else if config.lazy {
          LazyVStack(spacing: 0) {
            rows(axis: axis, usesPrototype: usesPrototype, children: children,
              explicitPrototypeID: explicitPrototype)
          }
        } else {
          VStack(spacing: 0) {
            rows(axis: axis, usesPrototype: usesPrototype, children: children,
              explicitPrototypeID: explicitPrototype)
          }
        }
      }
      .padding(config.padding)
      .modifier(CollectionClip(behavior: config.clipBehavior))
      .overlay(alignment: .topLeading) {
        if usesPrototype, let prototype = explicitPrototype {
          ControlView(id: prototype, axis: axis)
            .fixedSize()
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .modifier(CollectionPrototypeMeasure(horizontal: horizontal))
        }
      }
      .modifier(CollectionScrollContentProbe(node: node, horizontal: horizontal))
      .background(CollectionNativeScrollLocator(driver: scrollDriver))
      .accessibilityElement(children: .contain)
      .accessibilityValue(
        node.int("semantic_child_count").map { "\($0)" } ?? "")
    }
    .onPreferenceChange(CollectionPrototypeExtentKey.self) { extent in
      guard extent > 0, usesPrototype else { return }
      measuredPrototypeExtent = extent
    }
    // SwiftUI owns its own lazy-container prefetch window; reading the Flet
    // value documents the exact native limitation without treating it as row
    // geometry (the previous implementation incorrectly did so).
    .onAppear { _ = config.cacheExtent }
    .modifier(CollectionAutoScroll(node: node, horizontal: horizontal))
    .modifier(CollectionScrollCommands(
      node: node, horizontal: horizontal, driver: scrollDriver))
    .modifier(CollectionScrollReporter(node: node, horizontal: horizontal, events: events))
  }

  /// `divider_thickness` puts a rule between items — the one place a Flet list
  /// differs from a plain stack of children.
  @ViewBuilder
  private func rows(
    axis: LayoutAxis, usesPrototype: Bool, children: [Int], explicitPrototypeID: Int?
  ) -> some View {
    let config = CollectionDefaults.listView(node)
    let spacing = config.spacing
    // Flet deliberately ignores item/prototype extents when separators are
    // enabled because ListView.separated has no itemExtent/prototypeItem.
    let itemExtent = measuredPrototypeExtent ?? config.itemExtent

    ForEach(children.indices, id: \.self) { index in
      if spacing > 0, index > 0 {
        CollectionListSeparator(
          horizontal: axis == .horizontal,
          extent: spacing,
          thickness: config.dividerThickness,
          color: MaterialPalette.color(node.string("divider_color")))
      }
      ControlView(id: children[index], axis: axis)
        .modifier(CollectionPrototypeMeasure(
          enabled: usesPrototype && explicitPrototypeID == nil && index == 0,
          horizontal: axis == .horizontal))
        .frame(
          width: axis == .horizontal ? itemExtent : nil,
          height: axis == .vertical ? itemExtent : nil)
        .id(children[index])
    }
  }
}

/// `GridView` — a wrapping grid with either a fixed column count
/// (`runs_count`) or a maximum item extent, the two modes Flet exposes.
struct GridViewControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @StateObject private var scrollDriver = CollectionNativeScrollDriver()

  var body: some View {
    let config = CollectionDefaults.gridView(node)
    GeometryReader { proxy in
      ScrollView(config.horizontal ? .horizontal : .vertical,
        showsIndicators: config.showsIndicators) {
        Group {
          if config.horizontal {
            LazyHGrid(
              rows: rows(spacing: config.runSpacing, availableExtent: proxy.size.height),
              spacing: config.spacing
            ) {
              gridChildren
            }
          } else {
            LazyVGrid(
              columns: columns(spacing: config.runSpacing, availableExtent: proxy.size.width),
              spacing: config.spacing
            ) {
              gridChildren
            }
          }
        }
        .padding(config.padding)
        .modifier(CollectionClip(behavior: config.clipBehavior))
        .accessibilityElement(children: .contain)
        .accessibilityValue(node.int("semantic_child_count").map { "\($0)" } ?? "")
        .modifier(CollectionScrollContentProbe(node: node, horizontal: config.horizontal))
        .background(CollectionNativeScrollLocator(driver: scrollDriver))
      }
    }
    // Native lazy grids choose their own prefetch window. `cache_extent`
    // remains a consumed Flet contract value but must not change the visible
    // grid's minimum height.
    .onAppear { _ = config.cacheExtent }
    .modifier(CollectionAutoScroll(node: node, horizontal: config.horizontal))
    .modifier(CollectionScrollCommands(
      node: node, horizontal: config.horizontal, driver: scrollDriver))
    .modifier(CollectionScrollReporter(node: node, horizontal: config.horizontal, events: events))
  }

  @ViewBuilder
  private var gridChildren: some View {
    let config = CollectionDefaults.gridView(node)
    let ids = CollectionVisibleChildren.ids(
      node.childIDs, in: store.nodes, reverse: config.reverse)
    ForEach(ids, id: \.self) { childID in
      ControlView(id: childID, axis: .none)
        .aspectRatio(config.childAspectRatio, contentMode: .fit)
        .id(childID)
    }
  }

  private func columns(spacing: CGFloat, availableExtent: CGFloat) -> [GridItem] {
    let config = CollectionDefaults.gridView(node)
    let count = CollectionGridGeometry.crossAxisCount(
      availableExtent: availableExtent,
      spacing: spacing,
      runsCount: config.runsCount,
      maxExtent: config.maxExtent)
    return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
  }

  private func rows(spacing: CGFloat, availableExtent: CGFloat) -> [GridItem] {
    let config = CollectionDefaults.gridView(node)
    let count = CollectionGridGeometry.crossAxisCount(
      availableExtent: availableExtent,
      spacing: spacing,
      runsCount: config.runsCount,
      maxExtent: config.maxExtent)
    return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
  }
}

/// Flutter's `SliverGridDelegateWithMaxCrossAxisExtent` treats `max_extent`
/// as a maximum, not an adaptive minimum. SwiftUI's `.adaptive(minimum:)`
/// therefore produces the opposite result on a phone (one oversized column
/// where Flutter creates two or more). Resolve the same count explicitly and
/// keep fixed `runs_count` behavior when no maximum is supplied.
enum CollectionGridGeometry {
  static func crossAxisCount(
    availableExtent: CGFloat,
    spacing: CGFloat,
    runsCount: Int,
    maxExtent: CGFloat?
  ) -> Int {
    guard let maxExtent else { return max(runsCount, 1) }
    let usableExtent = max(availableExtent, 0)
    let divisor = max(maxExtent + spacing, 1)
    return max(Int(ceil((usableExtent + spacing) / divisor)), 1)
  }
}

/// Flet's `children("controls")` and `buildWidget("prototype_item")` omit
/// invisible controls before list/grid construction. Filtering at the native
/// collection boundary also keeps separators, reversal and prototype choice
/// indexed against the same visible sequence as Flutter.
enum CollectionVisibleChildren {
  static func ids(
    _ ids: [Int], in nodes: [Int: ControlNode], reverse: Bool = false
  ) -> [Int] {
    let visible = ids.filter { id in
      nodes[id].map { $0.bool("visible") != false } == true
    }
    return reverse ? Array(visible.reversed()) : visible
  }

  static func visibleID(_ id: Int?, in nodes: [Int: ControlNode]) -> Int? {
    guard let id, nodes[id].map({ $0.bool("visible") != false }) == true else { return nil }
    return id
  }
}

/// `ReorderableListView` — a list whose rows the user can drag into a new
/// order. The resulting `reorder` event carries `old_index`/`new_index`, which
/// is what Flet's control reports.
struct ReorderableListControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var orderedIDs: [Int]
  @State private var dragOrigin: Int?
  @State private var draggedID: Int?
  @State private var measuredPrototypeExtent: CGFloat?

  init(node: ControlNode) {
    self.node = node
    // The store is not available during init, but the named slot already
    // excludes header/footer. Visibility is reconciled when body mounts.
    _orderedIDs = State(initialValue: node.controlIDs(forKey: "controls"))
    _measuredPrototypeExtent = State(initialValue: nil)
  }

  var body: some View {
    let config = CollectionDefaults.reorderableListView(node)
    let axis: LayoutAxis = config.horizontal ? .horizontal : .vertical
    let visibleIDs = ReorderableListParity.visibleControlIDs(node, in: store.nodes)
    let effectiveOrder = ReorderableListParity.reconciledOrder(orderedIDs, with: visibleIDs)
    let headerID = CollectionVisibleChildren.visibleID(config.headerID, in: store.nodes)
    let footerID = CollectionVisibleChildren.visibleID(config.footerID, in: store.nodes)
    ScrollView(
      config.horizontal ? .horizontal : .vertical,
      showsIndicators: config.showsIndicators
    ) {
      Group {
        if config.horizontal, config.lazy {
          LazyHStack(spacing: 0) {
            content(
              config: config, axis: axis, ids: effectiveOrder,
              headerID: headerID, footerID: footerID)
          }
        } else if config.horizontal {
          HStack(spacing: 0) {
            content(
              config: config, axis: axis, ids: effectiveOrder,
              headerID: headerID, footerID: footerID)
          }
        } else if config.lazy {
          LazyVStack(spacing: 0) {
            content(
              config: config, axis: axis, ids: effectiveOrder,
              headerID: headerID, footerID: footerID)
          }
        } else {
          VStack(spacing: 0) {
            content(
              config: config, axis: axis, ids: effectiveOrder,
              headerID: headerID, footerID: footerID)
          }
        }
      }
      .padding(config.padding)
      .modifier(PageReverse(horizontal: config.horizontal, enabled: config.reverse))
      .modifier(CollectionScrollContentProbe(node: node, horizontal: config.horizontal))
    }
    .modifier(CollectionClip(behavior: config.clipBehavior))
    .onAppear {
      orderedIDs = effectiveOrder
      // Apple owns the lazy prefetch and drag-edge velocity. Keep the exact
      // Flet inputs consumed without turning them into visible geometry.
      _ = config.anchor
      _ = config.cacheExtent
      _ = config.autoScrollerVelocityScalar
    }
    .onChange(of: visibleIDs) { ids in
      orderedIDs = ReorderableListParity.reconciledOrder(orderedIDs, with: ids)
    }
    .onPreferenceChange(CollectionPrototypeExtentKey.self) { extent in
      guard config.firstItemPrototype, extent > 0 else { return }
      measuredPrototypeExtent = extent
    }
    .modifier(CollectionAutoScroll(node: node, horizontal: config.horizontal))
    .modifier(CollectionScrollReporter(node: node, horizontal: config.horizontal, events: events))
    .accessibilityElement(children: .contain)
    .accessibilityValue(config.semanticChildCount.map(String.init) ?? "")
  }

  @ViewBuilder
  private func content(
    config: CollectionDefaults.ReorderableListValues, axis: LayoutAxis,
    ids: [Int], headerID: Int?, footerID: Int?
  ) -> some View {
    if let headerID {
      ControlView(id: headerID, axis: axis)
        .modifier(PageReverse(horizontal: config.horizontal, enabled: config.reverse))
    }
    ForEach(ids, id: \.self) { childID in
      reorderableRow(
        childID, config: config, axis: axis,
        isPrototype: config.firstItemPrototype && childID == ids.first)
        .onDrop(
          of: ["public.text"],
          delegate: ReorderableListDropDelegate(
            destinationID: childID,
            orderedIDs: $orderedIDs,
            draggedID: $draggedID,
            dragOrigin: $dragOrigin,
            onDrop: finishReorder))
    }
    if let footerID {
      ControlView(id: footerID, axis: axis)
        .modifier(PageReverse(horizontal: config.horizontal, enabled: config.reverse))
    }
  }

  @ViewBuilder
  private func reorderableRow(
    _ childID: Int, config: CollectionDefaults.ReorderableListValues, axis: LayoutAxis,
    isPrototype: Bool
  ) -> some View {
    let itemExtent = config.itemExtent
      ?? (config.firstItemPrototype ? measuredPrototypeExtent : nil)
    let row = ControlView(id: childID, axis: axis)
      .modifier(CollectionPrototypeMeasure(
        enabled: isPrototype,
        horizontal: config.horizontal))
      .frame(
        width: config.horizontal ? itemExtent : nil,
        height: config.horizontal ? nil : itemExtent)
      .modifier(PageReverse(horizontal: config.horizontal, enabled: config.reverse))
      // Flutter's ReorderableItemScope makes the owning row/index available
      // to a ReorderableDragHandle anywhere below that row. An environment
      // action is the native SwiftUI equivalent and keeps the visible handle
      // entirely app supplied.
      .environment(
        \.rufletReorderDragAction,
        RufletReorderDragAction(begin: { beginDrag(childID) }))

    if config.showDefaultDragHandles {
      #if os(macOS)
        HStack(spacing: 0) {
          row
          Image(systemName: "line.3.horizontal")
            .accessibilityHidden(true)
            .padding(8)
            .onDrag { beginDrag(childID) }
        }
      #else
        row.onDrag { beginDrag(childID) }
      #endif
    } else {
      // With Flet's generated handles disabled, only an explicit
      // ReorderableDragHandle may initiate a drag; the row itself stays still.
      row
    }
  }

  private func beginDrag(_ childID: Int) -> NSItemProvider {
    if let origin = orderedIDs.firstIndex(of: childID) {
      draggedID = childID
      dragOrigin = origin
      events.fire(
        node, "reorder_start",
        data: ReorderableListParity.reorderStartPayload(oldIndex: origin))
    }
    return NSItemProvider(object: String(childID) as NSString)
  }

  private func finishReorder(oldIndex: Int, newIndex: Int) {
    events.fire(
      node, "reorder",
      data: ReorderableListParity.reorderPayload(oldIndex: oldIndex, newIndex: newIndex))
    events.fire(
      node, "reorder_end",
      data: ReorderableListParity.reorderEndPayload(newIndex: newIndex))
  }
}

/// The row-owned drag action inherited by an explicit
/// `ReorderableDragHandle`. This mirrors Flet's `ReorderableItemScope`: a
/// handle can be nested inside arbitrary layout controls but cannot be used
/// outside its owning reorderable row.
private struct RufletReorderDragAction {
  let begin: () -> NSItemProvider
}

private struct RufletReorderDragActionKey: EnvironmentKey {
  static let defaultValue: RufletReorderDragAction? = nil
}

private extension EnvironmentValues {
  var rufletReorderDragAction: RufletReorderDragAction? {
    get { self[RufletReorderDragActionKey.self] }
    set { self[RufletReorderDragActionKey.self] = newValue }
  }
}

/// `ReorderableDragHandle` — the app-provided content is itself the native
/// drag source. No Material grip is fabricated; Flet's control is only a
/// listener around its content.
struct ReorderableDragHandleControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletReorderDragAction) private var dragAction

  @ViewBuilder
  var body: some View {
    if let error = ReorderableDragHandleParity.error(
      hasReorderableAncestor: dragAction != nil,
      content: node.controlID(forKey: "content").flatMap(store.node))
    {
      Text(error).foregroundColor(.red)
    } else if let contentID = node.controlID(forKey: "content") {
      if node.bool("disabled") == true {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlView(id: contentID, axis: .none)
          .onDrag { dragAction!.begin() }
      }
    }
  }
}

enum ReorderableDragHandleParity {
  static let ancestorError =
    "ReorderableDragHandle must be placed inside ReorderableListView."
  static let missingContentError =
    "ReorderableDragHandle.content must be set and visible"

  /// Flet validates the item scope before it validates content, so preserve
  /// that observable error ordering as well as hidden-content handling.
  static func error(
    hasReorderableAncestor: Bool, content: ControlNode?
  ) -> String? {
    guard hasReorderableAncestor else { return ancestorError }
    guard let content, content.bool("visible") != false else {
      return missingContentError
    }
    return nil
  }
}

private struct ReorderableListDropDelegate: DropDelegate {
  let destinationID: Int
  @Binding var orderedIDs: [Int]
  @Binding var draggedID: Int?
  @Binding var dragOrigin: Int?
  let onDrop: (Int, Int) -> Void

  func dropEntered(info: DropInfo) {
    guard let draggedID,
          draggedID != destinationID,
          let source = orderedIDs.firstIndex(of: draggedID),
          let destination = orderedIDs.firstIndex(of: destinationID)
    else { return }
    orderedIDs = ReorderableListParity.moving(
      orderedIDs, from: source, over: destination)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    guard let draggedID,
          let oldIndex = dragOrigin,
          let newIndex = orderedIDs.firstIndex(of: draggedID)
    else { return false }
    onDrop(oldIndex, newIndex)
    self.draggedID = nil
    dragOrigin = nil
    return true
  }
}

enum ReorderableListParity {
  /// Flutter's `reverse` changes the scroll direction, not the model order.
  static func orderedChildren(_ ids: [Int], reverse: Bool) -> [Int] { ids }

  static func visibleControlIDs(
    _ node: ControlNode, in nodes: [Int: ControlNode]
  ) -> [Int] {
    CollectionVisibleChildren.ids(node.controlIDs(forKey: "controls"), in: nodes)
  }

  static func moving(_ ids: [Int], from source: Int, over destination: Int) -> [Int] {
    guard ids.indices.contains(source), ids.indices.contains(destination), source != destination
    else { return ids }
    var result = ids
    let item = result.remove(at: source)
    result.insert(item, at: destination)
    return result
  }

  static func reconciledOrder(_ current: [Int], with incoming: [Int]) -> [Int] {
    let retained = current.filter(incoming.contains)
    return retained + incoming.filter { !retained.contains($0) }
  }

  static func reorderStartPayload(oldIndex: Int) -> RufletValue {
    .map(["old_index": .int(Int64(oldIndex))])
  }

  static func reorderPayload(oldIndex: Int, newIndex: Int) -> RufletValue {
    .map([
      "old_index": .int(Int64(oldIndex)),
      "new_index": .int(Int64(newIndex))
    ])
  }

  static func reorderEndPayload(newIndex: Int) -> RufletValue {
    .map(["new_index": .int(Int64(newIndex))])
  }
}

/// `auto_scroll` keeps the end of a list in view as rows arrive, and
/// `scroll_interval` throttles what the list reports while it moves.
private struct CollectionAutoScroll: ViewModifier {
  let node: ControlNode
  let horizontal: Bool

  func body(content: Content) -> some View {
    guard node.bool("auto_scroll") == true else { return AnyView(content) }
    return AnyView(
      ScrollViewReader { proxy in
        content
          .onChange(of: node.childIDs) { childIDs in
            guard let last = CollectionAutoScrollTarget.lastID(in: childIDs) else { return }
            withAnimation {
              proxy.scrollTo(last, anchor: horizontal ? .trailing : .bottom)
            }
          }
      })
  }
}

enum CollectionAutoScrollTarget {
  static func lastID(in deliveredChildIDs: [Int]) -> Int? { deliveredChildIDs.last }
}

/// Parsed form of `ScrollableControl.scroll_to` shared by ListView and
/// GridView. Flet accepts a numeric duration or its structured Duration map,
/// and resolves arguments in key, offset, delta order rather than rejecting a
/// call that happens to contain more than one.
struct CollectionScrollToCommand: Equatable {
  let offset: Double?
  let delta: Double?
  let scrollKey: RufletValue?
  let durationMilliseconds: Double
  let curve: String

  init(_ call: RufletMethodCall) {
    offset = call.argument("offset")?.doubleValue
    delta = call.argument("delta")?.doubleValue
    scrollKey = call.argument("scroll_key").flatMap { $0.isNull ? nil : $0 }
    durationMilliseconds = Self.duration(call.argument("duration"))
    curve = call.argument("curve")?.stringValue ?? "ease"
  }

  static func duration(_ value: RufletValue?) -> Double {
    if let number = value?.doubleValue { return Double(Int64(number)) }
    guard let map = value?.mapValue else { return 0 }
    let microseconds =
      Int64(map["microseconds"]?.doubleValue ?? 0)
      + Int64(map["milliseconds"]?.doubleValue ?? 0) * 1_000
      + Int64(map["seconds"]?.doubleValue ?? 0) * 1_000_000
      + Int64(map["minutes"]?.doubleValue ?? 0) * 60_000_000
      + Int64(map["hours"]?.doubleValue ?? 0) * 3_600_000_000
      + Int64(map["days"]?.doubleValue ?? 0) * 86_400_000_000
    return Double(microseconds / 1_000)
  }

  static func keyString(_ value: RufletValue?) -> String? {
    guard let value else { return nil }
    if let map = value.mapValue { return keyString(map["value"]) }
    if let string = value.stringValue { return string }
    if let integer = value.intValue { return String(integer) }
    if let number = value.doubleValue { return String(number) }
    if let boolean = value.boolValue { return boolean ? "true" : "false" }
    return nil
  }

  func targetID(in children: [ControlNode]) -> Int? {
    guard let target = Self.keyString(scrollKey) else { return nil }
    return children.first(where: {
      Self.keyString($0.props["key"]) == target
    })?.id
  }

  func resolvedOffset(current: Double, maximum: Double) -> Double? {
    guard offset != nil || delta != nil else { return nil }
    var target = offset ?? current + (delta ?? 0)
    if let offset, offset < 0 { target = maximum + offset + 1 }
    return min(max(0, target), max(0, maximum))
  }
}

@MainActor
private final class CollectionNativeScrollDriver: ObservableObject {
  #if canImport(UIKit)
    weak var scrollView: UIScrollView?

    func move(
      _ command: CollectionScrollToCommand,
      horizontal: Bool,
      completion: @escaping () -> Void
    ) {
      guard let scrollView else { completion(); return }
      let current = horizontal ? scrollView.contentOffset.x : scrollView.contentOffset.y
      let maximum = horizontal
        ? max(0, scrollView.contentSize.width - scrollView.bounds.width)
        : max(0, scrollView.contentSize.height - scrollView.bounds.height)
      let target = CGFloat(command.resolvedOffset(
        current: Double(current), maximum: Double(maximum)) ?? Double(current))
      var point = scrollView.contentOffset
      if horizontal { point.x = target } else { point.y = target }
      guard command.durationMilliseconds >= 1 else {
        scrollView.setContentOffset(point, animated: false)
        completion()
        return
      }
      UIView.animate(
        withDuration: command.durationMilliseconds / 1_000,
        delay: 0,
        options: animationOptions(command.curve),
        animations: { scrollView.contentOffset = point },
        completion: { _ in completion() })
    }

    private func animationOptions(_ curve: String) -> UIView.AnimationOptions {
      switch curve.lowercased() {
      case "linear": return .curveLinear
      case "easein": return .curveEaseIn
      case "easeout": return .curveEaseOut
      case "easeinout", "ease": return .curveEaseInOut
      default: return .curveEaseInOut
      }
    }
  #elseif canImport(AppKit)
    weak var scrollView: NSScrollView?

    func move(
      _ command: CollectionScrollToCommand,
      horizontal: Bool,
      completion: @escaping () -> Void
    ) {
      guard let scrollView else { completion(); return }
      let clip = scrollView.contentView
      let current = horizontal ? clip.bounds.origin.x : clip.bounds.origin.y
      let documentSize = scrollView.documentView?.bounds.size ?? .zero
      let maximum = horizontal
        ? max(0, documentSize.width - clip.bounds.width)
        : max(0, documentSize.height - clip.bounds.height)
      let target = CGFloat(command.resolvedOffset(
        current: Double(current), maximum: Double(maximum)) ?? Double(current))
      var point = clip.bounds.origin
      if horizontal { point.x = target } else { point.y = target }
      guard command.durationMilliseconds >= 1 else {
        clip.setBoundsOrigin(point)
        scrollView.reflectScrolledClipView(clip)
        completion()
        return
      }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = command.durationMilliseconds / 1_000
        context.timingFunction = timingFunction(command.curve)
        clip.animator().setBoundsOrigin(point)
      } completionHandler: { completion() }
    }

    private func timingFunction(_ curve: String) -> CAMediaTimingFunction {
      switch curve.lowercased() {
      case "linear": return CAMediaTimingFunction(name: .linear)
      case "easein": return CAMediaTimingFunction(name: .easeIn)
      case "easeout": return CAMediaTimingFunction(name: .easeOut)
      default: return CAMediaTimingFunction(name: .easeInEaseOut)
      }
    }
  #endif
}

#if canImport(UIKit)
  private struct CollectionNativeScrollLocator: UIViewRepresentable {
    @ObservedObject var driver: CollectionNativeScrollDriver
    func makeUIView(context: Context) -> UIView { UIView(frame: .zero) }
    func updateUIView(_ view: UIView, context: Context) {
      DispatchQueue.main.async {
        var ancestor = view.superview
        while let candidate = ancestor {
          if let scrollView = candidate as? UIScrollView {
            driver.scrollView = scrollView
            return
          }
          ancestor = candidate.superview
        }
      }
    }
  }
#elseif canImport(AppKit)
  private struct CollectionNativeScrollLocator: NSViewRepresentable {
    @ObservedObject var driver: CollectionNativeScrollDriver
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }
    func updateNSView(_ view: NSView, context: Context) {
      DispatchQueue.main.async {
        var ancestor = view.superview
        while let candidate = ancestor {
          if let scrollView = candidate as? NSScrollView {
            driver.scrollView = scrollView
            return
          }
          ancestor = candidate.superview
        }
      }
    }
  }
#endif

private struct CollectionScrollCommands: ViewModifier {
  let node: ControlNode
  let horizontal: Bool
  @ObservedObject var driver: CollectionNativeScrollDriver
  @EnvironmentObject private var store: ControlStore

  func body(content: Content) -> some View {
    ScrollViewReader { proxy in
      content.rufletCommandHandler(node.id, method: "scroll_to") { call, completion in
        let command = CollectionScrollToCommand(call)
        if let targetID = command.targetID(in: node.childIDs.compactMap(store.node)) {
          let animation = command.durationMilliseconds >= 1
            ? RufletCurve.animation(
              command.curve, duration: command.durationMilliseconds / 1_000)
            : nil
          withAnimation(animation) { proxy.scrollTo(targetID) }
          if command.durationMilliseconds >= 1 {
            DispatchQueue.main.asyncAfter(
              deadline: .now() + command.durationMilliseconds / 1_000
            ) { completion(.success(.null)) }
          } else {
            completion(.success(.null))
          }
        } else if command.offset != nil || command.delta != nil {
          driver.move(command, horizontal: horizontal) {
            completion(.success(.null))
          }
        } else {
          completion(.success(.null))
        }
      }
    }
  }
}

/// A page narrower than its viewport leaves its neighbours visible at the
/// edges, which is what Flutter's viewportFraction does.
private struct ViewportFraction: ViewModifier {
  let value: Double?

  func body(content: Content) -> some View {
    guard let value, value > 0, value < 1 else { return AnyView(content) }
    return AnyView(
      GeometryReader { proxy in
        content
          .frame(width: proxy.size.width * CGFloat(value))
          .frame(maxWidth: .infinity)
      })
  }
}

/// `PageView` — a horizontally paged carousel.
struct PageViewControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var selectedIndex: Int
  @State private var viewportExtent: CGFloat = 0

  init(node: ControlNode) {
    self.node = node
    _selectedIndex = State(initialValue: CollectionDefaults.pageView(node).selectedIndex)
  }

  var body: some View {
    let config = CollectionDefaults.pageView(node)
    let ids = pageIDs
    Group {
      if config.snap {
        TabView(selection: $selectedIndex) {
          ForEach(PageViewParity.pages(ids), id: \.id) { page in
            ControlView(id: page.id, axis: .none)
              .modifier(PageViewport(
                horizontal: config.horizontal,
                fraction: config.viewportFraction,
                padEnds: config.padEnds))
              .modifier(PageReverse(horizontal: config.horizontal, enabled: config.reverse))
              .tag(page.index)
          }
        }
        .modifier(PagedTabStyle())
        .modifier(PageReverse(horizontal: config.horizontal, enabled: config.reverse))
        .modifier(PageAxis(horizontal: config.horizontal))
      } else {
        FreeScrollingPageView(
          ids: ids, selectedIndex: $selectedIndex,
          horizontal: config.horizontal, reverse: config.reverse,
          fraction: config.viewportFraction, padEnds: config.padEnds,
          implicitScrolling: config.implicitScrolling)
      }
    }
    .modifier(CollectionClip(behavior: config.clipBehavior))
    .background(
      GeometryReader { proxy in
        Color.clear.onAppear {
          viewportExtent = config.horizontal ? proxy.size.width : proxy.size.height
        }
        .onChange(of: proxy.size) { size in
          viewportExtent = config.horizontal ? size.width : size.height
        }
      })
    .onChange(of: selectedIndex) { value in
      let properties = PageViewParity.selectionProperties(index: value)
      events.setLocal(node.id, "selected_index", properties["selected_index"] ?? .int(Int64(value)))
      // Flet's renderer calls updateProperties even when no on_change handler
      // exists, keeping Ruby's selected_index synchronized with a native swipe.
      events.update(node.id, properties)
      events.fire(node, "change", data: .int(Int64(value)))
    }
    .onChange(of: node.int("selected_index") ?? 0) { value in
      selectedIndex = CollectionParity.clampedIndex(value, count: ids.count)
    }
    .onChange(of: ids) { nextIDs in
      selectedIndex = CollectionParity.clampedIndex(selectedIndex, count: nextIDs.count)
    }
    .rufletCommandHandler(node.id, handler: handleCommand)
  }

  private var pageIDs: [Int] {
    PageViewParity.visibleControlIDs(node, in: store.nodes)
  }

  private func handleCommand(
    _ call: RufletMethodCall,
    completion: @escaping RufletMethodCompletion
  ) {
    let count = pageIDs.count
    switch call.name {
    case "go_to_page", "jump_to_page":
      guard let index = call.argument("index")?.intValue else {
        return completion(.failure(RufletServiceError.invalidArguments("index is required")))
      }
      let target = CollectionParity.clampedIndex(index, count: count)
      if call.name == "go_to_page" {
        withAnimation(PageViewParity.commandAnimation(call)) { selectedIndex = target }
      } else {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { selectedIndex = target }
      }
      completion(.success(.null))
    case "jump_to":
      guard let value = call.argument("value")?.doubleValue else {
        return completion(.failure(RufletServiceError.invalidArguments("value is required")))
      }
      let pageExtent = viewportExtent * max(CollectionDefaults.pageView(node).viewportFraction, 0.01)
      let offset = CollectionParity.resolvedPageOffset(
        value, pageExtent: Double(pageExtent), count: count)
      selectedIndex = CollectionParity.pageIndex(
        forOffset: offset, pageExtent: Double(pageExtent), count: count)
      completion(.success(.null))
    case "next_page":
      withAnimation(PageViewParity.commandAnimation(call)) {
        selectedIndex = CollectionParity.clampedIndex(selectedIndex + 1, count: count)
      }
      completion(.success(.null))
    case "previous_page":
      withAnimation(PageViewParity.commandAnimation(call)) {
        selectedIndex = CollectionParity.clampedIndex(selectedIndex - 1, count: count)
      }
      completion(.success(.null))
    default:
      completion(.failure(rufletUnsupported("PageView", call)))
    }
  }
}

enum PageViewParity {
  struct Page: Equatable { let index: Int; let id: Int }
  /// Flutter's `reverse` changes the axis direction; it does not reorder the
  /// children or reinterpret PageController indices.
  static func pages(_ ids: [Int]) -> [Page] {
    ids.enumerated().map { Page(index: $0.offset, id: $0.element) }
  }
  static func visibleControlIDs(
    _ node: ControlNode, in nodes: [Int: ControlNode]
  ) -> [Int] {
    CollectionVisibleChildren.ids(node.controlIDs(forKey: "controls"), in: nodes)
  }
  static func selectionProperties(index: Int) -> [String: RufletValue] {
    ["selected_index": .int(Int64(index))]
  }
  static func commandAnimation(_ call: RufletMethodCall) -> Animation {
    let duration = call.argument("duration")?.doubleValue ?? 1_000
    let curve = call.argument("curve")?.stringValue ?? "linear"
    return ControlProps.animation(.map([
      "duration": .double(duration), "curve": .string(curve)
    ])) ?? .linear(duration: max(duration, 0) / 1_000)
  }
}

private struct PageReverse: ViewModifier {
  let horizontal: Bool
  let enabled: Bool
  func body(content: Content) -> some View {
    enabled
      ? AnyView(content.scaleEffect(x: horizontal ? -1 : 1, y: horizontal ? 1 : -1))
      : AnyView(content)
  }
}

private struct FreeScrollingPageView: View {
  let ids: [Int]
  @Binding var selectedIndex: Int
  let horizontal: Bool
  let reverse: Bool
  let fraction: CGFloat
  let padEnds: Bool
  let implicitScrolling: Bool
  @State private var selectionCameFromScroll = false

  var body: some View {
    GeometryReader { viewport in
      ScrollViewReader { reader in
        ScrollView(horizontal ? .horizontal : .vertical, showsIndicators: false) {
          stack(viewport: viewport.size)
            .modifier(PageReverse(horizontal: horizontal, enabled: reverse))
        }
        .coordinateSpace(name: "ruflet-free-page")
        .onPreferenceChange(PageFramePreference.self) { frames in
          guard let nearest = frames.min(by: {
            abs(center($0.value, viewport: viewport.size))
              < abs(center($1.value, viewport: viewport.size))
          })?.key else { return }
          if nearest != selectedIndex {
            selectionCameFromScroll = true
            selectedIndex = nearest
          }
        }
        .onAppear { reader.scrollTo(selectedIndex, anchor: .center) }
        .onChange(of: selectedIndex) { value in
          if selectionCameFromScroll {
            selectionCameFromScroll = false
          } else {
            reader.scrollTo(value, anchor: .center)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func stack(viewport: CGSize) -> some View {
    let resolvedFraction = max(fraction, 0.01)
    let pageExtent = (horizontal ? viewport.width : viewport.height) * resolvedFraction
    let endPadding = padEnds ? max(((horizontal ? viewport.width : viewport.height) - pageExtent) / 2, 0) : 0
    let pages = ForEach(Array(ids.enumerated()), id: \.offset) { index, id in
      ControlView(id: id, axis: .none)
        .frame(
          width: horizontal ? pageExtent : viewport.width,
          height: horizontal ? viewport.height : pageExtent)
        .modifier(PageReverse(horizontal: horizontal, enabled: reverse))
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: PageFramePreference.self,
              value: [index: proxy.frame(in: .named("ruflet-free-page"))])
          })
        .id(index)
        .accessibilityHidden(!implicitScrolling && index != selectedIndex)
    }
    if horizontal {
      LazyHStack(spacing: 0) { pages }
        .padding(.horizontal, endPadding)
    } else {
      LazyVStack(spacing: 0) { pages }
        .padding(.vertical, endPadding)
    }
  }

  private func center(_ frame: CGRect, viewport: CGSize) -> CGFloat {
    horizontal ? frame.midX - viewport.width / 2 : frame.midY - viewport.height / 2
  }
}

private struct PageFramePreference: PreferenceKey {
  static var defaultValue: [Int: CGRect] = [:]
  static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

private struct PagedTabStyle: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.tabViewStyle(.page)
    #else
      content
    #endif
  }
}

/// `ListTile` — leading, title/subtitle, trailing.
struct ListTileControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.openURL) private var openURL
  @StateObject private var tileClicks = RufletListTileClickNotifier()
  @State private var hovered = false
  @State private var pressed = false
  @FocusState private var focused: Bool

  @ViewBuilder
  var body: some View {
    if let validationMessage = ListTilePresentation.validationMessage(
      node, title: node.controlID(forKey: "title").flatMap(store.node))
    {
      Text(validationMessage).foregroundColor(.red)
    } else if node.type == "CupertinoListTile" {
      cupertinoTile
    } else if !ListTilePresentation(node: node).requiresCustomRendering {
      nativeTile
    } else {
      materialTile
    }
  }

  @ViewBuilder
  private var nativeTile: some View {
    Group {
      if nativeInteractive {
        Button(action: nativeActivate) { nativeTileContents }
          .buttonStyle(.plain)
      } else {
        nativeTileContents
      }
    }
    .environment(\.rufletListTileClicks, node.bool("toggle_inputs") == true ? tileClicks : nil)
    .modifier(NativeListTileLongPress(node: node, events: events))
    .modifier(NativeListTileFocusable(enabled: node.bool("disabled") != true))
    .focused($focused)
    .onAppear { if node.bool("autofocus") == true { focused = true } }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .disabled(node.bool("disabled") == true)
  }

  private var nativeTileContents: some View {
    let presentation = ListTilePresentation(node: node)
    return HStack(
      alignment: presentation.rowAlignment,
      spacing: presentation.horizontalTitleGap
    ) {
      if let leadingID = materialSlots.leadingID {
        ControlView(id: leadingID, axis: .none)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
          .frame(minWidth: presentation.minLeadingWidth)
      } else if let leadingIcon = materialSlots.leadingIcon {
        RufletIcon(value: leadingIcon)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
          .frame(minWidth: presentation.minLeadingWidth)
      }

      VStack(alignment: .leading, spacing: presentation.textSpacing) {
        if let titleID = materialSlots.titleID {
          ControlView(id: titleID, axis: .none)
        } else if let title = materialSlots.titleText {
          Text(title)
        }
        if let subtitleID = materialSlots.subtitleID {
          ControlView(id: subtitleID, axis: .none).foregroundStyle(.secondary)
        } else if let subtitle = materialSlots.subtitleText {
          Text(subtitle).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let trailingID = materialSlots.trailingID {
        ControlView(id: trailingID, axis: .none)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
      } else if let trailingIcon = materialSlots.trailingIcon {
        RufletIcon(value: trailingIcon)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
      }
    }
    .padding(presentation.contentPadding)
    .padding(.vertical, presentation.minVerticalPadding)
    .frame(maxWidth: .infinity, minHeight: presentation.minHeight)
    .contentShape(Rectangle())
  }

  private var nativeInteractive: Bool {
    node.handlesEvent("click") || node.bool("toggle_inputs") == true || node.string("url") != nil
  }

  private func nativeActivate() {
    RufletTapFeedback.perform(enabled: node.bool("enable_feedback") != false)
    if node.bool("toggle_inputs") == true { tileClicks.click() }
    if let url = node.string("url").flatMap(URL.init(string:)) { openURL(url) }
    if node.handlesEvent("click") { events.fire(node, "click") }
  }

  private var materialTile: some View {
    let presentation = ListTilePresentation(node: node)
    let shape = presentation.shape
    return HStack(
      alignment: presentation.rowAlignment,
      spacing: presentation.horizontalTitleGap
    ) {
      if let leadingID = materialSlots.leadingID {
        ControlView(id: leadingID, axis: .none)
          .font(.system(size: presentation.leadingTrailingFontSize))
          .foregroundColor(presentation.leadingTrailingColor)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
          .frame(minWidth: presentation.minLeadingWidth)
      } else if let leadingIcon = materialSlots.leadingIcon {
        RufletIcon(
          value: leadingIcon, size: 24,
          color: presentation.iconColor)
          .frame(minWidth: presentation.minLeadingWidth)
      }

      VStack(alignment: .leading, spacing: presentation.textSpacing) {
        if let titleID = materialSlots.titleID {
          ControlView(id: titleID, axis: .none)
            .font(.system(size: presentation.titleFontSize))
            .foregroundColor(presentation.titleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.titleTextStyle))
        } else if let title = materialSlots.titleText {
          Text(title)
            .font(.system(size: presentation.titleFontSize))
            .foregroundColor(presentation.titleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.titleTextStyle))
        }
        if let subtitleID = materialSlots.subtitleID {
          ControlView(id: subtitleID, axis: .none)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(presentation.subtitleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.subtitleTextStyle))
        } else if let subtitle = materialSlots.subtitleText {
          Text(subtitle)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(presentation.subtitleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.subtitleTextStyle))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let trailingID = materialSlots.trailingID {
        ControlView(id: trailingID, axis: .none)
          .font(.system(size: presentation.leadingTrailingFontSize))
          .foregroundColor(presentation.leadingTrailingColor)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
      } else if let trailingIcon = materialSlots.trailingIcon {
        RufletIcon(
          value: trailingIcon, size: 24,
          color: presentation.iconColor)
      }
    }
    .padding(presentation.contentPadding)
    .padding(.vertical, presentation.minVerticalPadding)
    .frame(minHeight: presentation.minHeight)
    .background(shape.fill(
      pressed
        ? MaterialPalette.color(node.string("splash_color"), default: .clear)
        : presentation.backgroundColor(hovered: hovered, focused: focused)))
    .overlay(shape.stroke(presentation.outlineColor, lineWidth: presentation.outlineWidth))
    .contentShape(shape)
    .environment(\.rufletListTileClicks, node.bool("toggle_inputs") == true ? tileClicks : nil)
    .onHover { hovered = $0 }
    .modifier(NativeListTileFocusable(enabled: node.bool("disabled") != true))
    .focused($focused)
    .onAppear { if node.bool("autofocus") == true { focused = true } }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .modifier(ListTileInteraction(
      node: node, events: events, openURL: openURL, tileClicks: tileClicks,
      pressed: $pressed))
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
    .disabled(node.bool("disabled") == true)
  }

  private var cupertinoTile: some View {
    let presentation = CupertinoListTilePresentation(
      node: node, visibilityForID: { store.node($0)?.bool("visible") })
    return HStack(spacing: 0) {
      if let leadingID = presentation.leadingID {
        ControlView(id: leadingID, axis: .none)
          .frame(width: presentation.leadingSize, height: presentation.leadingSize)
        Spacer().frame(width: presentation.leadingToTitle)
      } else if let leadingIcon = presentation.leadingIcon {
        RufletIcon(value: leadingIcon, size: presentation.leadingSize, color: nil)
          .frame(width: presentation.leadingSize, height: presentation.leadingSize)
        Spacer().frame(width: presentation.leadingToTitle)
      } else {
        // Flutter retains the leading slot's height even when it has no child.
        Color.clear.frame(width: 0, height: presentation.leadingSize)
      }

      VStack(alignment: .leading, spacing: presentation.titleSubtitleSpacing) {
        if let titleID = presentation.titleID {
          ControlView(id: titleID, axis: .none)
            .font(presentation.titleFont)
            .lineLimit(1)
        } else if let title = presentation.titleText {
          Text(title).font(presentation.titleFont).lineLimit(1)
        }
        if let subtitleID = presentation.subtitleID {
          ControlView(id: subtitleID, axis: .none)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(.secondary)
            .lineLimit(1)
        } else if let subtitle = presentation.subtitleText {
          Text(subtitle)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let infoID = presentation.additionalInfoID {
        ControlView(id: infoID, axis: .none).foregroundColor(.secondary).lineLimit(1)
        if presentation.hasTrailing { Spacer().frame(width: 6) }
      } else if let info = presentation.additionalInfoText {
        Text(info).foregroundColor(.secondary).lineLimit(1)
        if presentation.hasTrailing { Spacer().frame(width: 6) }
      }
      if let trailingID = presentation.trailingID {
        ControlView(id: trailingID, axis: .none)
      } else if let trailingIcon = presentation.trailingIcon {
        RufletIcon(value: trailingIcon, size: 17, color: nil)
      }
    }
    .padding(presentation.contentPadding)
    .frame(maxWidth: .infinity, minHeight: presentation.minHeight)
    .background(pressed ? presentation.activatedColor : presentation.backgroundColor)
    .contentShape(Rectangle())
    .environment(\.rufletListTileClicks, node.bool("toggle_inputs") == true ? tileClicks : nil)
    .modifier(ListTileInteraction(
      node: node, events: events, openURL: openURL, tileClicks: tileClicks,
      pressed: $pressed))
    .disabled(node.bool("disabled") == true)
  }

  private var materialSlots: MaterialListTileSlots {
    MaterialListTileSlots(
      node: node, visibilityForID: { store.node($0)?.bool("visible") })
  }
}

/// Exact type and visibility ownership of Material ListTile's four slots.
/// Dart's text builder accepts only String or a visible Control; its icon
/// builder accepts only an integer icon code or a visible Control.
struct MaterialListTileSlots: Equatable {
  let titleID: Int?
  let titleText: String?
  let subtitleID: Int?
  let subtitleText: String?
  let leadingID: Int?
  let leadingIcon: RufletValue?
  let trailingID: Int?
  let trailingIcon: RufletValue?

  init(node: ControlNode, visibilityForID: (Int) -> Bool?) {
    (titleID, titleText) = Self.textSlot(
      node, key: "title", visibilityForID: visibilityForID)
    (subtitleID, subtitleText) = Self.textSlot(
      node, key: "subtitle", visibilityForID: visibilityForID)
    (leadingID, leadingIcon) = Self.iconSlot(
      node, key: "leading", visibilityForID: visibilityForID)
    (trailingID, trailingIcon) = Self.iconSlot(
      node, key: "trailing", visibilityForID: visibilityForID)
  }

  private static func textSlot(
    _ node: ControlNode, key: String, visibilityForID: (Int) -> Bool?
  ) -> (Int?, String?) {
    if let id = node.controlID(forKey: key) {
      return visibilityForID(id) == true ? (id, nil) : (nil, nil)
    }
    if case .string(let text) = node.props[key] { return (nil, text) }
    return (nil, nil)
  }

  private static func iconSlot(
    _ node: ControlNode, key: String, visibilityForID: (Int) -> Bool?
  ) -> (Int?, RufletValue?) {
    if let id = node.controlID(forKey: key) {
      return visibilityForID(id) == true ? (id, nil) : (nil, nil)
    }
    if case .int = node.props[key] { return (nil, node.props[key]) }
    return (nil, nil)
  }
}

/// Focusable rows are native on macOS and iOS 17+. Earlier iOS releases do
/// not expose SwiftUI's boolean focusability modifier; keep the row native and
/// preserve its activation/disabled contract without inventing a focus ring.
private struct NativeListTileFocusable: ViewModifier {
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    #if os(iOS)
      if #available(iOS 17, *) {
        content.focusable(enabled)
      } else {
        content
      }
    #else
      content.focusable(enabled)
    #endif
  }
}

/// Activation is attached only when the Flet constructor would give the tile
/// an `onTap`; merely rendering a tile must not turn it into a button.
private struct ListTileInteraction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  let openURL: OpenURLAction
  let tileClicks: RufletListTileClickNotifier
  @Binding var pressed: Bool

  func body(content: Content) -> some View {
    var result = AnyView(content)
    if interactive && node.bool("disabled") != true {
      result = AnyView(
        Button(action: activate) { result }
          .buttonStyle(ListTileNativeButtonStyle(pressed: $pressed)))
    }
    if node.type == "ListTile", node.handlesEvent("long_press"),
      node.bool("disabled") != true
    {
      result = AnyView(result.simultaneousGesture(
        LongPressGesture().onEnded { _ in events.fire(node, "long_press") }))
    }
    return result
  }

  private var interactive: Bool {
    node.handlesEvent("click") || node.bool("toggle_inputs") == true || node.string("url") != nil
  }

  private func activate() {
    RufletTapFeedback.perform(enabled: node.bool("enable_feedback") != false)
    if node.bool("toggle_inputs") == true { tileClicks.click() }
    if let url = node.string("url").flatMap(URL.init(string:)) { openURL(url) }
    if node.handlesEvent("click") { events.fire(node, "click") }
  }
}

/// Let the platform button recognizer arbitrate a row tap against its parent
/// ScrollView. Combining `onTapGesture` with a zero-distance DragGesture made
/// a styled ListTile lose ordinary taps whenever scrolling won recognition.
private struct ListTileNativeButtonStyle: ButtonStyle {
  @Binding var pressed: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .onAppear { pressed = configuration.isPressed }
      .onChange(of: configuration.isPressed) { pressed = $0 }
  }
}

private struct NativeListTileLongPress: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("long_press"), node.bool("disabled") != true {
      content.onLongPressGesture { events.fire(node, "long_press") }
    } else {
      content
    }
  }
}

/// An omitted Flutter text-style slot inherits the constructor's theme style;
/// applying an empty RufletTextStyle would incorrectly reset that style to
/// SwiftUI's 17-point body font.
private struct OptionalListTileTextStyle: ViewModifier {
  let style: RufletTextStyle?

  func body(content: Content) -> some View {
    if let style { content.rufletTextStyle(style) } else { content }
  }
}

/// Generic pressed fill retained for collection controls such as
/// ExpansionPanel that share Material's list-row state layer.
private struct ListTileSplash: ViewModifier {
  let color: Color?
  @State private var pressed = false

  func body(content: Content) -> some View {
    guard let color else { return AnyView(content) }
    return AnyView(
      content
        .background(pressed ? color : .clear)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }))
  }
}

/// Constructor and Material-3 theme fallbacks used by `ListTile`.
struct ListTilePresentation {
  let node: ControlNode
  let metrics: CollectionDefaults.ListTileValues
  let shapeKind: RufletCardShapeKind
  let radii: RufletCornerRadii
  let outlineColor: Color
  let outlineWidth: CGFloat

  init(node: ControlNode) {
    self.node = node
    metrics = CollectionDefaults.listTile(node)
    let shapeMap = node.map("shape")
    shapeKind = RufletCardShapeKind(
      rawValue: shapeMap?["_type"]?.stringValue?.lowercased() ?? "") ?? .roundedRectangle
    radii = ControlProps.cornerRadii(shapeMap?["radius"]) ?? RufletCornerRadii(uniform: 0)
    let side = shapeMap?["side"]?.mapValue
    if side?["style"]?.stringValue?.lowercased() == "none" {
      outlineColor = .clear
      outlineWidth = 0
    } else {
      outlineColor = MaterialPalette.color(side?["color"]?.stringValue, default: .clear)
      outlineWidth = CGFloat(side?["width"]?.doubleValue ?? 0)
    }
  }

  var requiresCustomRendering: Bool {
    let materialVisualProperties = [
      "content_padding", "horizontal_spacing", "min_leading_width",
      "min_vertical_padding", "min_height", "dense", "is_three_line",
      "visual_density", "title_alignment", "shape", "bgcolor", "focus_color",
      "hover_color", "splash_color", "selected", "selected_color",
      "selected_tile_color", "text_color", "icon_color", "title_text_style",
      "subtitle_text_style", "enable_feedback",
    ]
    return materialVisualProperties.contains { node.props[$0] != nil }
  }

  static func validationMessage(_ node: ControlNode, title: ControlNode? = nil) -> String? {
    guard node.type == "CupertinoListTile" else { return nil }
    let hasTitle: Bool
    if node.controlID(forKey: "title") != nil {
      hasTitle = RufletRequiredContent.isVisible(title)
    } else {
      if case .string = node.props["title"] { hasTitle = true } else { hasTitle = false }
    }
    return hasTitle ? nil : "CupertinoListTile.title must be provided and visible"
  }

  var shape: RufletCardShape {
    RufletCardShape(kind: shapeKind, radii: radii, eccentricity: 0)
  }
  var contentPadding: EdgeInsets { metrics.contentPadding }
  var horizontalTitleGap: CGFloat { metrics.horizontalTitleGap }
  var minLeadingWidth: CGFloat { metrics.minLeadingWidth }
  var minVerticalPadding: CGFloat { metrics.minVerticalPadding }
  var minHeight: CGFloat { metrics.minHeight }
  var dense: Bool { node.bool("dense") == true }
  var titleFontSize: CGFloat { dense ? 13 : 16 }
  var subtitleFontSize: CGFloat { dense ? 12 : 14 }
  var leadingTrailingFontSize: CGFloat { 11 }
  var textSpacing: CGFloat { node.props["subtitle"] == nil ? 0 : 2 }

  var rowAlignment: VerticalAlignment {
    switch node.string("title_alignment")?.lowercased() {
    case "top": return .top
    case "bottom": return .bottom
    // M3's default `threeLine` is top only for an actual three-line tile.
    case "threeline" where node.bool("is_three_line") == true: return .top
    default: return .center
    }
  }

  private var explicitStateTextColor: Color? {
    if node.bool("disabled") == true {
      return MaterialPalette.color("onsurface", default: .secondary).opacity(0.38)
    }
    if node.bool("selected") == true {
      return MaterialPalette.color(
        node.string("selected_color"),
        default: MaterialPalette.color("primary", default: .accentColor))
    }
    return MaterialPalette.color(node.string("text_color"))
  }

  var titleColor: Color {
    explicitStateTextColor ?? MaterialPalette.color("onsurface", default: .primary)
  }
  var subtitleColor: Color {
    explicitStateTextColor ?? MaterialPalette.color("onsurfacevariant", default: .secondary)
  }
  var leadingTrailingColor: Color {
    explicitStateTextColor ?? MaterialPalette.color("onsurfacevariant", default: .secondary)
  }
  var titleTextStyle: RufletTextStyle? {
    node.map("title_text_style").map(RufletTextStyle.init(map:))
  }
  var subtitleTextStyle: RufletTextStyle? {
    node.map("subtitle_text_style").map(RufletTextStyle.init(map:))
  }
  var leadingTrailingTextStyle: RufletTextStyle? {
    node.map("leading_and_trailing_text_style").map(RufletTextStyle.init(map:))
  }

  var iconColor: Color {
    if node.bool("disabled") == true { return .secondary.opacity(0.38) }
    if node.bool("selected") == true {
      return MaterialPalette.color(
        node.string("selected_color"),
        default: MaterialPalette.color("primary", default: .accentColor))
    }
    return MaterialPalette.color(node.string("icon_color") ?? "onsurfacevariant", default: .secondary)
  }

  func backgroundColor(hovered: Bool, focused: Bool) -> Color {
    if focused, let focus = MaterialPalette.color(node.string("focus_color")) { return focus }
    if hovered, let hover = MaterialPalette.color(node.string("hover_color")) { return hover }
    if node.bool("selected") == true,
      let selected = MaterialPalette.color(node.string("selected_tile_color"))
    { return selected }
    return MaterialPalette.color(node.string("bgcolor"), default: .clear)
  }
}

/// Flutter's CupertinoListTile constants are part of its native constructor,
/// not app-specific styling. Ruflet forwards nil for these values and the
/// Apple renderer resolves the same four layout variants here.
struct CupertinoListTilePresentation {
  let node: ControlNode
  let notched: Bool
  let hasLeading: Bool
  let hasSubtitle: Bool
  let titleID: Int?
  let titleText: String?
  let leadingID: Int?
  let leadingIcon: RufletValue?
  let subtitleID: Int?
  let subtitleText: String?
  let additionalInfoID: Int?
  let additionalInfoText: String?
  let trailingID: Int?
  let trailingIcon: RufletValue?

  init(node: ControlNode, visibilityForID: (Int) -> Bool? = { _ in nil }) {
    self.node = node
    notched = node.bool("notched") == true

    func visibleID(_ key: String) -> Int? {
      node.controlID(forKey: key).flatMap { visibilityForID($0) == false ? nil : $0 }
    }
    func strictText(_ key: String) -> String? {
      if case .string(let value) = node.props[key] { return value }
      return nil
    }
    func strictIcon(_ key: String) -> RufletValue? {
      switch node.props[key] {
      case .int, .string: return node.props[key]
      default: return nil
      }
    }

    titleID = visibleID("title")
    titleText = strictText("title")
    leadingID = visibleID("leading")
    leadingIcon = strictIcon("leading")
    subtitleID = visibleID("subtitle")
    subtitleText = strictText("subtitle")
    additionalInfoID = visibleID("additional_info")
    additionalInfoText = strictText("additional_info")
    trailingID = visibleID("trailing")
    trailingIcon = strictIcon("trailing")
    hasLeading = leadingID != nil || leadingIcon != nil
    hasSubtitle = subtitleID != nil || subtitleText != nil
  }

  var hasTrailing: Bool { trailingID != nil || trailingIcon != nil }

  var leadingSize: CGFloat { CGFloat(node.double("leading_size") ?? (notched ? 30 : 28)) }
  var leadingToTitle: CGFloat { CGFloat(node.double("leading_to_title") ?? (notched ? 12 : 16)) }
  var titleSubtitleSpacing: CGFloat { hasSubtitle ? 3 : 0 }
  var subtitleFontSize: CGFloat { notched ? 14 : 12 }
  var titleFont: Font {
    if notched && hasSubtitle {
      return .system(size: hasLeading ? 17 : 16, weight: .semibold)
    }
    return .body
  }

  var minHeight: CGFloat {
    if !notched { return hasSubtitle ? 48 : 44 }
    return hasLeading ? 54 : 50
  }

  var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    if !notched { return EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 14) }
    if hasLeading { return EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14) }
    return EdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 14)
  }

  var backgroundColor: Color {
    MaterialPalette.color(node.string("bgcolor"), default: .clear)
  }

  var activatedColor: Color {
    if let explicit = MaterialPalette.color(node.string("bgcolor_activated")) { return explicit }
    #if os(iOS)
      return Color(uiColor: .systemGray4)
    #else
      return Color(nsColor: .lightGray).opacity(0.55)
    #endif
  }
}

/// `ExpansionTile` — a disclosure row that keeps its state on the Ruby side.
struct ExpansionTileControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    if let message = ExpansionTilePresentation.validationMessage(
      node, title: node.controlID(forKey: "title").flatMap(store.node))
    {
      Text(message).font(.caption).foregroundStyle(.red)
    } else {
      nativeTile
    }
  }

  private var expanded: Bool { node.bool("expanded") ?? false }
  private var presentation: ExpansionTilePresentation { ExpansionTilePresentation(node: node) }

  private var expansionBinding: Binding<Bool> {
    Binding(
      get: { expanded },
      set: { next in
        guard next != expanded else { return }
        RufletTapFeedback.perform(enabled: presentation.enableFeedback)
        events.commit(node, key: "expanded", value: .bool(next), event: "change")
      })
  }

  /// ExpansionTile remains a native Apple disclosure control for every style
  /// combination. Flet properties are translated through native modifiers;
  /// they never select a handwritten Material tile implementation.
  private var nativeTile: some View {
    DisclosureGroup(isExpanded: expansionBinding) {
      ControlList(ids: node.controlIDs(forKey: "controls"), axis: .vertical)
        .padding(presentation.controlsPadding)
        .frame(
          maxWidth: presentation.expandedCrossAxisAlignmentToken == "stretch" ? .infinity : nil,
          alignment: presentation.expandedCrossAxisAlignment.alignment)
        .frame(maxWidth: .infinity, alignment: presentation.expandedAlignment)
    } label: {
      nativeHeader
        .foregroundColor(MaterialPalette.color(presentation.currentTextColorToken))
        .padding(presentation.tilePadding)
    }
    .frame(minHeight: presentation.effectiveMinimumTileHeight)
    .background(MaterialPalette.color(presentation.currentBackgroundColorToken, default: .clear))
    .tint(MaterialPalette.color(presentation.currentIconColorToken))
    .disabled(node.bool("disabled") == true)
    .modifier(ChromeClipModifier(behavior: presentation.clipBehaviorToken))
    .animation(presentation.animation, value: expanded)
    .accessibilityHint(expanded ? "Collapse" : "Expand")
  }

  private var nativeHeader: some View {
    HStack(spacing: 12) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
      }
      VStack(alignment: .leading, spacing: 2) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
        } else if let title = node.string("title") { Text(title) }
        if let subtitleID = node.controlID(forKey: "subtitle") {
          ControlView(id: subtitleID, axis: .none)
        } else if let subtitle = node.string("subtitle") { Text(subtitle) }
      }
      Spacer(minLength: 0)
      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      }
    }
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
    .contentShape(Rectangle())
  }
}

enum ExpansionCrossAxisAlignment: String {
  case start, center, end, stretch

  var alignment: Alignment {
    switch self {
    case .start: return .leading
    case .center, .stretch: return .center
    case .end: return .trailing
    }
  }
}

struct ExpansionTilePresentation {
  let node: ControlNode

  static func validationMessage(_ node: ControlNode, title: ControlNode? = nil) -> String? {
    let hasTitle: Bool
    if node.controlID(forKey: "title") != nil {
      hasTitle = RufletRequiredContent.isVisible(title)
    } else {
      // `buildTextOrWidget` turns even an empty String into a Text widget.
      hasTitle = node.props["title"]?.stringValue != nil
    }
    if !hasTitle { return "ExpansionTile.title must be provided and visible" }
    if node.string("expanded_cross_axis_alignment")?.lowercased() == "baseline" {
      return "CrossAxisAlignment.BASELINE is not supported since the expanded controls are aligned in a column, not a row. Try aligning the controls differently."
    }
    return nil
  }

  /// Flutter's `_ExpansionTileDefaultsM3` theme fallbacks. Explicit DSL
  /// values take precedence, while these semantic roles remain available to
  /// the native control instead of being discarded on Apple platforms.
  var textColorToken: String { node.string("text_color") ?? "onsurface" }
  var iconColorToken: String { node.string("icon_color") ?? "primary" }
  var collapsedTextColorToken: String { node.string("collapsed_text_color") ?? "onsurface" }
  var collapsedIconColorToken: String {
    node.string("collapsed_icon_color") ?? "onsurfacevariant"
  }
  var backgroundColorToken: String { node.string("bgcolor") ?? "transparent" }
  var collapsedBackgroundColorToken: String {
    node.string("collapsed_bgcolor") ?? "transparent"
  }
  var currentTextColorToken: String { expanded ? textColorToken : collapsedTextColorToken }
  var currentIconColorToken: String { expanded ? iconColorToken : collapsedIconColorToken }
  var currentBackgroundColorToken: String {
    expanded ? backgroundColorToken : collapsedBackgroundColorToken
  }
  private var expanded: Bool { node.bool("expanded") ?? false }
  var iconAffinityToken: String {
    let value = node.string("affinity")?.lowercased()
    return value == "leading" ? "leading" : (value == "platform" ? "platform" : "trailing")
  }
  var showsTrailingIcon: Bool { node.bool("show_trailing_icon") != false }
  var maintainState: Bool { node.bool("maintain_state") ?? false }
  var enableFeedback: Bool { node.bool("enable_feedback") ?? true }
  var dense: Bool? { node.bool("dense") }
  var clipBehaviorToken: String { node.string("clip_behavior") ?? "antiAlias" }
  var animationDuration: TimeInterval {
    max(node.map("animation_style")?["duration"]?.doubleValue ?? 200, 0) / 1_000
  }
  var animationCurveToken: String {
    node.map("animation_style")?["curve"]?.stringValue?.lowercased() ?? "easein"
  }
  var reverseAnimationCurveToken: String {
    node.map("animation_style")?["reverse_curve"]?.stringValue?.lowercased()
      ?? animationCurveToken
  }
  var animation: Animation {
    RufletCurve.animation(animationCurveToken, duration: animationDuration)
  }
  var expandedAlignmentToken: String {
    node.string("expanded_alignment")?.lowercased() ?? "center"
  }
  var expandedCrossAxisAlignmentToken: String {
    node.string("expanded_cross_axis_alignment")?.lowercased() ?? "center"
  }

  var expandedAlignment: Alignment {
    ControlProps.alignment(node.props["expanded_alignment"]) ?? .center
  }
  var expandedCrossAxisAlignment: ExpansionCrossAxisAlignment {
    ExpansionCrossAxisAlignment(rawValue: expandedCrossAxisAlignmentToken) ?? .center
  }
  var tilePadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["tile_padding"])
      ?? EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
  }
  var controlsPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["controls_padding"]) ?? EdgeInsets()
  }

  var minTileHeight: CGFloat? {
    if let explicit = node.double("min_tile_height") { return CGFloat(explicit) }
    return nil
  }

  /// ListTile's constructor/theme fallback before visual-density adjustment:
  /// one-line 56/48 and two-line 72/64 for regular/dense tiles.
  var effectiveMinimumTileHeight: CGFloat {
    if let minTileHeight { return minTileHeight }
    let hasSubtitle = node.controlID(forKey: "subtitle") != nil
      || !(node.string("subtitle") ?? "").isEmpty
    if dense == true { return hasSubtitle ? 64 : 48 }
    return hasSubtitle ? 72 : 56
  }

  var expandedShapeSemantic: String {
    node.props["shape"] == nil ? "border.vertical(theme.dividerColor)" : "explicit"
  }
  var collapsedShapeSemantic: String {
    node.props["collapsed_shape"] == nil ? "border.vertical(transparent)" : "explicit"
  }
}

/// `ExpansionPanelList` — several independently expandable panels.
struct ExpansionPanelListControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    let presentation = ExpansionPanelListPresentation(node: node)
    // Flet builds the list from `children("controls")`, which contains only
    // visible controls. ExpansionPanel is structural and never reaches its
    // own ControlView, so the list must apply visibility before layout and
    // before assigning the callback index.
    let panels = ExpansionPanelListPresentation.visiblePanels(
      node.childIDs.compactMap { store.node($0) })
    if let message = presentation.validationMessage {
      Text(message).font(.caption).foregroundStyle(.red)
    } else {
      VStack(spacing: 0) {
        ForEach(Array(panels.enumerated()), id: \.element.id) { index, panel in
          NativeExpansionPanelView(node: panel, list: node, visibleIndex: index)
            .shadow(
              color: panel.bool("expanded") == true ? .black.opacity(0.2) : .clear,
              radius: panel.bool("expanded") == true ? presentation.elevation : 0)
          if index < panels.count - 1 {
            let nextExpanded = panels[index + 1].bool("expanded") == true
            if presentation.hasGap(
              afterExpanded: panel.bool("expanded") == true,
              beforeExpanded: nextExpanded)
            {
              Color.clear.frame(height: presentation.spacing)
            } else {
              Rectangle()
                .fill(MaterialPalette.color(presentation.dividerColorToken, default: .clear))
                .frame(height: 1)
            }
          }
        }
      }
      .animation(presentation.animation, value: panels.map { $0.bool("expanded") ?? false })
    }
  }
}

struct ExpansionPanelListPresentation {
  let node: ControlNode
  var validationMessage: String? {
    elevation < 0 ? "ExpansionPanelList.elevation must be greater than or equal to zero" : nil
  }
  var elevation: CGFloat { CGFloat(node.double("elevation") ?? 2) }
  var spacing: CGFloat { CGFloat(node.double("spacing") ?? 16) }
  var expandedHeaderPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["expanded_header_padding"])
      ?? EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
  }
  var animationDuration: TimeInterval { 0.2 }
  var animation: Animation {
    RufletCurve.animation("fastoutslowin", duration: animationDuration)
  }
  var dividerColorToken: String { node.string("divider_color") ?? "outline" }
  var expandIconColorToken: String? {
    // `expand_icon_color` is the Ruflet/Flet public property. The earlier Dart
    // renderer used `expanded_icon_color`; accepting it preserves old streams.
    node.string("expand_icon_color") ?? node.string("expanded_icon_color")
  }
  var defaultExpandIconColorSemantic: String { "black54(light)/white60(dark)" }

  static func visiblePanels(_ panels: [ControlNode]) -> [ControlNode] {
    panels.filter { $0.bool("visible") != false }
  }

  func hasGap(afterExpanded: Bool, beforeExpanded: Bool) -> Bool {
    // ExpansionPanelList inserts a MaterialGap on either side of an expanded
    // slice. Between two expanded slices the adjacent gaps merge into one.
    afterExpanded || beforeExpanded
  }
}

struct ExpansionPanelPresentation {
  let node: ControlNode

  var expanded: Bool { node.bool("expanded") ?? false }
  var canTapHeader: Bool { node.bool("can_tap_header") ?? false }
  var backgroundColorToken: String { node.string("bgcolor") ?? "surface" }
  var splashColorToken: String? { node.string("splash_color") }
  var highlightColorToken: String? { node.string("highlight_color") }
  var hasHeader: Bool { node.controlID(forKey: "header") != nil }
  var hasContent: Bool { node.controlID(forKey: "content") != nil }
}

/// Apple's DisclosureGroup is the native equivalent for every panel. The
/// panel's wire state and Flet list-level change event remain authoritative.
private struct NativeExpansionPanelView: View {
  let node: ControlNode
  let list: ControlNode
  let visibleIndex: Int
  @Environment(\.rufletEvents) private var events
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let presentation = ExpansionPanelListPresentation(node: list)
    let panel = ExpansionPanelPresentation(node: node)
    DisclosureGroup(isExpanded: expansionBinding) {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
      } else {
        Text("Body Placeholder").padding()
      }
    } label: {
      Group {
        if let headerID = node.controlID(forKey: "header") {
          ControlView(id: headerID, axis: .none)
        } else {
          Text("Header Placeholder").padding()
        }
      }
      .padding(expanded ? presentation.expandedHeaderPadding : EdgeInsets())
    }
    .frame(minHeight: 48)
    .background(MaterialPalette.color(panel.backgroundColorToken, default: .clear))
    .tint(expandIconColor)
    .disabled(list.bool("disabled") == true)
    .animation(presentation.animation, value: expanded)
  }

  private var expanded: Bool { node.bool("expanded") ?? false }

  private var expandIconColor: Color {
    if let explicit = MaterialPalette.color(
      ExpansionPanelListPresentation(node: list).expandIconColorToken)
    {
      return explicit
    }
    return colorScheme == .dark ? .white.opacity(0.60) : .black.opacity(0.54)
  }

  private var expansionBinding: Binding<Bool> {
    Binding(
      get: { expanded },
      set: { next in
        guard list.bool("disabled") != true, next != expanded else { return }
        events.setLocal(node.id, "expanded", .bool(next))
        events.update(node.id, ["expanded": .bool(next)])
        events.fire(
          list, "change",
          data: .int(Int64(visibleIndex)))
      })
  }
}

private struct RufletTabSelectionKey: EnvironmentKey {
  static let defaultValue: Binding<Int>? = nil
}

private extension EnvironmentValues {
  var rufletTabSelection: Binding<Int>? {
    get { self[RufletTabSelectionKey.self] }
    set { self[RufletTabSelectionKey.self] = newValue }
  }
}

struct TabsPresentation {
  let node: ControlNode
  static let moveDefaultCurveToken = "easeIn"

  var length: Int { node.int("length") ?? 0 }
  var rawSelectedIndex: Int { node.int("selected_index") ?? 0 }
  var selectedIndex: Int {
    CollectionParity.normalizedIndex(rawSelectedIndex, count: length)
  }
  var animationDuration: TimeInterval {
    max(node.double("animation_duration") ?? 100, 0) / 1_000
  }

  static func preservedIndex(_ current: Int, forDeliveredLength length: Int) -> Int {
    CollectionParity.normalizedIndex(current, count: length)
  }

  static func validationMessage(_ node: ControlNode) -> String? {
    validationMessage(node, contentIsVisible: node.controlID(forKey: "content") != nil)
  }

  static func validationMessage(_ node: ControlNode, contentIsVisible: Bool) -> String? {
    let length = node.int("length") ?? 0
    let selected = node.int("selected_index") ?? 0
    if length < 0 {
      return "length must be greater than or equal to 0, got \(length)"
    }
    if !(-length <= selected && selected < length) {
      return "selected_index out of range: got \(selected), expected in range [-\(length), \(length - 1)]"
    }
    if node.controlID(forKey: "content") == nil || !contentIsVisible {
      return "Tabs.content must be provided and visible"
    }
    return nil
  }

  static func moveValidationMessage(index: Int, length: Int) -> String? {
    guard -length <= index && index < length else {
      return "index out of range: got \(index), expected in range [-\(length), \(length - 1)]"
    }
    return nil
  }
}

struct TabPresentation {
  let node: ControlNode

  var hasLabel: Bool {
    node.string("label") != nil || node.string("text") != nil
      || node.controlID(forKey: "label") != nil
  }
  var hasIcon: Bool {
    (node.props["icon"] != nil && node.props["icon"]?.isNull == false)
      || node.controlID(forKey: "icon") != nil
  }
  var height: CGFloat { CollectionDefaults.tabHeight(node) }
  var iconMargin: EdgeInsets {
    ControlProps.edgeInsets(node.props["icon_margin"])
      ?? EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)
  }

  static func validationMessage(_ node: ControlNode) -> String? {
    guard node.type == "Tab" else { return nil }
    let values = TabPresentation(node: node)
    return values.hasLabel || values.hasIcon
      ? nil : "Tab must have at least label or icon property set"
  }
}

struct TabBarPresentation {
  let node: ControlNode
  static let ancestorError = "TabBar must be used within a Tabs control"

  var values: CollectionDefaults.TabBarValues { CollectionDefaults.tabBar(node) }

  /// All TabBars use Apple's native selector. Material-only properties remain
  /// in `values` for source parity and are translated only where SwiftUI has a
  /// corresponding modifier; they never opt into a handwritten strip.
  static func usesNativeAppearance(_: ControlNode) -> Bool { true }

  /// `Tab` is structural metadata owned by `TabBar`. Dart obtains it through
  /// `children("tabs")`, whose default contract excludes invisible children
  /// before constructing the native tab indices.
  static func visibleTabs(_ tabs: [ControlNode]) -> [ControlNode] {
    tabs.filter { $0.bool("visible") != false }
  }

  static func validationMessage(_ node: ControlNode) -> String? {
    let values = CollectionDefaults.tabBar(node)
    if node.map("indicator") == nil && values.indicatorThickness <= 0 {
      return "indicator_thickness must be strictly greater than zero if indicator is None, got \(values.indicatorThickness)"
    }
    guard node.props["tab_alignment"] != nil else { return nil }
    let valid = values.scrollable
      ? ["start", "startoffset", "center"] : ["center", "fill"]
    if !valid.contains(values.tabAlignmentToken.lowercased()) {
      let names = values.scrollable
        ? "TabAlignment.START, TabAlignment.START_OFFSET, TabAlignment.CENTER"
        : "TabAlignment.CENTER, TabAlignment.FILL"
      return "If scrollable is \(values.scrollable ? "True" : "False"), tab_alignment must be one of: \(names)."
    }
    return nil
  }
}

struct TabBarViewPresentation {
  let node: ControlNode
  static let ancestorError = "TabBarView must be used within a Tabs control"
  var clipBehaviorToken: String { node.string("clip_behavior") ?? "hardEdge" }
  var viewportFraction: Double { node.double("viewport_fraction") ?? 1 }
}

/// `Tabs` owns the selection controller. Its content owns the actual TabBar
/// and TabBarView, exactly as Flet's ancestor TabController contract does.
struct TabsControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var selectedIndex: Int

  init(node: ControlNode) {
    self.node = node
    _selectedIndex = State(initialValue: TabsPresentation(node: node).selectedIndex)
  }

  var body: some View {
    let contentID = node.controlID(forKey: "content")
    let content = contentID.flatMap { store.node($0) }
    let contentIsVisible = RufletRequiredContent.isVisible(content)
    let validationMessage = TabsPresentation.validationMessage(
      node, contentIsVisible: contentIsVisible)
    Group {
      if let message = validationMessage {
        Text(message).font(.caption).foregroundStyle(.red)
      } else if let contentID {
        ControlView(id: contentID, axis: .vertical)
      } else {
        EmptyView()
      }
    }
    .environment(\.rufletTabSelection, Binding(
      get: { selectedIndex },
      set: { move(to: $0, curve: "ease", duration: TabsPresentation(node: node).animationDuration) }))
    .onChange(of: selectedIndex) { value in
      events.setLocal(node.id, "selected_index", .int(Int64(value)))
      events.fire(node, "change", data: .int(Int64(value)))
    }
    .onChange(of: node.int("selected_index") ?? 0) { value in
      move(to: value, curve: "ease", duration: TabsPresentation(node: node).animationDuration)
    }
    .onChange(of: node.int("length") ?? 0) { length in
      // Flet recreates its TabController when length changes and preserves the
      // current mounted index, clamped to the new range.
      let preserved = TabsPresentation.preservedIndex(
        selectedIndex, forDeliveredLength: length)
      guard preserved != selectedIndex else { return }
      selectedIndex = preserved
      events.setLocal(node.id, "selected_index", .int(Int64(preserved)))
      events.update(node.id, ["selected_index": .int(Int64(preserved))])
    }
    .rufletCommandHandler(node.id, handler: handleCommand)
  }

  private func move(to index: Int, curve: String, duration: TimeInterval) {
    let resolved = CollectionParity.normalizedIndex(index, count: node.int("length") ?? 0)
    guard resolved != selectedIndex else { return }
    withAnimation(RufletCurve.animation(curve, duration: duration)) {
      selectedIndex = resolved
    }
  }

  private func handleCommand(
    _ call: RufletMethodCall,
    completion: @escaping RufletMethodCompletion
  ) {
    guard call.name == "move_to" else {
      return completion(.failure(rufletUnsupported("Tabs", call)))
    }
    guard let index = call.argument("index")?.intValue else {
      return completion(.failure(RufletServiceError.invalidArguments("index is required")))
    }
    let length = node.int("length") ?? 0
    if let message = TabsPresentation.moveValidationMessage(index: index, length: length) {
      return completion(.failure(RufletServiceError.invalidArguments(message)))
    }
    let curve = call.argument("curve")?.stringValue
      ?? TabsPresentation.moveDefaultCurveToken
    let duration = max(
      call.argument("duration")?.doubleValue ?? node.double("animation_duration") ?? 100,
      0) / 1_000
    move(to: index, curve: curve, duration: duration)
    completion(.success(.null))
  }
}

/// Flet's Material TabBar, with parent-owned `Tab` metadata.
struct TabBarControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletTabSelection) private var selection

  var body: some View {
    let tabs = TabBarPresentation.visibleTabs(
      node.controlIDs(forKey: "tabs").compactMap { store.node($0) })

    Group {
      if selection == nil {
        Text(TabBarPresentation.ancestorError).font(.caption).foregroundStyle(.red)
      } else if let message = TabBarPresentation.validationMessage(node) {
        Text(message).font(.caption).foregroundStyle(.red)
      } else {
        nativePicker(tabs)
      }
    }
    .disabled(node.bool("disabled") == true)
  }

  /// A Flet TabBar maps to Apple's native selector for every property set.
  /// Scrollability, padding, alignment, feedback, tab heights and slots have
  /// native translations. Material indicator/divider/ripple semantics remain
  /// modelled by `TabBarValues` where SwiftUI exposes no equivalent hook.
  @ViewBuilder
  private func nativePicker(_ tabs: [ControlNode]) -> some View {
    let values = CollectionDefaults.tabBar(node)
    if values.scrollable {
      ScrollView(.horizontal, showsIndicators: false) {
        picker(tabs, values: values).fixedSize(horizontal: true, vertical: false)
      }
      .padding(values.padding)
      .frame(maxWidth: .infinity, alignment: values.nativeAlignment)
    } else {
      picker(tabs, values: values)
        .padding(values.padding)
        .frame(maxWidth: .infinity, alignment: values.nativeAlignment)
    }
  }

  private func picker(
    _ tabs: [ControlNode], values: CollectionDefaults.TabBarValues
  ) -> some View {
    Picker("", selection: Binding(
      get: { selection?.wrappedValue ?? 0 },
      set: { index in
        let resolved = CollectionParity.normalizedIndex(index, count: tabs.count)
        RufletTapFeedback.perform(enabled: values.enableFeedback)
        selection?.wrappedValue = resolved
        events.fire(node, "click", data: .int(Int64(index)))
      })) {
        ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
          tabLabel(tab)
            .foregroundColor(MaterialPalette.color(
              index == selection?.wrappedValue
                ? values.labelColorToken : values.unselectedLabelColorToken))
            .rufletTextStyle(labelStyle(
              selected: index == selection?.wrappedValue, values: values))
            .padding(values.labelPadding)
            .frame(minHeight: CollectionDefaults.tabHeight(tab))
            .tag(index)
            .onHover { hovering in
              events.fire(
                node, "hover",
                data: .map(["hovering": .bool(hovering), "index": .int(Int64(index))]))
            }
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
  }

  private func labelStyle(
    selected: Bool, values: CollectionDefaults.TabBarValues
  ) -> RufletTextStyle {
    let key = selected ? "label_text_style" : "unselected_label_text_style"
    var style = RufletTextStyle(node: node, styleKey: key)
    if node.map(key) == nil {
      style.themeStyle = RufletTextStyle.themeTextStyle(
        selected ? values.labelTextStyleToken : values.unselectedLabelTextStyleToken)
    }
    return style
  }

  @ViewBuilder
  private func tabLabel(_ tab: ControlNode) -> some View {
    let presentation = TabPresentation(node: tab)
    if tab.type != "Tab" {
      // Flet wraps arbitrary controls in a Flutter `Tab(child:)` so that the
      // native tab selector still owns sizing, selection and interaction.
      ControlView(id: tab.id, axis: .none)
    } else if let message = TabPresentation.validationMessage(tab) {
      Text(message).font(.caption).foregroundStyle(.red)
    } else if presentation.hasIcon && presentation.hasLabel {
      VStack(spacing: 0) {
        tabIcon(tab).padding(presentation.iconMargin)
        tabText(tab)
      }
    } else if presentation.hasLabel {
      tabText(tab)
    } else if presentation.hasIcon {
      tabIcon(tab)
    }
  }

  @ViewBuilder
  private func tabText(_ tab: ControlNode) -> some View {
    if let labelID = tab.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else if let label = tab.string("label") ?? tab.string("text") {
      Text(label).lineLimit(1)
    }
  }

  @ViewBuilder
  private func tabIcon(_ tab: ControlNode) -> some View {
    if let iconID = tab.controlID(forKey: "icon") {
      ControlView(id: iconID, axis: .none)
    } else if let icon = tab.props["icon"], !icon.isNull {
      RufletIcon(value: icon, size: CollectionDefaults.tabIconSize)
    }
  }
}

/// `TabBarView` — the pages behind a `TabBar`.
struct TabBarViewControlView: View {
  let node: ControlNode
  @Environment(\.rufletTabSelection) private var selection

  @ViewBuilder
  var body: some View {
    let children = node.childIDs
    let presentation = TabBarViewPresentation(node: node)
    if let selection {
      #if os(iOS)
        TabView(selection: selection) {
          ForEach(Array(children.enumerated()), id: \.element) { index, child in
            ControlView(id: child, axis: .vertical)
              .modifier(ViewportFraction(value: presentation.viewportFraction))
              .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .modifier(ChromeClipModifier(behavior: presentation.clipBehaviorToken))
      #else
        let selected = selection.wrappedValue
        if children.indices.contains(selected) {
          ControlView(id: children[selected], axis: .vertical)
            .modifier(ViewportFraction(value: presentation.viewportFraction))
            .modifier(ChromeClipModifier(behavior: presentation.clipBehaviorToken))
        }
      #endif
    } else {
      Text(TabBarViewPresentation.ancestorError)
        .font(.caption).foregroundStyle(.red)
    }
  }
}

/// `DataTable` — columns, rows and cells.
struct DataTableControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var columnWidths: [Int: CGFloat] = [:]

  var body: some View {
    let columns = DataTablePresentation.visibleStructuralIDs(
      node.controlIDs(forKey: "columns"), in: store.nodes).compactMap { store.node($0) }
    let rows = DataTablePresentation.visibleStructuralIDs(
      node.controlIDs(forKey: "rows"), in: store.nodes).compactMap { store.node($0) }
    let metrics = CollectionDefaults.dataTable(node)
    let showsCheckboxes = metrics.showCheckboxColumn
      && rows.contains(where: { $0.handlesEvent("select_change") })

    if #available(iOS 16.0, macOS 13.0, *) {
      nativeDataTable(columns: columns, rows: rows, showsCheckboxes: showsCheckboxes)
    } else {
      legacyDataTable(columns: columns, rows: rows, metrics: metrics,
        showsCheckboxes: showsCheckboxes)
    }
  }

  /// SwiftUI does not expose a type-erased `TableColumn`, so Ruflet's dynamic
  /// protocol columns use the native `Grid` layout primitive. The primitive is
  /// Apple-native, while its resolved geometry remains the exact Flet/Flutter
  /// constructor contract (explicit value -> theme default -> constructor
  /// default). This deliberately separates semantics from visual imitation.
  @available(iOS 16.0, macOS 13.0, *)
  private func nativeDataTable(
    columns: [ControlNode], rows: [ControlNode], showsCheckboxes: Bool
  ) -> some View {
    let nativeMetrics = DataTablePresentation.nativeMetrics(node)
    return ScrollView(.horizontal, showsIndicators: true) {
      Grid(
        alignment: .leading,
        horizontalSpacing: nativeMetrics.columnSpacing,
        verticalSpacing: nil
      ) {
        GridRow {
          if showsCheckboxes {
            nativeSelectAllToggle(rows)
              .modifier(NativeDataTableCheckboxMargin(node: node))
          }
          ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
            nativeHeaderCell(column, index: index)
              .gridColumnAlignment(headingHorizontalAlignment(column))
              .modifier(NativeDataTableCellPadding(
                node: node, column: index, columnCount: columns.count,
                checkboxVisible: showsCheckboxes))
          }
        }
        .frame(height: nativeMetrics.headingRowHeight)
        .background(headingBackground)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "heading_text_style"))

        nativeDivider

        ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
          GridRow {
            if showsCheckboxes {
              nativeRowSelectionToggle(row)
                .modifier(NativeDataTableCheckboxMargin(node: node))
            }
            ForEach(Array(visibleCellIDs(row).enumerated()), id: \.element) {
              index, cellID in
              cellContent(cellID, row: row, numeric: columns.indices.contains(index)
                && columns[index].bool("numeric") == true)
                .gridColumnAlignment(columns.indices.contains(index)
                  && columns[index].bool("numeric") == true ? .trailing : .leading)
                .modifier(NativeDataTableCellPadding(
                  node: node, column: index, columnCount: columns.count,
                  checkboxVisible: showsCheckboxes))
            }
          }
          .frame(
            minHeight: nativeMetrics.dataRowMinHeight,
            maxHeight: nativeMetrics.dataRowMaxHeight)
          .frame(maxWidth: .infinity, alignment: .leading)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "data_text_style"))
          .background(rowBackground(row))
          .overlay(alignment: .bottom) { horizontalRule }
          .contentShape(Rectangle())

          if rowIndex < rows.count - 1 || node.bool("show_bottom_border") == true {
            nativeDivider
          }
        }
      }
      .background { tableBackground }
      .overlay { tableBorder }
      .modifier(DataTableClip(
        behavior: node.string("clip_behavior") ?? "none", radii: tableRadii))
    }
  }

  private func legacyDataTable(
    columns: [ControlNode], rows: [ControlNode], metrics: CollectionDefaults.DataTableValues,
    showsCheckboxes: Bool
  ) -> some View {
    ScrollView(.horizontal, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 0) {
          if showsCheckboxes {
            Button { selectAll(rows) } label: {
              Image(systemName: headingCheckboxSymbol(rows))
            }
            .buttonStyle(.plain)
            .padding(.leading, metrics.checkboxMarginStart)
            .padding(.trailing, metrics.checkboxMarginEnd)
            .overlay(alignment: .trailing) { verticalRule }
            // Flutter invokes each selectable row when onSelectAll is null.
            .disabled(!node.handlesEvent("select_all") && selectableRows(rows).isEmpty)
          }
          ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
            headerCell(column, index: index)
              .modifier(DataTableColumnWidth(
                index: index, width: columnWidths[index],
                alignment: headingAlignment(column)))
              .padding(metrics.cellPadding(column: index, columnCount: columns.count,
                checkboxVisible: showsCheckboxes))
              .overlay(alignment: .trailing) {
                if index < columns.count - 1 { verticalRule }
              }
          }
        }
        .frame(height: metrics.headingRowHeight)
        .background(headingBackground)
        .font(.subheadline.weight(.semibold))
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "heading_text_style"))

        tableDivider

        ForEach(rows, id: \.id) { row in
          HStack(spacing: 0) {
            if showsCheckboxes {
              Button { selectRow(row, selected: !(row.bool("selected") ?? false)) } label: {
                Image(systemName: (row.bool("selected") ?? false) ? "checkmark.square.fill" : "square")
              }
              .buttonStyle(.plain)
              .padding(.leading, metrics.checkboxMarginStart)
              .padding(.trailing, metrics.checkboxMarginEnd)
              .overlay(alignment: .trailing) { verticalRule }
              .disabled(!row.handlesEvent("select_change"))
            }
            ForEach(Array(visibleCellIDs(row).enumerated()), id: \.element) {
              index, cellID in
              cellContent(cellID, row: row, numeric: columns.indices.contains(index)
                && columns[index].bool("numeric") == true)
                .modifier(DataTableColumnWidth(
                  index: index, width: columnWidths[index],
                  alignment: columns.indices.contains(index)
                    && columns[index].bool("numeric") == true ? .trailing : .leading))
                .padding(metrics.cellPadding(column: index, columnCount: columns.count,
                  checkboxVisible: showsCheckboxes))
                .overlay(alignment: .trailing) {
                  if index < columns.count - 1 { verticalRule }
                }
            }
          }
          .frame(minHeight: metrics.dataRowMinHeight, maxHeight: metrics.dataRowMaxHeight)
          .frame(maxWidth: .infinity, alignment: .leading)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "data_text_style"))
          .background(rowBackground(row))
          .overlay(alignment: .bottom) { horizontalRule }
          .contentShape(Rectangle())

          if metrics.dividerThickness > 0,
            row.id != rows.last?.id || metrics.showBottomBorder { tableDivider }
        }
      }
      .background { tableBackground }
      .overlay { tableBorder }
      .modifier(DataTableClip(
        behavior: node.string("clip_behavior") ?? "none", radii: tableRadii))
      .onPreferenceChange(DataTableColumnWidthPreference.self) { measured in
        var next = columnWidths
        for (index, width) in measured {
          next[index] = max(next[index] ?? 0, width)
        }
        if next != columnWidths { columnWidths = next }
      }
    }
  }

  @available(iOS 16.0, macOS 13.0, *)
  private func nativeSelectAllToggle(_ rows: [ControlNode]) -> some View {
    let selectable = selectableRows(rows)
    let allSelected = !selectable.isEmpty
      && selectable.allSatisfy { $0.bool("selected") == true }
    return Toggle("Select all", isOn: Binding(
      get: { allSelected },
      set: { _ in selectAll(rows) }
    ))
    .labelsHidden()
    .disabled(!node.handlesEvent("select_all") && selectable.isEmpty)
  }

  @available(iOS 16.0, macOS 13.0, *)
  private func nativeRowSelectionToggle(_ row: ControlNode) -> some View {
    Toggle("Select row", isOn: Binding(
      get: { row.bool("selected") ?? false },
      set: { selectRow(row, selected: $0) }
    ))
    .labelsHidden()
    .disabled(!row.handlesEvent("select_change"))
  }

  @available(iOS 16.0, macOS 13.0, *)
  @ViewBuilder
  private var nativeDivider: some View {
    if node.double("divider_thickness") != 0 {
      Divider()
        .gridCellUnsizedAxes(.horizontal)
        .modifier(NativeDataTableDivider(node: node))
    }
  }

  @available(iOS 16.0, macOS 13.0, *)
  @ViewBuilder
  private func nativeHeaderCell(_ column: ControlNode, index: Int) -> some View {
    if column.handlesEvent("sort") {
      Button {
        sort(column, index: index)
      } label: {
        HStack {
          if column.bool("numeric") == true { nativeSortIndicator(index) }
          columnLabel(column)
          if column.bool("numeric") != true { nativeSortIndicator(index) }
        }
      }
      .help(DataTablePresentation.tooltipMessage(column) ?? "")
    } else {
      columnLabel(column)
        .help(DataTablePresentation.tooltipMessage(column) ?? "")
    }
  }

  @available(iOS 16.0, macOS 13.0, *)
  @ViewBuilder
  private func columnLabel(_ column: ControlNode) -> some View {
    if let labelID = column.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else {
      Text(column.string("label") ?? "")
    }
  }

  @available(iOS 16.0, macOS 13.0, *)
  @ViewBuilder
  private func nativeSortIndicator(_ index: Int) -> some View {
    if node.int("sort_column_index") == index {
      Image(systemName: (node.bool("sort_ascending") ?? false) ? "chevron.up" : "chevron.down")
    }
  }

  private var tableDivider: some View {
    Rectangle()
      .fill(MaterialPalette.color(for: node, property: "divider_color", default: .clear))
      .frame(height: CollectionDefaults.dataTable(node).dividerThickness)
  }

  @ViewBuilder
  private func headerCell(_ column: ControlNode, index: Int) -> some View {
    Button {
      sort(column, index: index)
    } label: {
      HStack(spacing: 4) {
        if column.bool("numeric") == true, column.handlesEvent("sort") {
          sortArrow(index)
        }
        if let labelID = column.controlID(forKey: "label") {
          ControlView(id: labelID, axis: .none)
        } else {
          Text(column.string("label") ?? "")
        }
        if column.bool("numeric") != true, column.handlesEvent("sort") {
          sortArrow(index)
        }
      }
    }
    .buttonStyle(.plain)
    .help(DataTablePresentation.tooltipMessage(column) ?? "")
    .disabled(!column.handlesEvent("sort"))
  }

  private func sort(_ column: ControlNode, index: Int) {
    let ascending = DataTablePresentation.nextSortAscending(
      sortedColumn: node.int("sort_column_index"), tappedColumn: index,
      currentlyAscending: node.bool("sort_ascending") ?? false)
    events.fire(
      column, "sort",
      data: .map(["ci": .int(Int64(index)), "asc": .bool(ascending)]))
  }

  @ViewBuilder
  private func cellContent(_ cellID: Int, row: ControlNode, numeric: Bool) -> some View {
    if let cell = store.node(cellID) {
      HStack(spacing: 4) {
        if numeric, cell.bool("show_edit_icon") == true {
          Image(systemName: "pencil").font(.system(size: 18)).foregroundColor(.secondary)
        }
        Group {
          if let contentID = cell.controlID(forKey: "content") {
            ControlView(id: contentID, axis: .none)
          } else if let text = cell.string("content") {
            Text(text)
          }
        }
        if !numeric, cell.bool("show_edit_icon") == true {
          Image(systemName: "pencil").font(.system(size: 18)).foregroundColor(.secondary)
        }
      }
      .opacity(cell.bool("placeholder") == true ? 0.6 : 1)
      .contentShape(Rectangle())
      .modifier(DataCellInteractionReporter(node: cell, row: row, events: events))
    } else {
      ControlView(id: cellID, axis: .none)
    }
  }

  private func selectRow(_ row: ControlNode, selected: Bool) {
    guard row.handlesEvent("select_change") else { return }
    events.setLocal(row.id, "selected", .bool(selected))
    events.send(row.id, "select_change", .bool(selected))
  }

  private func selectableRows(_ rows: [ControlNode]) -> [ControlNode] {
    rows.filter { $0.handlesEvent("select_change") }
  }

  private func visibleCellIDs(_ row: ControlNode) -> [Int] {
    DataTablePresentation.visibleStructuralIDs(
      row.controlIDs(forKey: "cells"), in: store.nodes)
  }

  private func headingCheckboxSymbol(_ rows: [ControlNode]) -> String {
    let selectable = selectableRows(rows)
    let selectedCount = selectable.filter { $0.bool("selected") == true }.count
    if selectedCount > 0, selectedCount < selectable.count { return "minus.square.fill" }
    return selectedCount == selectable.count && !selectable.isEmpty
      ? "checkmark.square.fill" : "square"
  }

  /// `data_row_color` is a WidgetStateProperty: Flet sends the resting colour
  /// and the selected one under their state names.
  private func rowBackground(_ row: ControlNode) -> Color {
    let selected = row.bool("selected") ?? false
    let states: Set<RufletWidgetState> = selected ? [.selected] : []
    if let own = MaterialPalette.color(stateful: row.props["color"], in: states) {
      return own
    }
    if let table = MaterialPalette.color(stateful: node.props["data_row_color"], in: states) {
      return table
    }
    // With no DSL colour, the native row and Toggle supply Apple selection
    // appearance. Do not manufacture Flutter's Material primary overlay here.
    return .clear
  }

  /// `horizontal_lines` and `vertical_lines` are BorderSides drawn between
  /// the cells rather than around the table.
  @ViewBuilder
  private var horizontalRule: some View {
    if let side = node.map("horizontal_lLines") ?? node.map("horizontal_lines") {
      Rectangle()
        .fill(MaterialPalette.color(side["color"]?.stringValue, default: .clear))
        .frame(height: CGFloat(side["width"]?.doubleValue ?? 1))
    }
  }

  @ViewBuilder
  private var verticalRule: some View {
    if let side = node.map("vertical_lines") {
      Rectangle()
        .fill(MaterialPalette.color(side["color"]?.stringValue, default: .clear))
        .frame(width: CGFloat(side["width"]?.doubleValue ?? 1))
    }
  }

  private func selectAll(_ rows: [ControlNode]) {
    let selected = DataTablePresentation.nextSelectAllValue(rows: rows)
    if node.handlesEvent("select_all") {
      events.fire(node, "select_all", data: .bool(selected))
      return
    }
    for change in DataTablePresentation.fallbackRowChanges(rows: rows, selected: selected) {
      events.setLocal(change.id, "selected", .bool(change.selected))
      if let row = rows.first(where: { $0.id == change.id }) {
        events.fire(row, "select_change", data: .bool(change.selected))
      }
    }
  }

  private var headingBackground: Color {
    MaterialPalette.color(stateful: node.props["heading_row_color"], in: []) ?? .clear
  }

  private func headingAlignment(_ column: ControlNode) -> Alignment {
    let numeric = column.bool("numeric") == true
    switch column.string("heading_row_alignment")?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "center", "spacearound", "spacebetween", "spaceevenly": return .center
    case "end": return numeric ? .leading : .trailing
    default: return numeric ? .trailing : .leading
    }
  }

  private func headingHorizontalAlignment(_ column: ControlNode) -> HorizontalAlignment {
    let numeric = column.bool("numeric") == true
    switch column.string("heading_row_alignment")?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "center", "spacearound", "spacebetween", "spaceevenly": return .center
    case "end": return numeric ? .leading : .trailing
    default: return numeric ? .trailing : .leading
    }
  }

  private func sortArrow(_ index: Int) -> some View {
    let sorted = node.int("sort_column_index") == index
    return Image(systemName: "arrow.up")
      .font(.caption)
      .rotationEffect((node.bool("sort_ascending") ?? false) ? .zero : .degrees(180))
      .opacity(sorted ? 1 : 0)
      .animation(.easeInOut(duration: 0.15), value: sorted)
      .animation(.easeInOut(duration: 0.15), value: node.bool("sort_ascending") ?? false)
  }

  private var tableRadii: RufletCornerRadii {
    ControlProps.cornerRadii(node.props["border_radius"]) ?? RufletCornerRadii(uniform: 0)
  }

  @ViewBuilder private var tableBackground: some View {
    let shape = RufletRoundedRectangle(radii: tableRadii)
    if let gradient = RufletWrapperGradient(node.props["gradient"]) {
      gradient.view.mask(shape)
    } else {
      shape.fill(MaterialPalette.color(node.string("bgcolor"), default: .clear))
    }
  }

  @ViewBuilder private var tableBorder: some View {
    DataTableBorderLayer(border: ControlProps.borderSides(node.props["border"]))
  }
}

enum DataTablePresentation {
  struct NativeMetrics: Equatable {
    let columnSpacing: CGFloat
    let horizontalMargin: CGFloat
    let headingRowHeight: CGFloat
    let dataRowMinHeight: CGFloat
    let dataRowMaxHeight: CGFloat
    let dividerThickness: CGFloat
    let checkboxMarginStart: CGFloat
    let checkboxMarginEnd: CGFloat
  }

  /// Columns, rows and cells are structural controls owned by DataTable.
  /// Dart obtains every level through `children(...)`, whose default contract
  /// removes invisible children before assigning column and row indices.
  static func visibleStructuralIDs(
    _ ids: [Int], in nodes: [Int: ControlNode]
  ) -> [Int] {
    ids.filter { id in
      nodes[id].map { $0.bool("visible") != false } == true
    }
  }

  /// Resolves the same values passed to Flutter's `DataTable` constructor.
  /// The renderer remains a SwiftUI `Grid`; these values are protocol
  /// semantics, not a request to reproduce the Material widget's appearance.
  static func nativeMetrics(_ node: ControlNode) -> NativeMetrics {
    let values = CollectionDefaults.dataTable(node)
    return NativeMetrics(
      columnSpacing: values.columnSpacing,
      horizontalMargin: values.horizontalMargin,
      headingRowHeight: values.headingRowHeight,
      dataRowMinHeight: values.dataRowMinHeight,
      dataRowMaxHeight: values.dataRowMaxHeight,
      dividerThickness: values.dividerThickness,
      checkboxMarginStart: values.checkboxMarginStart,
      checkboxMarginEnd: values.checkboxMarginEnd)
  }

  static func tooltipMessage(_ column: ControlNode) -> String? {
    column.string("tooltip") ?? column.map("tooltip")?["message"]?.stringValue
  }

  static func nextSortAscending(
    sortedColumn: Int?, tappedColumn: Int, currentlyAscending: Bool
  ) -> Bool {
    sortedColumn != tappedColumn || !currentlyAscending
  }

  static func nextSelectAllValue(rows: [ControlNode]) -> Bool {
    let selectable = rows.filter { $0.handlesEvent("select_change") }
    return !(!selectable.isEmpty && selectable.allSatisfy { $0.bool("selected") == true })
  }

  static func fallbackRowChanges(rows: [ControlNode], selected: Bool)
    -> [(id: Int, selected: Bool)]
  {
    rows.compactMap { row in
      guard row.handlesEvent("select_change"), row.bool("selected") != selected else { return nil }
      return (row.id, selected)
    }
  }

  static func cellOverridesRowInteraction(_ cell: ControlNode) -> Bool {
    ["tap", "double_tap", "long_press", "tap_cancel", "tap_down"]
      .contains(where: cell.handlesEvent)
  }
}

private struct DataTableClip: ViewModifier {
  let behavior: String
  let radii: RufletCornerRadii

  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" { content }
    else { content.clipShape(RufletRoundedRectangle(radii: radii)) }
  }
}

private struct NativeDataTableCellPadding: ViewModifier {
  let node: ControlNode
  let column: Int
  let columnCount: Int
  let checkboxVisible: Bool

  func body(content: Content) -> some View {
    let margin = DataTablePresentation.nativeMetrics(node).horizontalMargin
    content
      .padding(.leading, !checkboxVisible && column == 0 ? margin : 0)
      .padding(.trailing, column == columnCount - 1 ? margin : 0)
  }
}

private struct NativeDataTableCheckboxMargin: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let metrics = DataTablePresentation.nativeMetrics(node)
    content
      .padding(.leading, metrics.checkboxMarginStart)
      .padding(.trailing, metrics.checkboxMarginEnd)
  }
}

private struct NativeDataTableDivider: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    let thickness = DataTablePresentation.nativeMetrics(node).dividerThickness
    if let color = MaterialPalette.color(node.string("divider_color")) {
      content
        .frame(height: thickness)
        .overlay(color)
    } else {
      content.frame(height: thickness)
    }
  }
}

/// Flutter's `DataTable` computes an intrinsic width for each column once and
/// reuses it for the heading and every row. Independent SwiftUI `HStack`s do
/// not share those measurements, so this preference performs the same table-
/// wide max pass without introducing equal-width or Explorer-specific rules.
private struct DataTableColumnWidthPreference: PreferenceKey {
  static var defaultValue: [Int: CGFloat] = [:]

  static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
    for (index, width) in nextValue() {
      value[index] = max(value[index] ?? 0, width)
    }
  }
}

private struct DataTableColumnWidth: ViewModifier {
  let index: Int
  let width: CGFloat?
  let alignment: Alignment

  func body(content: Content) -> some View {
    content
      .fixedSize(horizontal: true, vertical: false)
      .background(GeometryReader { proxy in
        Color.clear.preference(
          key: DataTableColumnWidthPreference.self,
          value: [index: proxy.size.width])
      })
      .frame(width: width, alignment: alignment)
  }
}

private struct DataTableBorderLayer: View {
  let border: RufletBorder?

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      ZStack {
        if let side = border?.top {
          Rectangle().fill(side.color).frame(height: side.width)
            .position(x: size.width / 2, y: side.width / 2)
        }
        if let side = border?.bottom {
          Rectangle().fill(side.color).frame(height: side.width)
            .position(x: size.width / 2, y: size.height - side.width / 2)
        }
        if let side = border?.left {
          Rectangle().fill(side.color).frame(width: side.width)
            .position(x: side.width / 2, y: size.height / 2)
        }
        if let side = border?.right {
          Rectangle().fill(side.color).frame(width: side.width)
            .position(x: size.width - side.width / 2, y: size.height / 2)
        }
      }
    }
    .allowsHitTesting(false)
  }
}

/// Omitted values in this family come from Flutter constructors or Material
/// theme data. Keeping the resolution pure makes explicit DSL values and
/// upstream defaults follow the same path.
enum CollectionDefaults {
  /// Tab icons inherit Flutter's ambient IconTheme, whose Material default is
  /// 24 logical pixels. The native SF Symbol renderer consumes that semantic
  /// size instead of inferring a smaller value from Apple tab screenshots.
  static let tabIconSize = RufletThemeDefaults.materialIconButtonSize

  struct ListViewValues {
    let horizontal: Bool
    let spacing: CGFloat
    let dividerThickness: CGFloat
    let itemExtent: CGFloat?
    let cacheExtent: CGFloat?
    let semanticChildCount: Int?
    let reverse: Bool
    let firstItemPrototype: Bool
    let prototypeItemID: Int?
    let padding: EdgeInsets
    let lazy: Bool
    let showsIndicators: Bool
    let clipBehavior: String

    /// Flutter switches to `ListView.separated` whenever spacing is positive,
    /// and that constructor intentionally accepts neither itemExtent nor a
    /// prototypeItem.
    var usesPrototype: Bool {
      spacing == 0 && (prototypeItemID != nil || firstItemPrototype)
    }
  }

  struct GridViewValues {
    let horizontal: Bool
    let spacing: CGFloat
    let runSpacing: CGFloat
    let childAspectRatio: CGFloat
    let cacheExtent: CGFloat?
    let semanticChildCount: Int?
    let reverse: Bool
    let lazy: Bool
    let padding: EdgeInsets
    let showsIndicators: Bool
    let clipBehavior: String
    let runsCount: Int
    let maxExtent: CGFloat?
  }

  struct ListTileValues {
    let contentPadding: EdgeInsets
    let horizontalTitleGap: CGFloat
    let minLeadingWidth: CGFloat
    let minVerticalPadding: CGFloat
    let minHeight: CGFloat
  }

  struct TabBarValues {
    let scrollable: Bool
    let secondary: Bool
    let indicatorThickness: CGFloat
    let effectiveIndicatorThickness: CGFloat
    let indicatorSizeToken: String
    let indicatorAnimationToken: String
    let indicatorPadding: EdgeInsets
    let indicatorColorToken: String
    let dividerHeight: CGFloat
    let dividerColorToken: String
    let showsDivider: Bool
    let labelColorToken: String
    let unselectedLabelColorToken: String
    let labelTextStyleToken: String
    let unselectedLabelTextStyleToken: String
    let padding: EdgeInsets
    let labelPadding: EdgeInsets
    /// Flutter applies this only to the Material ink response. SwiftUI's
    /// native segmented Picker exposes no ripple shape, but the exact Flet
    /// geometry remains consumed and modelled rather than discarded.
    let splashBorderRadius: RufletCornerRadii?
    let tabAlignmentToken: String
    let enableFeedback: Bool

    var nativeAlignment: Alignment {
      switch tabAlignmentToken.lowercased() {
      case "center", "fill": return .center
      default: return .leading
      }
    }
  }

  struct DataTableValues {
    let columnSpacing: CGFloat
    let horizontalMargin: CGFloat
    let headingRowHeight: CGFloat
    let dataRowMinHeight: CGFloat
    let dataRowMaxHeight: CGFloat
    let dividerThickness: CGFloat
    let showBottomBorder: Bool
    let showCheckboxColumn: Bool
    let checkboxMarginStart: CGFloat
    let checkboxMarginEnd: CGFloat

    func cellPadding(column: Int, columnCount: Int, checkboxVisible: Bool) -> EdgeInsets {
      let leading: CGFloat
      if column == 0 {
        leading = checkboxVisible ? horizontalMargin / 2 : horizontalMargin
      } else {
        leading = columnSpacing / 2
      }
      let trailing = column == columnCount - 1 ? horizontalMargin : columnSpacing / 2
      return EdgeInsets(top: 0, leading: leading, bottom: 0, trailing: trailing)
    }
  }

  struct PageViewValues {
    let horizontal: Bool
    let reverse: Bool
    let keepPage: Bool
    let padEnds: Bool
    let implicitScrolling: Bool
    let snap: Bool
    let viewportFraction: CGFloat
    let selectedIndex: Int
    let clipBehavior: String
  }

  struct ReorderableListValues {
    let horizontal: Bool
    let reverse: Bool
    let itemExtent: CGFloat?
    let firstItemPrototype: Bool
    let padding: EdgeInsets
    let clipBehavior: String
    let cacheExtent: CGFloat?
    let anchor: CGFloat
    let autoScrollerVelocityScalar: CGFloat?
    let lazy: Bool
    let showDefaultDragHandles: Bool
    let showsIndicators: Bool
    let semanticChildCount: Int?
    let headerID: Int?
    let footerID: Int?
  }

  static func listView(_ node: ControlNode) -> ListViewValues {
    ListViewValues(
      horizontal: node.bool("horizontal") ?? false,
      spacing: CGFloat(node.double("spacing") ?? 0),
      dividerThickness: CGFloat(node.double("divider_thickness") ?? 0),
      itemExtent: node.double("spacing") == 0
        ? node.double("item_extent").map { CGFloat($0) } : nil,
      cacheExtent: node.double("cache_extent").map { CGFloat($0) },
      semanticChildCount: node.int("semantic_child_count"),
      reverse: node.bool("reverse") ?? false,
      firstItemPrototype: node.bool("first_item_prototype") ?? false,
      prototypeItemID: node.controlID(forKey: "prototype_item"),
      padding: ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(),
      lazy: node.bool("build_controls_on_demand") ?? true,
      showsIndicators: node.string("scroll") != "hidden",
      clipBehavior: node.string("clip_behavior") ?? "hardEdge")
  }

  static func gridView(_ node: ControlNode) -> GridViewValues {
    GridViewValues(
      horizontal: node.bool("horizontal") ?? false,
      spacing: CGFloat(node.double("spacing") ?? 10),
      runSpacing: CGFloat(node.double("run_spacing") ?? 10),
      childAspectRatio: CGFloat(node.double("child_aspect_ratio") ?? 1),
      cacheExtent: node.double("cache_extent").map { CGFloat($0) },
      semanticChildCount: node.int("semantic_child_count"),
      reverse: node.bool("reverse") ?? false,
      lazy: node.bool("build_controls_on_demand") ?? true,
      padding: ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(),
      showsIndicators: node.string("scroll") != "hidden",
      clipBehavior: node.string("clip_behavior") ?? "hardEdge",
      runsCount: max(node.int("runs_count") ?? 1, 1),
      maxExtent: node.double("max_extent").map { CGFloat(max($0, 1)) })
  }

  static func reorderableListView(_ node: ControlNode) -> ReorderableListValues {
    let itemExtent = node.double("item_extent").map { CGFloat($0) }
    let cacheExtent = node.double("cache_extent").map { CGFloat($0) }
    let velocity = node.double("auto_scroller_velocity_scalar").map { CGFloat($0) }
    return ReorderableListValues(
      horizontal: node.bool("horizontal") ?? false,
      reverse: node.bool("reverse") ?? false,
      itemExtent: itemExtent,
      firstItemPrototype: node.bool("first_item_prototype") ?? false,
      padding: ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(),
      clipBehavior: node.string("clip_behavior") ?? "hardEdge",
      cacheExtent: cacheExtent,
      anchor: CGFloat(node.double("anchor") ?? 0),
      autoScrollerVelocityScalar: velocity,
      lazy: node.bool("build_controls_on_demand") ?? true,
      showDefaultDragHandles: node.bool("show_default_drag_handles") ?? true,
      showsIndicators: node.string("scroll") != "hidden",
      semanticChildCount: node.int("semantic_child_count"),
      headerID: node.controlID(forKey: "header"),
      footerID: node.controlID(forKey: "footer"))
  }

  static func listTile(_ node: ControlNode) -> ListTileValues {
    let dense = node.bool("dense") == true
    let hasSubtitle = node.props["subtitle"] != nil || node.controlID(forKey: "subtitle") != nil
    let defaultHeight: CGFloat = node.bool("is_three_line") == true
      ? 88 : (hasSubtitle ? 72 : RufletThemeDefaults.listTileMinHeight)
    return ListTileValues(
      contentPadding: ControlProps.edgeInsets(node.props["content_padding"])
        ?? RufletThemeDefaults.listTileContentPadding,
      horizontalTitleGap: CGFloat(node.double("horizontal_spacing")
        ?? Double(RufletThemeDefaults.listTileHorizontalTitleGap)),
      minLeadingWidth: CGFloat(node.double("min_leading_width")
        ?? Double(RufletThemeDefaults.listTileMinLeadingWidth)),
      minVerticalPadding: CGFloat(node.double("min_vertical_padding")
        ?? Double(RufletThemeDefaults.listTileMinVerticalPadding)),
      minHeight: CGFloat(node.double("min_height") ?? Double(defaultHeight - (dense ? 8 : 0))))
  }

  static func tabBar(_ node: ControlNode) -> TabBarValues {
    let scrollable = node.bool("scrollable") ?? true
    let secondary = node.bool("secondary") ?? false
    let indicatorSize = node.string("indicator_size")?.lowercased()
      ?? (secondary ? "tab" : "label")
    let requestedThickness = CGFloat(node.double("indicator_thickness") ?? 2)
    let effectiveThickness: CGFloat
    if node.map("indicator") != nil {
      effectiveThickness = requestedThickness
    } else if secondary {
      effectiveThickness = max(requestedThickness, 2)
    } else {
      effectiveThickness = max(requestedThickness, indicatorSize == "label" ? 3 : 2)
    }
    let dividerHeight = CGFloat(node.double("divider_height")
      ?? Double(RufletThemeDefaults.tabBarDividerHeight))
    let dividerColor = node.string("divider_color") ?? "outlinevariant"
    return TabBarValues(
      scrollable: scrollable,
      secondary: secondary,
      indicatorThickness: requestedThickness,
      effectiveIndicatorThickness: effectiveThickness,
      indicatorSizeToken: indicatorSize,
      indicatorAnimationToken: node.string("indicator_animation")?.lowercased()
        ?? (indicatorSize == "label" ? "elastic" : "linear"),
      indicatorPadding: ControlProps.edgeInsets(node.props["indicator_padding"])
        ?? EdgeInsets(),
      indicatorColorToken: node.string("indicator_color") ?? "primary",
      dividerHeight: dividerHeight,
      dividerColorToken: dividerColor,
      showsDivider: dividerHeight > 0 && dividerColor.lowercased() != "transparent",
      labelColorToken: node.string("label_color") ?? (secondary ? "onsurface" : "primary"),
      unselectedLabelColorToken: node.string("unselected_label_color")
        ?? "onsurfacevariant",
      labelTextStyleToken: node.map("label_text_style")?["theme_style"]?.stringValue
        ?? "titlesmall",
      unselectedLabelTextStyleToken:
        node.map("unselected_label_text_style")?["theme_style"]?.stringValue ?? "titlesmall",
      padding: ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(),
      labelPadding: ControlProps.edgeInsets(node.props["label_padding"])
        ?? RufletThemeDefaults.tabBarLabelPadding,
      splashBorderRadius: ControlProps.cornerRadii(node.props["splash_border_radius"]),
      tabAlignmentToken: node.string("tab_alignment")
        ?? (scrollable ? "startOffset" : "fill"),
      enableFeedback: node.bool("enable_feedback") ?? true)
  }

  static func tabHeight(_ tab: ControlNode) -> CGFloat {
    if let height = tab.double("height") { return CGFloat(height) }
    let hasIcon = (tab.props["icon"] != nil && tab.props["icon"]?.isNull == false)
      || tab.controlID(forKey: "icon") != nil
    let hasLabel = tab.string("label") != nil || tab.string("text") != nil
      || tab.controlID(forKey: "label") != nil
    return hasIcon && hasLabel
      ? RufletThemeDefaults.tabHeightWithIconAndLabel : RufletThemeDefaults.tabHeight
  }

  static func dataTable(_ node: ControlNode) -> DataTableValues {
    let horizontalMargin = CGFloat(node.double("horizontal_margin")
      ?? Double(RufletThemeDefaults.dataTableHorizontalMargin))
    let explicitCheckboxMargin = node.double("checkbox_horizontal_margin").map { CGFloat($0) }
    return DataTableValues(
      columnSpacing: CGFloat(node.double("column_spacing")
        ?? Double(RufletThemeDefaults.dataTableColumnSpacing)),
      horizontalMargin: horizontalMargin,
      headingRowHeight: CGFloat(node.double("heading_row_height")
        ?? Double(RufletThemeDefaults.dataTableHeadingHeight)),
      dataRowMinHeight: CGFloat(node.double("data_row_min_height")
        ?? Double(RufletThemeDefaults.dataTableRowMinHeight)),
      dataRowMaxHeight: CGFloat(node.double("data_row_max_height")
        ?? Double(RufletThemeDefaults.dataTableRowMaxHeight)),
      dividerThickness: CGFloat(node.double("divider_thickness") ?? 1),
      showBottomBorder: node.bool("show_bottom_border") ?? false,
      showCheckboxColumn: node.bool("show_checkbox_column") ?? false,
      checkboxMarginStart: explicitCheckboxMargin ?? horizontalMargin,
      checkboxMarginEnd: explicitCheckboxMargin ?? horizontalMargin / 2)
  }

  static func pageView(_ node: ControlNode) -> PageViewValues {
    PageViewValues(
      horizontal: node.bool("horizontal") ?? true,
      reverse: node.bool("reverse") ?? false,
      keepPage: node.bool("keep_page") ?? true,
      padEnds: node.bool("pad_ends") ?? true,
      implicitScrolling: node.bool("implicit_scrolling") ?? false,
      snap: node.bool("snap") ?? true,
      viewportFraction: CGFloat(node.double("viewport_fraction") ?? 1),
      selectedIndex: node.int("selected_index") ?? 0,
      clipBehavior: node.string("clip_behavior") ?? "hardEdge")
  }
}

private struct CollectionClip: ViewModifier {
  let behavior: String
  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" { content } else { content.clipped() }
  }
}

/// Flet's separated list reserves exactly `spacing` points between adjacent
/// controls and paints the optional divider inside that reserved extent.
/// Keeping the clear extent separate from the rule prevents stack spacing
/// from being counted twice.
private struct CollectionListSeparator: View {
  let horizontal: Bool
  let extent: CGFloat
  let thickness: CGFloat
  let color: Color?

  var body: some View {
    Color.clear
      .frame(
        width: horizontal ? extent : nil,
        height: horizontal ? nil : extent)
      .overlay {
        if thickness > 0 {
          if let color {
            Rectangle()
              .fill(color)
              .frame(
                width: horizontal ? thickness : nil,
                height: horizontal ? nil : thickness)
          } else {
            // Divider supplies the platform's native separator appearance
            // whenever the DSL did not provide a colour.
            Divider()
              .frame(
                width: horizontal ? thickness : nil,
                height: horizontal ? nil : thickness)
          }
        }
      }
  }
}

private struct CollectionPrototypeExtentKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Flutter's `prototypeItem` measures a real control and reuses that main-axis
/// extent for every row. Geometry preferences provide the equivalent without
/// inventing a fixed Apple or Material row height.
private struct CollectionPrototypeMeasure: ViewModifier {
  var enabled = true
  let horizontal: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.background(GeometryReader { proxy in
        Color.clear.preference(
          key: CollectionPrototypeExtentKey.self,
          value: horizontal ? proxy.size.width : proxy.size.height)
      })
    } else {
      content
    }
  }
}

private struct PageAxis: ViewModifier {
  let horizontal: Bool
  func body(content: Content) -> some View {
    content.rotationEffect(.degrees(horizontal ? 0 : -90))
  }
}

private struct PageViewport: ViewModifier {
  let horizontal: Bool
  let fraction: CGFloat
  let padEnds: Bool

  func body(content: Content) -> some View {
    GeometryReader { proxy in
      let clamped = min(max(fraction, 0.01), 1)
      content
        .rotationEffect(.degrees(horizontal ? 0 : 90))
        .frame(
          width: horizontal ? proxy.size.width * clamped : proxy.size.width,
          height: horizontal ? proxy.size.height : proxy.size.height * clamped)
        .frame(
          maxWidth: .infinity, maxHeight: .infinity,
          alignment: padEnds ? .center : .topLeading)
    }
  }
}

/// DataCell exposes five independent gestures in Flet. This modifier keeps
/// those handlers on the structural cell id instead of accidentally firing on
/// DataTable, which is the source of the current silent/double-click bug.
private struct DataCellInteractionReporter: ViewModifier {
  let node: ControlNode
  let row: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(DataCellTapReporter(node: node, row: row, events: events))
      .modifier(LongPressReporter(
        node: DataTablePresentation.cellOverridesRowInteraction(node) ? node : row,
        events: events))
      .modifier(DataCellPointerReporter(node: node, events: events))
  }
}

private struct DataCellPointerReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var pointerOrigin: CGPoint?

  func body(content: Content) -> some View {
    if node.handlesEvent("tap_down") || node.handlesEvent("tap_cancel") {
      content
      .simultaneousGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
          .onChanged { value in
            guard pointerOrigin == nil else { return }
            pointerOrigin = value.startLocation
            if node.handlesEvent("tap_down") {
              events.fire(
                node, "tap_down",
                data: CollectionParity.tapDownPayload(
                  x: value.startLocation.x, y: value.startLocation.y))
            }
          }
          .onEnded { value in
            defer { pointerOrigin = nil }
            guard node.handlesEvent("tap_cancel"), let origin = pointerOrigin else { return }
            let distance = hypot(value.location.x - origin.x, value.location.y - origin.y)
            if distance > 18 { events.fire(node, "tap_cancel") }
          })
    } else {
      content
    }
  }
}

private struct DataCellTapReporter: ViewModifier {
  let node: ControlNode
  let row: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if DataTablePresentation.cellOverridesRowInteraction(node) {
      if node.handlesEvent("double_tap") {
        content
          .onTapGesture(count: 2) { events.fire(node, "double_tap") }
          .modifier(DataCellSingleTap(node: node, events: events))
      } else {
        content.modifier(DataCellSingleTap(node: node, events: events))
      }
    } else if row.handlesEvent("select_change") {
      content.onTapGesture {
        let selected = !(row.bool("selected") ?? false)
        events.setLocal(row.id, "selected", .bool(selected))
        events.fire(row, "select_change", data: .bool(selected))
      }
    } else {
      content
    }
  }
}

private struct DataCellSingleTap: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("tap") {
      content.onTapGesture(count: 1) { events.fire(node, "tap") }
    } else { content }
  }
}

/// Pure collection semantics shared by views and regression tests.
enum CollectionParity {
  static func reorderDestination(from origin: Int, insertionSlot: Int) -> Int {
    insertionSlot > origin ? insertionSlot - 1 : insertionSlot
  }

  static func clampedIndex(_ index: Int, count: Int) -> Int {
    guard count > 0 else { return 0 }
    return min(max(index, 0), count - 1)
  }

  static func normalizedIndex(_ index: Int, count: Int) -> Int {
    clampedIndex(index < 0 ? count + index : index, count: count)
  }

  static func pageIndex(forOffset offset: Double, pageExtent: Double, count: Int) -> Int {
    guard pageExtent > 0 else { return 0 }
    return clampedIndex(Int((offset / pageExtent).rounded()), count: count)
  }

  static func resolvedPageOffset(_ offset: Double, pageExtent: Double, count: Int) -> Double {
    guard offset < 0 else { return offset }
    let maximum = Double(max(count - 1, 0)) * max(pageExtent, 0)
    return maximum + offset + 1
  }

  static func tapDownPayload(x: CGFloat, y: CGFloat) -> RufletValue {
    .map([
      "local_x": .double(Double(x)), "local_y": .double(Double(y)),
      "global_x": .double(Double(x)), "global_y": .double(Double(y)),
      "kind": .string("touch")
    ])
  }
}

private struct CollectionScrollSample: Equatable {
  var pixels: CGFloat = 0
  var contentExtent: CGFloat = 0
}

private struct CollectionScrollOffsetKey: PreferenceKey {
  static var defaultValue = CollectionScrollSample()
  static func reduce(value: inout CollectionScrollSample, nextValue: () -> CollectionScrollSample) {
    value = nextValue()
  }
}

private struct CollectionViewportKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct CollectionScrollReporter: ViewModifier {
  let node: ControlNode
  let horizontal: Bool
  let events: RufletEventSink
  @Environment(\.rufletScaffoldHost) private var scaffold
  @State private var lastReports: [String: Date] = [:]
  @State private var viewportExtent: CGFloat = 0
  @State private var previousPixels: CGFloat = 0
  @State private var previousRawPixels: CGFloat = 0
  @State private var previousSampleTime = Date()
  @State private var hasSample = false
  @State private var isScrolling = false
  @State private var scrollDirection = RufletScrollDirection.idle
  @State private var endToken = UUID()

  func body(content: Content) -> some View {
    content
      .coordinateSpace(name: "ruflet-scroll-\(node.id)")
      .background(
        GeometryReader { proxy in
          Color.clear.preference(
            key: CollectionViewportKey.self,
            value: horizontal ? proxy.size.width : proxy.size.height)
        })
      .onPreferenceChange(CollectionViewportKey.self) { viewportExtent = $0 }
      .onPreferenceChange(CollectionScrollOffsetKey.self) { sample in
          let now = Date()
          let resolved = RufletScrollSampleContract.resolve(
            rawPixels: sample.pixels,
            contentExtent: sample.contentExtent,
            viewportDimension: viewportExtent)
          let pixels = resolved.metrics.pixels
          scaffold?.reportScroll(sourceID: node.id, offset: pixels)
          guard node.handlesEvent("scroll") else { return }
          guard hasSample else {
            hasSample = true
            previousPixels = pixels
            previousRawPixels = sample.pixels
            previousSampleTime = now
            return
          }
          let rawDelta = sample.pixels - previousRawPixels
          guard abs(rawDelta) > 0.001 else { return }
          if !isScrolling {
            isScrolling = true
            report(kind: .start, metrics: resolved.metrics, now: now)
          }
          let direction = RufletScrollContract.direction(for: rawDelta)
          if direction != scrollDirection {
            scrollDirection = direction
            report(kind: .user, metrics: resolved.metrics, direction: direction, now: now)
          }
          if resolved.overscroll != 0 {
            report(
              kind: .overscroll,
              metrics: resolved.metrics,
              overscroll: resolved.overscroll,
              velocity: RufletScrollContract.velocity(
                delta: rawDelta, elapsed: now.timeIntervalSince(previousSampleTime)),
              now: now)
          } else {
            report(
              kind: .update,
              metrics: resolved.metrics,
              delta: pixels - previousPixels,
              now: now)
          }
          previousPixels = pixels
          previousRawPixels = sample.pixels
          previousSampleTime = now
          let token = UUID()
          endToken = token
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard endToken == token else { return }
            isScrolling = false
            report(kind: .end, metrics: resolved.metrics)
            scrollDirection = .idle
            report(kind: .user, metrics: resolved.metrics, direction: .idle)
          }
      }
      .onDisappear { scaffold?.removeScrollSource(node.id) }
  }

  private func report(
    kind: RufletScrollNotificationKind,
    metrics: RufletScrollMetrics,
    delta: CGFloat? = nil,
    direction: RufletScrollDirection? = nil,
    overscroll: CGFloat? = nil,
    velocity: CGFloat? = nil,
    now: Date = Date()
  ) {
    let interval = node.int("scroll_interval") ?? RufletScrollContract.defaultIntervalMilliseconds
    guard RufletScrollContract.shouldEmit(
      previous: lastReports[kind.rawValue], now: now, intervalMilliseconds: interval)
    else { return }
    lastReports[kind.rawValue] = now
    events.fire(
      node,
      "scroll",
      data: RufletScrollContract.payload(
        kind: kind,
        metrics: metrics,
        scrollDelta: delta,
        direction: direction,
        overscroll: overscroll,
        velocity: velocity))
  }
}

/// The offset probe must be inside the ScrollView's content. The reporter is
/// outside it and owns the named coordinate space, matching Flutter's
/// ScrollNotification relationship between body and Scaffold.
private struct CollectionScrollContentProbe: ViewModifier {
  let node: ControlNode
  let horizontal: Bool

  func body(content: Content) -> some View {
    content.background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: CollectionScrollOffsetKey.self,
          value: CollectionScrollSample(
            pixels: horizontal
              ? -proxy.frame(in: .named("ruflet-scroll-\(node.id)")).minX
              : -proxy.frame(in: .named("ruflet-scroll-\(node.id)")).minY,
            contentExtent: horizontal ? proxy.size.width : proxy.size.height))
      })
  }
}

/// Rows are draggable only while the list is editing on iOS; on macOS `onMove`
/// works without an edit mode.
/// `show_default_drag_handles: false` leaves rows reorderable by long press
/// rather than by a handle, which is what Flutter's flag means.
private struct AlwaysEditing: ViewModifier {
  var enabled = true

  func body(content: Content) -> some View {
    #if os(iOS)
      content.environment(\.editMode, .constant(enabled ? .active : .inactive))
    #else
      content
    #endif
  }
}
