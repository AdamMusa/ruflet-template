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
    }
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
    }
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
    if let runs = node.int("runs_count"), runs > 0 {
      return Array(repeating: GridItem(.flexible(), spacing: spacing), count: runs)
    }
    let extent = CGFloat(node.double("max_extent") ?? 1)
    return [GridItem(.adaptive(minimum: extent), spacing: spacing)]
  }

  private func rows(spacing: CGFloat) -> [GridItem] {
    if let runs = node.int("runs_count"), runs > 0 {
      return Array(repeating: GridItem(.flexible(), spacing: spacing), count: runs)
    }
    let extent = CGFloat(node.double("max_extent") ?? 1)
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

/// `PageView` — a horizontally paged carousel.
struct PageViewControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var selectedIndex: Int

  init(node: ControlNode) {
    self.node = node
    _selectedIndex = State(initialValue: CollectionDefaults.pageView(node).selectedIndex)
  }

  var body: some View {
    let config = CollectionDefaults.pageView(node)
    TabView(selection: $selectedIndex) {
      ForEach(Array(node.childIDs.enumerated()), id: \.element) { index, childID in
        ControlView(id: childID, axis: .none)
          .modifier(PageViewport(
            horizontal: config.horizontal,
            fraction: config.viewportFraction,
            padEnds: config.padEnds))
          .tag(index)
      }
    }
    .modifier(PagedTabStyle())
    .modifier(PageAxis(horizontal: config.horizontal))
    .modifier(CollectionClip(behavior: config.clipBehavior))
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
      selectedIndex = CollectionParity.clampedIndex(index, count: count)
      completion(.success(.null))
    case "jump_to":
      guard let value = call.argument("value")?.doubleValue else {
        return completion(.failure(RufletServiceError.invalidArguments("value is required")))
      }
      selectedIndex = CollectionParity.pageIndex(forOffset: value, count: count)
      completion(.success(.null))
    case "next_page":
      selectedIndex = CollectionParity.clampedIndex(selectedIndex + 1, count: count)
      completion(.success(.null))
    case "previous_page":
      selectedIndex = CollectionParity.clampedIndex(selectedIndex - 1, count: count)
      completion(.success(.null))
    default:
      completion(.failure(rufletUnsupported("PageView", call)))
    }
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

  var body: some View {
    let metrics = CollectionDefaults.listTile(node)
    HStack(alignment: rowAlignment, spacing: metrics.horizontalTitleGap) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .frame(minWidth: metrics.minLeadingWidth)
      } else if node.props["leading"] != nil {
        RufletIcon(
          value: node.props["leading"], size: 22,
          color: MaterialPalette.color(node.string("icon_color")))
          .frame(minWidth: metrics.minLeadingWidth)
      }

      VStack(alignment: .leading, spacing: 2) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
        } else if let title = node.string("title") {
          Text(title).rufletTextStyle(RufletTextStyle(node: node, styleKey: "title_text_style"))
        }
        if let subtitleID = node.controlID(forKey: "subtitle") {
          ControlView(id: subtitleID, axis: .none)
            .font(.subheadline)
            .foregroundColor(.secondary)
        } else if let subtitle = node.string("subtitle") {
          Text(subtitle)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .rufletTextStyle(RufletTextStyle(node: node, styleKey: "subtitle_text_style"))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      } else if node.props["trailing"] != nil {
        RufletIcon(
          value: node.props["trailing"], size: 22,
          color: MaterialPalette.color(node.string("icon_color")))
      } else if let trailingText = node.string("trailing") {
        Text(trailingText)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "leading_and_trailing_text_style"))
      }
      // `toggle_inputs` lets a tap anywhere on the row drive the switch or
      // checkbox it carries, rather than only the control itself.
      if node.bool("toggle_inputs") == true, let toggleID = node.controlID(forKey: "leading") {
        Color.clear.frame(width: 0).onTapGesture { events.fire(node, "click") }
          .accessibilityHidden(true)
          .id(toggleID)
      }
    }
    .padding(metrics.contentPadding)
    .padding(.vertical, metrics.minVerticalPadding)
    .frame(minHeight: metrics.minHeight)
    .background(
      (node.bool("selected") ?? false)
        ? MaterialPalette.color(node.string("selected_tile_color") ?? "secondarycontainer")
        : MaterialPalette.color(node.string("bgcolor")))
    .foregroundColor(MaterialPalette.color(
      (node.bool("selected") ?? false) ? node.string("selected_color") : node.string("text_color"),
      default: .primary))
    .opacity(node.bool("disabled") == true ? 0.45 : 1)
    .allowsHitTesting(node.bool("disabled") != true)
    .clipShape(RoundedRectangle(cornerRadius: tileRadius))
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
    .contentShape(Rectangle())
    .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
    .modifier(ListTileSplash(color: MaterialPalette.color(node.string("splash_color"))))
    .modifier(TapReporter(node: node, events: events))
  }

  /// `title_alignment` places the leading and trailing slots against the title
  /// block rather than centring them on the row.
  private var rowAlignment: VerticalAlignment {
    switch node.string("title_alignment")?.lowercased() {
    case "top", "titlehigh": return .top
    case "bottom": return .bottom
    default: return .center
    }
  }

  private var tileRadius: CGFloat {
    ControlProps.cornerRadius(node.map("shape")?["radius"]) ?? 0
  }
}

/// Material fills a pressed tile with its splash colour.
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

/// `ExpansionTile` — a disclosure row that keeps its state on the Ruby side.
struct ExpansionTileControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { node.bool("expanded") ?? false },
        set: { events.commit(node, key: "expanded", value: .bool($0)) })
    ) {
      VStack(alignment: .leading, spacing: 0) {
        ControlList(ids: node.controlIDs(forKey: "controls"), axis: .vertical)
      }
      .padding(ControlProps.edgeInsets(node.props["controls_padding"]) ?? EdgeInsets())
    } label: {
      HStack(spacing: 12) {
        // `affinity` puts the disclosure control on the leading side; the
        // leading slot then follows it rather than opening the row.
        if affinity == .leading, node.bool("show_trailing_icon") != false { expansionIcon }
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
        }
        VStack(alignment: .leading, spacing: 2) {
          if let titleID = node.controlID(forKey: "title") {
            ControlView(id: titleID, axis: .none)
          } else if let title = node.string("title") {
            Text(title)
          }
          if let subtitleID = node.controlID(forKey: "subtitle") {
            ControlView(id: subtitleID, axis: .none)
          }
        }
        .foregroundColor(textColor)
        Spacer(minLength: 0)
        if let trailingID = node.controlID(forKey: "trailing") {
          ControlView(id: trailingID, axis: .none)
        }
      }
      .frame(minHeight: node.double("min_tile_height").map { CGFloat($0) })
      .modifier(VisualDensityPadding(value: node.props["visual_density"]))
      .contentShape(Rectangle())
    }
    .padding(ControlProps.edgeInsets(node.props["tile_padding"])
      ?? EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    .frame(maxWidth: .infinity, alignment: expandedAlignment)
    .background(
      RoundedRectangle(cornerRadius: tileRadius).fill(tileBackground))
    .animation(rufletAnimation(node.props["animation_style"]), value: node.bool("expanded"))
    // `maintain_state` keeps the collapsed children built, which is what
    // Flutter's flag does; SwiftUI discards them otherwise.
    .modifier(MaintainedState(enabled: node.bool("maintain_state") == true))
    .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
  }

  private enum Affinity { case leading, trailing }

  private var affinity: Affinity {
    node.string("affinity")?.lowercased() == "leading" ? .leading : .trailing
  }

  private var expanded: Bool { node.bool("expanded") ?? false }

  @ViewBuilder
  private var expansionIcon: some View {
    Image(systemName: expanded ? "chevron.down" : "chevron.right")
      .foregroundColor(iconColor)
      .font(.caption)
  }

  private var iconColor: Color? {
    guard expanded else { return MaterialPalette.color(node.string("collapsed_icon_color")) }
    return MaterialPalette.color(node.string("icon_color"))
  }

  private var textColor: Color? {
    guard expanded else { return MaterialPalette.color(node.string("collapsed_text_color")) }
    return MaterialPalette.color(node.string("text_color"))
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

  /// `expanded_alignment` and `expanded_cross_axis_alignment` place the tile
  /// and its children once it is open.
  private var expandedAlignment: Alignment {
    ControlProps.alignment(node.props["expanded_alignment"])
      ?? (node.string("expanded_cross_axis_alignment")?.lowercased() == "center"
        ? .center : .leading)
  }
}

/// Flutter keeps a maintained tile's children alive while it is collapsed.
private struct MaintainedState: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled {
      content.transaction { $0.disablesAnimations = false }
    } else {
      content
    }
  }
}

/// `ExpansionPanelList` — several independently expandable panels.
struct ExpansionPanelListControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    VStack(spacing: CGFloat(node.double("spacing") ?? 16)) {
      ForEach(node.childIDs, id: \.self) { panelID in
        if let panel = store.node(panelID) {
          ExpansionPanelView(node: panel, list: node)
        }
      }
    }
  }
}

private struct ExpansionPanelView: View {
  let node: ControlNode
  let list: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { node.bool("expanded") ?? false },
        set: { expanded in
          events.setLocal(node.id, "expanded", .bool(expanded))
          // Flet's ExpansionPanelList callback carries the panel index. The
          // expanded property itself lives on the structural panel child.
          events.fire(
            list, "change",
            data: .int(Int64(list.childIDs.firstIndex(of: node.id) ?? 0)))
        })
    ) {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
      }
    } label: {
      if let headerID = node.controlID(forKey: "header") {
        ControlView(id: headerID, axis: .none)
      }
    }
    .padding(.horizontal, 12)
    .background(MaterialPalette.color(node.string("bgcolor")))
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
    .rufletCommandHandler(node.id, handler: handleCommand)
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
            .padding(metrics.labelPadding)
            .frame(minHeight: CollectionDefaults.tabHeight(tab))
            .overlay(alignment: .bottom) {
              if index == selection?.wrappedValue {
                Rectangle()
                  .fill(MaterialPalette.color(node.string("indicator_color"), default: .accentColor))
                  .frame(height: metrics.indicatorThickness)
              }
            }
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
    let symbol = IconMapping.symbol(for: tab.props["icon"])
    if let label, let symbol {
      Label(label, systemImage: symbol).labelStyle(.titleAndIcon)
    } else if let label {
      Text(label)
    } else if let symbol {
      Image(systemName: symbol)
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

  var body: some View {
    let columns = node.controlIDs(forKey: "columns").compactMap { store.node($0) }
    let rows = node.controlIDs(forKey: "rows").compactMap { store.node($0) }
    let metrics = CollectionDefaults.dataTable(node)
    let spacing = metrics.columnSpacing
    let showsCheckboxes = metrics.showCheckboxColumn
      && rows.contains(where: { $0.handlesEvent("select_change") })

    ScrollView(.horizontal, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: spacing) {
          if showsCheckboxes {
            Button { selectAll(rows) } label: {
              Image(systemName: allSelected(rows) ? "checkmark.square.fill" : "square")
            }
            .buttonStyle(.plain)
            .disabled(!node.handlesEvent("select_all"))
          }
          ForEach(columns, id: \.id) { column in
            headerCell(column, index: columns.firstIndex(where: { $0.id == column.id }) ?? 0)
          }
        }
        .frame(height: metrics.headingRowHeight)
        .background(MaterialPalette.color(node.string("heading_row_color")))
        .font(.subheadline.weight(.semibold))

        tableDivider

        ForEach(rows, id: \.id) { row in
          HStack(spacing: spacing) {
            if showsCheckboxes {
              Button { selectRow(row, selected: !(row.bool("selected") ?? false)) } label: {
                Image(systemName: (row.bool("selected") ?? false) ? "checkmark.square.fill" : "square")
              }
              .buttonStyle(.plain)
              .disabled(!row.handlesEvent("select_change"))
            }
            ForEach(row.controlIDs(forKey: "cells"), id: \.self) { cellID in
              cellContent(cellID)
            }
          }
          .frame(minHeight: metrics.dataRowMinHeight, maxHeight: metrics.dataRowMaxHeight)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            (row.bool("selected") ?? false)
              ? MaterialPalette.color("secondarycontainer", default: .clear) : Color.clear)
          .contentShape(Rectangle())
          .onTapGesture { selectRow(row, selected: !(row.bool("selected") ?? false)) }
          .modifier(LongPressReporter(node: row, events: events))

          if metrics.dividerThickness > 0,
            row.id != rows.last?.id || metrics.showBottomBorder { tableDivider }
        }
      }
      .padding(.horizontal, metrics.horizontalMargin)
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
      let ascending = node.int("sort_column_index") == index
        ? !(node.bool("sort_ascending") ?? false) : true
      events.fire(
        column, "sort",
        data: .map(["ci": .int(Int64(index)), "asc": .bool(ascending)]))
    } label: {
      HStack(spacing: 4) {
        if let labelID = column.controlID(forKey: "label") {
          ControlView(id: labelID, axis: .none)
        } else {
          Text(column.string("label") ?? "")
        }
        if node.int("sort_column_index") == index {
          Image(systemName: (node.bool("sort_ascending") ?? false) ? "arrow.up" : "arrow.down")
            .font(.caption)
        }
      }
      .frame(maxWidth: .infinity,
        alignment: column.bool("numeric") == true ? .trailing : .leading)
    }
    .buttonStyle(.plain)
    .help(column.string("tooltip") ?? "")
    .disabled(!column.handlesEvent("sort"))
  }

  @ViewBuilder
  private func cellContent(_ cellID: Int) -> some View {
    if let cell = store.node(cellID) {
      Group {
        if let contentID = cell.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        } else if let text = cell.string("content") {
          HStack(spacing: 4) {
            Text(text)
            if cell.bool("show_edit_icon") == true {
              Image(systemName: "pencil").foregroundColor(.secondary)
            }
          }
          .opacity(cell.bool("placeholder") == true ? 0.55 : 1)
        }
      }
      .contentShape(Rectangle())
      .modifier(DataCellInteractionReporter(node: cell, events: events))
    } else {
      ControlView(id: cellID, axis: .none)
    }
  }

  private func selectRow(_ row: ControlNode, selected: Bool) {
    guard row.handlesEvent("select_change") else { return }
    events.setLocal(row.id, "selected", .bool(selected))
    events.send(row.id, "select_change", .bool(selected))
  }

  private func allSelected(_ rows: [ControlNode]) -> Bool {
    !rows.isEmpty && rows.allSatisfy { $0.bool("selected") ?? false }
  }

  private func selectAll(_ rows: [ControlNode]) {
    let selected = !allSelected(rows)
    events.fire(node, "select_all", data: .bool(selected))
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
      clipBehavior: node.string("clip_behavior") ?? "hardEdge")
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
    DataTableValues(
      columnSpacing: CGFloat(node.double("column_spacing")
        ?? Double(RufletThemeDefaults.dataTableColumnSpacing)),
      horizontalMargin: CGFloat(node.double("horizontal_margin")
        ?? Double(RufletThemeDefaults.dataTableHorizontalMargin)),
      headingRowHeight: CGFloat(node.double("heading_row_height")
        ?? Double(RufletThemeDefaults.dataTableHeadingHeight)),
      dataRowMinHeight: CGFloat(node.double("data_row_min_height")
        ?? Double(RufletThemeDefaults.dataTableRowMinHeight)),
      dataRowMaxHeight: CGFloat(node.double("data_row_max_height")
        ?? Double(RufletThemeDefaults.dataTableRowMaxHeight)),
      dividerThickness: CGFloat(node.double("divider_thickness") ?? 1),
      showBottomBorder: node.bool("show_bottom_border") ?? false,
      showCheckboxColumn: node.bool("show_checkbox_column") ?? false)
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
  let events: RufletEventSink
  @State private var pointerOrigin: CGPoint?

  func body(content: Content) -> some View {
    content
      .onTapGesture(count: 2) { events.fire(node, "double_tap") }
      .onTapGesture(count: 1) { events.fire(node, "tap") }
      .modifier(LongPressReporter(node: node, events: events))
      .simultaneousGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
          .onChanged { value in
            guard pointerOrigin == nil else { return }
            pointerOrigin = value.startLocation
            events.fire(
              node, "tap_down",
              data: CollectionParity.tapDownPayload(
                x: value.startLocation.x, y: value.startLocation.y))
          }
          .onEnded { value in
            defer { pointerOrigin = nil }
            guard let origin = pointerOrigin else { return }
            let distance = hypot(value.location.x - origin.x, value.location.y - origin.y)
            if distance > 18 { events.fire(node, "tap_cancel") }
          })
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

  static func pageIndex(forOffset offset: Double, count: Int) -> Int {
    clampedIndex(Int(offset.rounded()), count: count)
  }

  static func tapDownPayload(x: CGFloat, y: CGFloat) -> RufletValue {
    .map([
      "local_x": .double(Double(x)), "local_y": .double(Double(y)),
      "global_x": .double(Double(x)), "global_y": .double(Double(y)),
      "kind": .string("touch")
    ])
  }
}

private struct CollectionScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct CollectionScrollReporter: ViewModifier {
  let node: ControlNode
  let horizontal: Bool
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("scroll") {
      content
        .coordinateSpace(name: "ruflet-scroll-\(node.id)")
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: CollectionScrollOffsetKey.self,
              value: horizontal
                ? -proxy.frame(in: .named("ruflet-scroll-\(node.id)")).minX
                : -proxy.frame(in: .named("ruflet-scroll-\(node.id)")).minY)
          })
        .onPreferenceChange(CollectionScrollOffsetKey.self) { pixels in
          events.fire(
            node, "scroll",
            data: .map([
              "pixels": .double(Double(max(0, pixels))),
              "event_type": .string("update"),
              "axis": .string(horizontal ? "horizontal" : "vertical")
            ]))
        }
    } else {
      content
    }
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
