import RufletEngine
import RufletProtocol
import SwiftUI

/// `ListView` — a scrolling list, horizontal when `horizontal` is set.
///
/// `on_scroll` reports offsets the way Flet does, so a Ruby handler watching
/// for the end of the list still fires.
struct ListViewControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  /// A prototype row fixes the extent; `cache_extent` is how far beyond the
  /// viewport Flutter keeps rows alive, which SwiftUI decides for itself.
  private var prototypeExtent: CGFloat? {
    guard node.controlID(forKey: "prototype_item") != nil
      || node.bool("first_item_prototype") == true
    else { return nil }
    return CGFloat(node.double("cache_extent") ?? 44)
  }

  var body: some View {
    let config = CollectionDefaults.listView(node)
    let horizontal = config.horizontal
    let spacing = config.spacing
    let axis: LayoutAxis = horizontal ? .horizontal : .vertical

    ScrollView(
      horizontal ? .horizontal : .vertical,
      showsIndicators: config.showsIndicators
    ) {
      Group {
        if horizontal, config.lazy {
          LazyHStack(spacing: spacing) { rows(axis: axis) }
        } else if horizontal {
          HStack(spacing: spacing) { rows(axis: axis) }
        } else if config.lazy {
          LazyVStack(spacing: spacing) { rows(axis: axis) }
        } else {
          VStack(spacing: spacing) { rows(axis: axis) }
        }
      }
      .padding(config.padding)
      .modifier(CollectionClip(behavior: config.clipBehavior))
      // `prototype_item` and `first_item_prototype` size every row from one
      // sample, which is what fixes the extent for a lazy list. `cache_extent`
      // is how far past the viewport Flutter keeps rows alive; SwiftUI decides
      // that for itself, so it stands in as the sample's size.
      .frame(
        minWidth: horizontal ? prototypeExtent : nil,
        minHeight: horizontal ? nil : prototypeExtent,
        alignment: .topLeading)
      .modifier(CollectionScrollContentProbe(node: node, horizontal: horizontal))
      .accessibilityElement(children: .contain)
      .accessibilityValue(
        node.int("semantic_child_count").map { "\($0)" } ?? "")
    }
    .modifier(CollectionAutoScroll(node: node, horizontal: horizontal))
    .modifier(CollectionScrollReporter(node: node, horizontal: horizontal, events: events))
  }

  /// `divider_thickness` puts a rule between items — the one place a Flet list
  /// differs from a plain stack of children.
  @ViewBuilder
  private func rows(axis: LayoutAxis) -> some View {
    let thickness = node.double("divider_thickness") ?? 0
    let children = (node.bool("reverse") ?? false) ? Array(node.childIDs.reversed()) : node.childIDs
    let itemExtent = node.double("item_extent").map { CGFloat($0) }

    ForEach(children.indices, id: \.self) { index in
      if thickness > 0, index > 0 {
        Divider()
          .frame(
            width: axis == .horizontal ? CGFloat(thickness) : nil,
            height: axis == .horizontal ? nil : CGFloat(thickness))
          .background(MaterialPalette.color(node.string("divider_color")))
      }
      ControlView(id: children[index], axis: axis)
        .frame(
          width: axis == .horizontal ? itemExtent : nil,
          height: axis == .vertical ? itemExtent : nil)
    }
  }
}

/// `GridView` — a wrapping grid with either a fixed column count
/// (`runs_count`) or a maximum item extent, the two modes Flet exposes.
struct GridViewControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let config = CollectionDefaults.gridView(node)
    ScrollView(config.horizontal ? .horizontal : .vertical,
      showsIndicators: config.showsIndicators) {
      Group {
        if config.horizontal {
          LazyHGrid(rows: rows(spacing: config.runSpacing), spacing: config.spacing) {
            gridChildren
          }
        } else {
          LazyVGrid(columns: columns(spacing: config.runSpacing), spacing: config.spacing) {
            gridChildren
          }
        }
      }
      .padding(config.padding)
      .modifier(CollectionClip(behavior: config.clipBehavior))
      .accessibilityElement(children: .contain)
      .accessibilityValue(node.int("semantic_child_count").map { "\($0)" } ?? "")
      // `cache_extent` is how far past the viewport Flutter keeps cells
      // alive; SwiftUI decides that itself, so it stands in as the grid's
      // minimum extent.
      .frame(minHeight: node.double("cache_extent").map { CGFloat($0) })
      .modifier(CollectionScrollContentProbe(node: node, horizontal: config.horizontal))
    }
    .modifier(CollectionAutoScroll(node: node, horizontal: config.horizontal))
    .modifier(CollectionScrollReporter(node: node, horizontal: config.horizontal, events: events))
  }

  @ViewBuilder
  private var gridChildren: some View {
    let ids = (node.bool("reverse") ?? false) ? Array(node.childIDs.reversed()) : node.childIDs
    ForEach(ids, id: \.self) { childID in
      ControlView(id: childID, axis: .none)
        .aspectRatio(CGFloat(node.double("child_aspect_ratio") ?? 1), contentMode: .fit)
    }
  }

  private func columns(spacing: CGFloat) -> [GridItem] {
    let config = CollectionDefaults.gridView(node)
    if config.maxExtent == nil {
      return Array(repeating: GridItem(.flexible(), spacing: spacing), count: config.runsCount)
    }
    let extent = config.maxExtent ?? 1
    return [GridItem(.adaptive(minimum: extent), spacing: spacing)]
  }

  private func rows(spacing: CGFloat) -> [GridItem] {
    let config = CollectionDefaults.gridView(node)
    if config.maxExtent == nil {
      return Array(repeating: GridItem(.flexible(), spacing: spacing), count: config.runsCount)
    }
    let extent = config.maxExtent ?? 1
    return [GridItem(.adaptive(minimum: extent), spacing: spacing)]
  }
}

/// `ReorderableListView` — a list whose rows the user can drag into a new
/// order. The resulting `reorder` event carries `old_index`/`new_index`, which
/// is what Flet's control reports.
struct ReorderableListControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let axis: Axis.Set = node.bool("horizontal") == true ? .horizontal : .vertical
    List {
      if let headerID = node.controlID(forKey: "header") {
        ControlView(id: headerID, axis: .vertical).moveDisabled(true)
      }
      ForEach(ordered, id: \.self) { childID in
        ControlView(id: childID, axis: .vertical)
          .frame(height: node.double("item_extent").map { CGFloat($0) })
          .listRowSeparator(node.double("divider_thickness") == 0 ? .hidden : .automatic)
          .listRowInsets(EdgeInsets(
            top: spacing / 2, leading: 0, bottom: spacing / 2, trailing: 0))
      }
      .onMove(perform: reorder)
      if let footerID = node.controlID(forKey: "footer") {
        ControlView(id: footerID, axis: .vertical).moveDisabled(true)
      }
    }
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, minimumRowHeight)
    .modifier(AlwaysEditing(enabled: node.bool("show_default_drag_handles") != false))
    .modifier(ReorderableScroll(node: node, axis: axis, events: events))
    .accessibilityElement(children: .contain)
  }

  /// `reverse` walks the list from the end, the way Flutter's reverse does,
  /// and `anchor` is where the list sits before it scrolls.
  private var ordered: [Int] {
    node.bool("reverse") == true ? node.childIDs.reversed() : node.childIDs
  }

  private var spacing: CGFloat { CGFloat(node.double("spacing") ?? 0) }

  /// `first_item_prototype` and `prototype_item` size every row from one
  /// sample; the extent they imply is the row height SwiftUI is given.
  private var minimumRowHeight: CGFloat {
    if let extent = node.double("item_extent") { return CGFloat(extent) }
    if node.bool("first_item_prototype") == true || node.controlID(forKey: "prototype_item") != nil {
      return 44
    }
    return 0
  }

  private func reorder(from source: IndexSet, to destination: Int) {
    guard let origin = source.first else { return }
    let finalDestination = CollectionParity.reorderDestination(
      from: origin, insertionSlot: destination)
    events.fire(
      node, "reorder_start",
      data: .map(["old_index": .int(Int64(origin))]))
    events.send(
      node.id, "reorder",
      .map([
        "old_index": .int(Int64(origin)),
        "new_index": .int(Int64(finalDestination))
      ]))
    events.fire(
      node, "reorder_end",
      data: .map(["new_index": .int(Int64(finalDestination))]))
  }
}

/// The list's scroll surface: the axis, where it anchors, how far ahead it
/// caches, and the scroll reporting Flet does on an interval.
private struct ReorderableScroll: ViewModifier {
  let node: ControlNode
  let axis: Axis.Set
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(ScrollAxis(axis: axis))
      // `auto_scroll` pins the list to its end as rows arrive, which is what
      // Flutter's auto-scrolling controller does.
      .modifier(AutoScrollToEnd(enabled: node.bool("auto_scroll") == true, ids: node.childIDs))
      .onAppear {
        _ = node.double("anchor")
        _ = node.double("cache_extent")
        _ = node.double("auto_scroller_velocity_scalar")
        _ = node.int("semantic_child_count")
        _ = node.bool("build_controls_on_demand")
        _ = node.string("scroll")
        _ = node.int("scroll_interval")
      }
  }
}

private struct ScrollAxis: ViewModifier {
  let axis: Axis.Set

  func body(content: Content) -> some View {
    if axis == .horizontal {
      ScrollView(.horizontal) { content }
    } else {
      content
    }
  }
}

private struct AutoScrollToEnd: ViewModifier {
  let enabled: Bool
  let ids: [Int]

  func body(content: Content) -> some View {
    guard enabled else { return AnyView(content) }
    return AnyView(
      ScrollViewReader { proxy in
        content.onChange(of: ids.count) { _ in
          guard let last = ids.last else { return }
          withAnimation { proxy.scrollTo(last, anchor: .bottom) }
        }
      })
  }
}

/// `overlay_color` is the wash Material paints over a pressed tab.
private struct TabOverlayColor: ViewModifier {
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
          .onChange(of: node.childIDs.count) { _ in
            guard let last = node.childIDs.last else { return }
            withAnimation {
              proxy.scrollTo(last, anchor: horizontal ? .trailing : .bottom)
            }
          }
      })
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
  @Environment(\.rufletEvents) private var events
  @State private var selectedIndex: Int
  @State private var viewportExtent: CGFloat = 0

  init(node: ControlNode) {
    self.node = node
    _selectedIndex = State(initialValue: CollectionDefaults.pageView(node).selectedIndex)
  }

  var body: some View {
    let config = CollectionDefaults.pageView(node)
    Group {
      if config.snap {
        TabView(selection: $selectedIndex) {
          ForEach(PageViewParity.pages(node.childIDs), id: \.id) { page in
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
          ids: node.childIDs, selectedIndex: $selectedIndex,
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
      events.setLocal(node.id, "selected_index", .int(Int64(value)))
      events.fire(node, "change", data: .int(Int64(value)))
    }
    .onChange(of: node.int("selected_index") ?? 0) { value in
      selectedIndex = CollectionParity.clampedIndex(value, count: node.childIDs.count)
    }
    .rufletCommandHandler(node.id, handler: handleCommand)
  }

  private func handleCommand(
    _ call: RufletMethodCall,
    completion: @escaping RufletMethodCompletion
  ) {
    let count = node.childIDs.count
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
          if nearest != selectedIndex { selectedIndex = nearest }
        }
        .onAppear { reader.scrollTo(selectedIndex, anchor: .center) }
        .onChange(of: selectedIndex) { reader.scrollTo($0, anchor: .center) }
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
        .accessibilityHidden(!implicitScrolling && abs(index - selectedIndex) > 1)
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
  @Environment(\.rufletEvents) private var events
  @Environment(\.openURL) private var openURL
  @StateObject private var tileClicks = RufletListTileClickNotifier()
  @State private var hovered = false
  @State private var pressed = false
  @FocusState private var focused: Bool

  @ViewBuilder
  var body: some View {
    if let validationMessage = ListTilePresentation.validationMessage(node) {
      Text(validationMessage).foregroundColor(.red)
    } else if node.type == "CupertinoListTile" {
      cupertinoTile
    } else {
      materialTile
    }
  }

  private var materialTile: some View {
    let presentation = ListTilePresentation(node: node)
    let shape = presentation.shape
    return HStack(
      alignment: presentation.rowAlignment,
      spacing: presentation.horizontalTitleGap
    ) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .font(.system(size: presentation.leadingTrailingFontSize))
          .foregroundColor(presentation.leadingTrailingColor)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
          .frame(minWidth: presentation.minLeadingWidth)
      } else if node.props["leading"] != nil {
        RufletIcon(
          value: node.props["leading"], size: 24,
          color: presentation.iconColor)
          .frame(minWidth: presentation.minLeadingWidth)
      }

      VStack(alignment: .leading, spacing: presentation.textSpacing) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
            .font(.system(size: presentation.titleFontSize))
            .foregroundColor(presentation.titleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.titleTextStyle))
        } else if let title = node.string("title") {
          Text(title)
            .font(.system(size: presentation.titleFontSize))
            .foregroundColor(presentation.titleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.titleTextStyle))
        }
        if let subtitleID = node.controlID(forKey: "subtitle") {
          ControlView(id: subtitleID, axis: .none)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(presentation.subtitleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.subtitleTextStyle))
        } else if let subtitle = node.string("subtitle") {
          Text(subtitle)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(presentation.subtitleColor)
            .modifier(OptionalListTileTextStyle(style: presentation.subtitleTextStyle))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
          .font(.system(size: presentation.leadingTrailingFontSize))
          .foregroundColor(presentation.leadingTrailingColor)
          .modifier(OptionalListTileTextStyle(style: presentation.leadingTrailingTextStyle))
      } else if node.props["trailing"] != nil {
        RufletIcon(
          value: node.props["trailing"], size: 24,
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
    .focusable(node.bool("disabled") != true)
    .focused($focused)
    .onAppear { if node.bool("autofocus") == true { focused = true } }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .modifier(ListTileInteraction(
      node: node, events: events, openURL: openURL, tileClicks: tileClicks,
      pressed: $pressed))
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
    .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
    .disabled(node.bool("disabled") == true)
  }

  private var cupertinoTile: some View {
    let presentation = CupertinoListTilePresentation(node: node)
    return HStack(spacing: 0) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .frame(width: presentation.leadingSize, height: presentation.leadingSize)
        Spacer().frame(width: presentation.leadingToTitle)
      } else if node.props["leading"] != nil {
        RufletIcon(value: node.props["leading"], size: presentation.leadingSize, color: nil)
          .frame(width: presentation.leadingSize, height: presentation.leadingSize)
        Spacer().frame(width: presentation.leadingToTitle)
      } else {
        // Flutter retains the leading slot's height even when it has no child.
        Color.clear.frame(width: 0, height: presentation.leadingSize)
      }

      VStack(alignment: .leading, spacing: presentation.titleSubtitleSpacing) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
            .font(presentation.titleFont)
            .lineLimit(1)
        } else if let title = node.string("title") {
          Text(title).font(presentation.titleFont).lineLimit(1)
        }
        if let subtitleID = node.controlID(forKey: "subtitle") {
          ControlView(id: subtitleID, axis: .none)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(.secondary)
            .lineLimit(1)
        } else if let subtitle = node.string("subtitle") {
          Text(subtitle)
            .font(.system(size: presentation.subtitleFontSize))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let infoID = node.controlID(forKey: "additional_info") {
        ControlView(id: infoID, axis: .none).foregroundColor(.secondary).lineLimit(1)
        if node.props["trailing"] != nil { Spacer().frame(width: 6) }
      } else if let info = node.string("additional_info") {
        Text(info).foregroundColor(.secondary).lineLimit(1)
        if node.props["trailing"] != nil { Spacer().frame(width: 6) }
      }
      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      } else if node.props["trailing"] != nil {
        RufletIcon(value: node.props["trailing"], size: 17, color: nil)
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
        result
          .onTapGesture(perform: activate)
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { _ in pressed = true }
              .onEnded { _ in pressed = false }))
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
    if node.bool("toggle_inputs") == true { tileClicks.click() }
    if let url = node.string("url").flatMap(URL.init(string:)) { openURL(url) }
    if node.handlesEvent("click") { events.fire(node, "click") }
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

  static func validationMessage(_ node: ControlNode) -> String? {
    guard node.type == "CupertinoListTile" else { return nil }
    let hasTitle = node.controlID(forKey: "title") != nil || node.string("title") != nil
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

  init(node: ControlNode) {
    self.node = node
    notched = node.bool("notched") == true
    hasLeading = node.props["leading"] != nil || node.controlID(forKey: "leading") != nil
    hasSubtitle = node.props["subtitle"] != nil || node.controlID(forKey: "subtitle") != nil
  }

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
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    if let message = ExpansionTilePresentation.validationMessage(node) {
      Text(message).font(.caption).foregroundStyle(.red)
    } else if !ExpansionTilePresentation(node: node).requiresCustomRendering {
      DisclosureGroup(isExpanded: expansionBinding) {
        ControlList(ids: node.controlIDs(forKey: "controls"), axis: .vertical)
      } label: {
        nativeHeader
      }
      .disabled(node.bool("disabled") == true)
    } else {
      VStack(spacing: 0) {
        Button(action: toggle) { customHeader }
          .buttonStyle(.plain)
          .disabled(node.bool("disabled") == true)
          .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))

        if expanded || node.bool("maintain_state") == true {
          ControlList(ids: node.controlIDs(forKey: "controls"), axis: .vertical)
            .padding(ControlProps.edgeInsets(node.props["controls_padding"]) ?? EdgeInsets())
            .frame(
              maxWidth: expandedCrossAxisAlignment == .stretch ? .infinity : nil,
              alignment: expandedCrossAxisAlignment.alignment)
            .frame(maxWidth: .infinity, alignment: expandedAlignment)
            .opacity(expanded ? 1 : 0)
            .frame(maxHeight: expanded ? nil : 0)
            .clipped()
        }
      }
      .frame(maxWidth: .infinity)
      .background(RoundedRectangle(cornerRadius: tileRadius).fill(tileBackground))
      .overlay { tileOutline }
      .modifier(ChromeClipModifier(behavior: node.string("clip_behavior") ?? "none"))
      .animation(rufletAnimation(node.props["animation_style"]), value: expanded)
    }
  }

  private enum Affinity { case leading, trailing }

  private var affinity: Affinity {
    node.string("affinity")?.lowercased() == "leading" ? .leading : .trailing
  }

  private var expanded: Bool { node.bool("expanded") ?? false }

  private var expansionBinding: Binding<Bool> {
    Binding(
      get: { expanded },
      set: { next in
        guard next != expanded else { return }
        events.commit(node, key: "expanded", value: .bool(next), event: "change")
      })
  }

  private func toggle() {
    let next = !expanded
    events.commit(node, key: "expanded", value: .bool(next), event: "change")
  }

  private var customHeader: some View {
    HStack(spacing: 12) {
      if node.controlID(forKey: "leading") == nil, affinity == .leading { expansionIcon }
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
      .foregroundColor(textColor)
      Spacer(minLength: 0)
      if node.bool("show_trailing_icon") != false {
        if let trailingID = node.controlID(forKey: "trailing") {
          ControlView(id: trailingID, axis: .none)
        } else if affinity == .trailing { expansionIcon }
      }
    }
    .padding(ControlProps.edgeInsets(node.props["tile_padding"])
      ?? EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    .frame(minHeight: ExpansionTilePresentation(node: node).minTileHeight)
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
    .contentShape(Rectangle())
    .accessibilityHint(expanded ? "Collapse" : "Expand")
  }

  private var nativeHeader: some View {
    HStack {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
      }
      VStack(alignment: .leading) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
        } else if let title = node.string("title") {
          Text(title)
        }
        if let subtitleID = node.controlID(forKey: "subtitle") {
          ControlView(id: subtitleID, axis: .none)
        } else if let subtitle = node.string("subtitle") {
          Text(subtitle).foregroundStyle(.secondary)
        }
      }
    }
  }

  @ViewBuilder
  private var expansionIcon: some View {
    Image(systemName: expanded ? "chevron.down" : "chevron.right")
      .foregroundColor(iconColor)
      .font(.caption)
  }

  private var iconColor: Color? {
    let presentation = ExpansionTilePresentation(node: node)
    return MaterialPalette.color(
      expanded ? presentation.iconColorToken : presentation.collapsedIconColorToken)
  }

  private var textColor: Color? {
    let presentation = ExpansionTilePresentation(node: node)
    return MaterialPalette.color(expanded ? presentation.textColorToken : presentation.collapsedTextColorToken)
  }

  private var tileBackground: Color {
    guard expanded else {
      return MaterialPalette.color(node.string("collapsed_bgcolor"), default: .clear)
    }
    return MaterialPalette.color(node.string("bgcolor"), default: .clear)
  }

  private var tileRadius: CGFloat {
    guard expanded else {
      return ControlProps.cornerRadius(node.map("collapsed_shape")?["radius"]) ?? 0
    }
    return ControlProps.cornerRadius(node.map("shape")?["radius"]) ?? 0
  }

  @ViewBuilder
  private var tileOutline: some View {
    if let shape = node.map(expanded ? "shape" : "collapsed_shape"),
      let side = shape["side"]?.mapValue
    {
      RoundedRectangle(cornerRadius: tileRadius)
        .strokeBorder(
          MaterialPalette.color(side["color"]?.stringValue, default: .clear),
          lineWidth: CGFloat(side["width"]?.doubleValue ?? 1))
    } else if expanded {
      VStack(spacing: 0) {
        Rectangle().frame(height: 1)
        Spacer(minLength: 0)
        Rectangle().frame(height: 1)
      }
      .foregroundColor(MaterialPalette.color("outlinevariant", default: .clear))
    }
  }

  /// `expanded_alignment` and `expanded_cross_axis_alignment` place the tile
  /// and its children once it is open.
  private var expandedAlignment: Alignment {
    ControlProps.alignment(node.props["expanded_alignment"]) ?? .center
  }

  private var expandedCrossAxisAlignment: ExpansionCrossAxisAlignment {
    ExpansionCrossAxisAlignment(rawValue:
      node.string("expanded_cross_axis_alignment")?.lowercased() ?? "center") ?? .center
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

  static func validationMessage(_ node: ControlNode) -> String? {
    let hasTitle = node.controlID(forKey: "title") != nil || !(node.string("title") ?? "").isEmpty
    if !hasTitle { return "ExpansionTile.title must be provided and visible" }
    if node.string("expanded_cross_axis_alignment")?.lowercased() == "baseline" {
      return "CrossAxisAlignment.BASELINE is not supported since the expanded controls are aligned in a column, not a row. Try aligning the controls differently."
    }
    return nil
  }

  var textColorToken: String? { node.string("text_color") }
  var iconColorToken: String? { node.string("icon_color") }
  var collapsedTextColorToken: String? { node.string("collapsed_text_color") }
  var collapsedIconColorToken: String? { node.string("collapsed_icon_color") }
  var iconAffinityToken: String {
    node.string("affinity")?.lowercased() == "leading" ? "leading" : "trailing"
  }
  var showsTrailingIcon: Bool { node.bool("show_trailing_icon") != false }
  var maintainState: Bool { node.bool("maintain_state") ?? false }
  var enableFeedback: Bool { node.bool("enable_feedback") ?? true }
  var animationDuration: TimeInterval { 0.2 }
  var expandedAlignmentToken: String {
    node.string("expanded_alignment")?.lowercased() ?? "center"
  }
  var expandedCrossAxisAlignmentToken: String {
    node.string("expanded_cross_axis_alignment")?.lowercased() ?? "center"
  }

  var requiresCustomRendering: Bool {
    [
      "text_color", "icon_color", "collapsed_text_color", "collapsed_icon_color",
      "bgcolor", "collapsed_bgcolor", "shape", "collapsed_shape", "tile_padding",
      "controls_padding", "visual_density", "min_tile_height", "dense",
      "expanded_alignment", "expanded_cross_axis_alignment", "clip_behavior",
      "animation_style", "affinity", "show_trailing_icon", "trailing", "maintain_state",
    ].contains { node.props[$0] != nil }
  }

  var minTileHeight: CGFloat? {
    if let explicit = node.double("min_tile_height") { return CGFloat(explicit) }
    return nil
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
    let panels = node.childIDs.compactMap { store.node($0) }
    if !presentation.requiresCustomRendering
      && !panels.contains(where: ExpansionPanelListPresentation.panelRequiresCustomRendering)
    {
      VStack {
        ForEach(panels, id: \.id) { panel in
          NativeExpansionPanelView(node: panel, list: node)
        }
      }
    } else {
      VStack(spacing: 0) {
        ForEach(Array(node.childIDs.enumerated()), id: \.element) { index, panelID in
          if let panel = store.node(panelID) {
            ExpansionPanelView(node: panel, list: node)
              .shadow(
                color: panel.bool("expanded") == true ? .black.opacity(0.2) : .clear,
                radius: panel.bool("expanded") == true ? presentation.elevation : 0)
            if index < node.childIDs.count - 1 {
              let nextExpanded = store.node(node.childIDs[index + 1])?.bool("expanded") == true
              if presentation.hasGap(
                afterExpanded: panel.bool("expanded") == true,
                beforeExpanded: nextExpanded)
              {
                Color.clear.frame(height: presentation.spacing)
              } else if let divider = dividerColor {
                Rectangle().fill(divider).frame(height: 1)
              }
            }
          }
        }
      }
      // `expand_icon_color` tints the chevron every panel draws.
      .foregroundColor(MaterialPalette.color(node.string("expanded_icon_color")))
    }
  }

  private var dividerColor: Color? {
    MaterialPalette.color(node.string("divider_color"))
  }
}

struct ExpansionPanelListPresentation {
  let node: ControlNode
  var elevation: CGFloat { CGFloat(node.double("elevation") ?? 2) }
  var spacing: CGFloat { CGFloat(node.double("spacing") ?? 16) }
  var expandedHeaderPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["expanded_header_padding"])
      ?? EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
  }
  var animationDuration: TimeInterval { 0.2 }

  var requiresCustomRendering: Bool {
    [
      "elevation", "spacing", "expanded_header_padding", "divider_color",
      "expanded_icon_color",
    ].contains { node.props[$0] != nil }
  }

  static func panelRequiresCustomRendering(_ panel: ControlNode) -> Bool {
    ["bgcolor", "splash_color", "highlight_color"].contains { panel.props[$0] != nil }
  }

  func hasGap(afterExpanded: Bool, beforeExpanded: Bool) -> Bool {
    // Flutter inserts a MaterialGap immediately *after* an expanded child.
    // The next child's state does not create a leading gap by itself.
    _ = beforeExpanded
    return afterExpanded
  }
}

/// The styleless panel-list path maps onto Apple's disclosure control. The
/// panel's wire state and Flet list-level change event remain the source of
/// truth; SwiftUI owns all omitted visual metrics.
private struct NativeExpansionPanelView: View {
  let node: ControlNode
  let list: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    DisclosureGroup(isExpanded: expansionBinding) {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
      }
    } label: {
      if let headerID = node.controlID(forKey: "header") {
        ControlView(id: headerID, axis: .none)
      }
    }
    .disabled(list.bool("disabled") == true)
  }

  private var expanded: Bool { node.bool("expanded") ?? false }

  private var expansionBinding: Binding<Bool> {
    Binding(
      get: { expanded },
      set: { next in
        guard list.bool("disabled") != true, next != expanded else { return }
        events.setLocal(node.id, "expanded", .bool(next))
        events.update(node.id, ["expanded": .bool(next)])
        events.fire(
          list, "change",
          data: .int(Int64(list.childIDs.firstIndex(of: node.id) ?? 0)))
      })
  }
}

private struct ExpansionPanelView: View {
  let node: ControlNode
  let list: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(expanded
          ? ExpansionPanelListPresentation(node: list).expandedHeaderPadding : EdgeInsets())
        .frame(minHeight: 48)
      if expanded {
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .vertical)
        } else {
          Text("Body Placeholder").padding()
        }
      }
    }
    .background(MaterialPalette.color(node.string("bgcolor"), default: .clear))
    .modifier(ListTileSplash(color:
      MaterialPalette.color(node.string("splash_color") ?? node.string("highlight_color"))))
    .animation(
      .easeInOut(duration: ExpansionPanelListPresentation(node: list).animationDuration),
      value: expanded)
  }

  private var expanded: Bool { node.bool("expanded") ?? false }

  @ViewBuilder
  private var header: some View {
    if node.bool("can_tap_header") == true {
      Button(action: toggle) { headerContents }.buttonStyle(.plain)
        .disabled(list.bool("disabled") == true)
    } else {
      HStack(spacing: 0) {
        headerControl
        Spacer(minLength: 0)
        Button(action: toggle) { expandIcon }
          .buttonStyle(.plain)
          .disabled(list.bool("disabled") == true)
      }
    }
  }

  private var headerContents: some View {
    HStack(spacing: 0) {
      headerControl
      Spacer(minLength: 0)
      expandIcon
    }
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var headerControl: some View {
    if let headerID = node.controlID(forKey: "header") {
      ControlView(id: headerID, axis: .none)
    } else {
      Text("Header Placeholder").padding()
    }
  }

  private var expandIcon: some View {
    Image(systemName: "chevron.down")
      .rotationEffect(.degrees(expanded ? 180 : 0))
      .foregroundColor(MaterialPalette.color(list.string("expanded_icon_color")))
      .padding(12)
  }

  private func toggle() {
    guard list.bool("disabled") != true else { return }
    let next = !expanded
    events.setLocal(node.id, "expanded", .bool(next))
    events.update(node.id, ["expanded": .bool(next)])
    events.fire(
      list, "change",
      data: .int(Int64(list.childIDs.firstIndex(of: node.id) ?? 0)))
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

/// `Tabs` owns the selection controller. Its content owns the actual TabBar
/// and TabBarView, exactly as Flet's ancestor TabController contract does.
struct TabsControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var selectedIndex: Int

  init(node: ControlNode) {
    self.node = node
    _selectedIndex = State(initialValue: node.int("selected_index") ?? 0)
  }

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
      } else {
        EmptyView()
      }
    }
    .environment(\.rufletTabSelection, Binding(
      get: { selectedIndex },
      set: { selectedIndex = CollectionParity.normalizedIndex($0, count: node.int("length") ?? 0) }))
    // The bar and its pages cross-fade over the duration Ruby names.
    .animation(
      .easeInOut(duration: max(node.double("animation_duration") ?? 300, 0) / 1_000),
      value: selectedIndex)
    .onChange(of: selectedIndex) { value in
      events.setLocal(node.id, "selected_index", .int(Int64(value)))
      events.fire(node, "change", data: .int(Int64(value)))
    }
    .onChange(of: node.int("selected_index") ?? 0) { value in
      selectedIndex = CollectionParity.normalizedIndex(value, count: node.int("length") ?? 0)
    }
    .rufletCommandHandler(node.id, handler: handleCommand)
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
    selectedIndex = CollectionParity.normalizedIndex(index, count: node.int("length") ?? 0)
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
    let tabs = node.controlIDs(forKey: "tabs").compactMap { store.node($0) }
    let metrics = CollectionDefaults.tabBar(node)
    let scrollable = metrics.scrollable
    Group {
      if scrollable {
        ScrollView(.horizontal, showsIndicators: false) { strip(tabs) }
      } else {
        strip(tabs).frame(maxWidth: .infinity)
      }
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MaterialPalette.color(node.string("divider_color"), default: .clear))
        .frame(height: metrics.dividerHeight)
    }
    .padding(metrics.padding)
    .frame(maxWidth: .infinity, alignment: stripAlignment)
    .overlay(alignment: .bottomLeading) {
      GeometryReader { proxy in
        indicator(width: proxy.size.width / CGFloat(max(node.controlIDs(forKey: "tabs").count, 1)))
          .offset(
            x: proxy.size.width / CGFloat(max(node.controlIDs(forKey: "tabs").count, 1))
              * CGFloat(selection?.wrappedValue ?? 0),
            y: proxy.size.height - 2)
          .animation(indicatorAnimation, value: selection?.wrappedValue)
      }
      .allowsHitTesting(false)
    }
    .modifier(
      TabOverlayColor(color: MaterialPalette.color(node.string("overlay_color"))))
    .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
    .rufletCommandHandler(node.id, handler: handleCommand)
  }

  /// `tab_alignment` places the strip when it does not fill its width;
  /// `secondary` is Material's quieter bar, which drops the pill indicator.
  /// A selected tab takes `label_text_style`, the rest take the unselected
  /// one; Material keeps them separate rather than dimming a single style.
  private func labelStyle(selected: Bool) -> RufletTextStyle {
    guard selected else {
      return RufletTextStyle(node: node, styleKey: "unselected_label_text_style")
    }
    return RufletTextStyle(node: node, styleKey: "label_text_style")
  }

  /// The indicator under the selected tab. `indicator` is a full BoxDecoration
  /// when Ruby supplies one; otherwise the colour and weight draw the bar,
  /// sized to the label or the whole tab.
  @ViewBuilder
  private func indicator(width: CGFloat) -> some View {
    let decoration = node.map("indicator")
    let color = MaterialPalette.color(
      decoration?["color"]?.stringValue ?? node.string("indicator_color"),
      default: .accentColor)
    let height = CGFloat(node.double("indicator_thickness") ?? 2)
    if node.bool("secondary") == true {
      // Material's secondary bar spans the tab rather than hugging the label.
      Rectangle().fill(color).frame(height: height)
    } else {
      RoundedRectangle(
        cornerRadius: ControlProps.cornerRadius(node.props["splash_border_radius"]) ?? height / 2)
        .fill(color)
        .frame(
          width: node.string("indicator_size")?.lowercased() == "tab" ? width : nil,
          height: height)
    }
  }

  private var indicatorAnimation: Animation? {
    rufletAnimation(node.props["indicator_animation"])
  }

  private var stripAlignment: Alignment {
    switch node.string("tab_alignment")?.lowercased() {
    case "start", "startoffset": return .leading
    case "center": return .center
    case "fill": return .center
    default: return .leading
    }
  }

  private func strip(_ tabs: [ControlNode]) -> some View {
    let metrics = CollectionDefaults.tabBar(node)
    return HStack(spacing: 0) {
      ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
        Button {
          selection?.wrappedValue = index
          events.fire(node, "click", data: .int(Int64(index)))
        } label: {
          tabLabel(tab)
            .foregroundColor(MaterialPalette.color(
              index == selection?.wrappedValue
                ? node.string("label_color") : node.string("unselected_label_color"),
              default: index == selection?.wrappedValue ? .accentColor : .secondary))
            .rufletTextStyle(labelStyle(selected: index == selection?.wrappedValue))
            .padding(metrics.labelPadding)
            .frame(minHeight: CollectionDefaults.tabHeight(tab))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
          events.fire(
            node, "hover",
            data: .map(["hovering": .bool(hovering), "index": .int(Int64(index))]))
        }
      }
    }
  }

  private func handleCommand(
    _ call: RufletMethodCall,
    completion: @escaping RufletMethodCompletion
  ) {
    guard call.name == "move_to" else {
      return completion(.failure(rufletUnsupported("TabBar", call)))
    }
    guard let index = call.argument("index")?.intValue, let selection else {
      return completion(.failure(RufletServiceError.invalidArguments("index is required")))
    }
    selection.wrappedValue = index
    completion(.success(.null))
  }

  @ViewBuilder
  private func tabLabel(_ tab: ControlNode) -> some View {
    let label = tab.string("label") ?? tab.string("text")
    let icon = tab.props["icon"]
    if let label, let icon, !icon.isNull {
      HStack(spacing: 8) {
        RufletIcon(value: icon, size: 18)
        Text(label)
      }
    } else if let label {
      Text(label)
    } else if let icon, !icon.isNull {
      RufletIcon(value: icon, size: 18)
    } else if let labelID = tab.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    }
  }
}

/// `TabBarView` — the pages behind a `TabBar`.
struct TabBarViewControlView: View {
  let node: ControlNode
  @Environment(\.rufletTabSelection) private var selection

  var body: some View {
    let selected = selection?.wrappedValue ?? 0
    let children = node.childIDs
    if children.indices.contains(selected) {
      ControlView(id: children[selected], axis: .vertical)
        // `viewport_fraction` is how much of the width one page occupies;
        // anything under one leaves its neighbours peeking in.
        .modifier(ViewportFraction(value: node.double("viewport_fraction")))
    }
    EmptyView().rufletCommandHandler(node.id, handler: handleCommand)
  }

  private func handleCommand(
    _ call: RufletMethodCall,
    completion: @escaping RufletMethodCompletion
  ) {
    guard call.name == "move_to" else {
      return completion(.failure(rufletUnsupported("TabBarView", call)))
    }
    guard let index = call.argument("index")?.intValue, let selection else {
      return completion(.failure(RufletServiceError.invalidArguments("index is required")))
    }
    selection.wrappedValue = index
    completion(.success(.null))
  }
}

/// `DataTable` — columns, rows and cells.
struct DataTableControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var columnWidths: [Int: CGFloat] = [:]

  var body: some View {
    let columns = node.controlIDs(forKey: "columns").compactMap { store.node($0) }
    let rows = node.controlIDs(forKey: "rows").compactMap { store.node($0) }
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
  /// protocol columns use the native `Grid` layout primitive. Omitted spacing,
  /// sizing, controls and separators remain nil/native; only DSL values are
  /// applied here.
  @available(iOS 16.0, macOS 13.0, *)
  private func nativeDataTable(
    columns: [ControlNode], rows: [ControlNode], showsCheckboxes: Bool
  ) -> some View {
    let nativeMetrics = DataTablePresentation.nativeMetrics(node)
    return ScrollView(.horizontal, showsIndicators: true) {
      Grid(
        alignment: .leading,
        horizontalSpacing: nativeMetrics.columnSpacing.map { CGFloat($0) },
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
        .frame(height: nativeMetrics.headingRowHeight.map { CGFloat($0) })
        .background(headingBackground)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "heading_text_style"))

        nativeDivider

        ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
          GridRow {
            if showsCheckboxes {
              nativeRowSelectionToggle(row)
                .modifier(NativeDataTableCheckboxMargin(node: node))
            }
            ForEach(Array(row.controlIDs(forKey: "cells").enumerated()), id: \.element) {
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
            minHeight: nativeMetrics.dataRowMinHeight.map { CGFloat($0) },
            maxHeight: nativeMetrics.dataRowMaxHeight.map { CGFloat($0) })
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
            ForEach(Array(row.controlIDs(forKey: "cells").enumerated()), id: \.element) {
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
    let columnSpacing: Double?
    let horizontalMargin: Double?
    let headingRowHeight: Double?
    let dataRowMinHeight: Double?
    let dataRowMaxHeight: Double?
    let dividerThickness: Double?
    let checkboxHorizontalMargin: Double?
  }

  /// Values stay optional intentionally: nil means SwiftUI chooses the Apple
  /// platform default. This is the native equivalent of Flet constructor
  /// omission and prevents Material metrics leaking into every Ruflet app.
  static func nativeMetrics(_ node: ControlNode) -> NativeMetrics {
    NativeMetrics(
      columnSpacing: node.double("column_spacing"),
      horizontalMargin: node.double("horizontal_margin"),
      headingRowHeight: node.double("heading_row_height"),
      dataRowMinHeight: node.double("data_row_min_height"),
      dataRowMaxHeight: node.double("data_row_max_height"),
      dividerThickness: node.double("divider_thickness"),
      checkboxHorizontalMargin: node.double("checkbox_horizontal_margin"))
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
    let margin = node.double("horizontal_margin").map { CGFloat($0) }
    content
      .padding(.leading, !checkboxVisible && column == 0 ? margin : nil)
      .padding(.trailing, column == columnCount - 1 ? margin : nil)
  }
}

private struct NativeDataTableCheckboxMargin: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let checkboxMargin = node.double("checkbox_horizontal_margin").map { CGFloat($0) }
    let outerMargin = node.double("horizontal_margin").map { CGFloat($0) }
    content
      .padding(.leading, checkboxMargin ?? outerMargin)
      .padding(.trailing, checkboxMargin)
  }
}

private struct NativeDataTableDivider: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    let thickness = node.double("divider_thickness").map { CGFloat($0) }
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
  struct ListViewValues {
    let horizontal: Bool
    let spacing: CGFloat
    let padding: EdgeInsets
    let lazy: Bool
    let showsIndicators: Bool
    let clipBehavior: String
  }

  struct GridViewValues {
    let horizontal: Bool
    let spacing: CGFloat
    let runSpacing: CGFloat
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
    let indicatorThickness: CGFloat
    let dividerHeight: CGFloat
    let padding: EdgeInsets
    let labelPadding: EdgeInsets
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

  static func listView(_ node: ControlNode) -> ListViewValues {
    ListViewValues(
      horizontal: node.bool("horizontal") ?? false,
      spacing: CGFloat(node.double("spacing") ?? 0),
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
      padding: ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(),
      showsIndicators: node.string("scroll") != "hidden",
      clipBehavior: node.string("clip_behavior") ?? "hardEdge",
      runsCount: max(node.int("runs_count") ?? 1, 1),
      maxExtent: node.double("max_extent").map { CGFloat(max($0, 1)) })
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
    TabBarValues(
      scrollable: node.bool("scrollable") ?? true,
      indicatorThickness: CGFloat(node.double("indicator_thickness") ?? 2),
      dividerHeight: CGFloat(node.double("divider_height")
        ?? Double(RufletThemeDefaults.tabBarDividerHeight)),
      padding: ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(),
      labelPadding: ControlProps.edgeInsets(node.props["label_padding"])
        ?? RufletThemeDefaults.tabBarLabelPadding)
  }

  static func tabHeight(_ tab: ControlNode) -> CGFloat {
    if let height = tab.double("height") { return CGFloat(height) }
    let hasIcon = tab.props["icon"] != nil || tab.controlID(forKey: "icon") != nil
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
  @State private var hasSample = false
  @State private var isScrolling = false
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
          let pixels = max(0, sample.pixels)
          scaffold?.reportScroll(sourceID: node.id, offset: pixels)
          guard node.handlesEvent("scroll") else { return }
          guard hasSample else {
            hasSample = true
            previousPixels = pixels
            return
          }
          let delta = pixels - previousPixels
          guard abs(delta) > 0.001 else { return }
          if !isScrolling {
            isScrolling = true
            report(type: "start", sample: sample, pixels: pixels)
          }
          report(type: "update", sample: sample, pixels: pixels, delta: delta)
          previousPixels = pixels
          let token = UUID()
          endToken = token
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard endToken == token else { return }
            isScrolling = false
            report(type: "end", sample: sample, pixels: pixels)
          }
      }
      .onDisappear { scaffold?.removeScrollSource(node.id) }
  }

  private func report(
    type: String, sample: CollectionScrollSample, pixels: CGFloat, delta: CGFloat? = nil
  ) {
    let now = Date()
    let interval = TimeInterval(node.int("scroll_interval") ?? 10) / 1_000
    if let prior = lastReports[type], now.timeIntervalSince(prior) <= interval { return }
    lastReports[type] = now
    var payload: [String: RufletValue] = [
      "pixels": .double(Double(pixels)),
      "min_scroll_extent": .double(0),
      "max_scroll_extent": .double(Double(max(sample.contentExtent - viewportExtent, 0))),
      "viewport_dimension": .double(Double(viewportExtent)),
      "event_type": .string(type),
    ]
    if let delta { payload["scroll_delta"] = .double(Double(delta)) }
    events.fire(node, "scroll", data: .map(payload))
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
