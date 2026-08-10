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
    let horizontal = node.bool("horizontal") ?? false
    let spacing = CGFloat(node.double("spacing") ?? 0)
    let axis: LayoutAxis = horizontal ? .horizontal : .vertical

    ScrollView(horizontal ? .horizontal : .vertical, showsIndicators: true) {
      Group {
        if horizontal {
          LazyHStack(spacing: spacing) { rows(axis: axis) }
        } else {
          LazyVStack(spacing: spacing) { rows(axis: axis) }
        }
      }
      .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
    }
  }

  /// `divider_thickness` puts a rule between items — the one place a Flet list
  /// differs from a plain stack of children.
  @ViewBuilder
  private func rows(axis: LayoutAxis) -> some View {
    let thickness = node.double("divider_thickness") ?? 0
    let children = node.childIDs

    ForEach(Array(children.enumerated()), id: \.element) { index, childID in
      if thickness > 0, index > 0 {
        Divider()
          .frame(
            width: axis == .horizontal ? CGFloat(thickness) : nil,
            height: axis == .horizontal ? nil : CGFloat(thickness))
          .background(MaterialPalette.color(node.string("divider_color")))
      }
      ControlView(id: childID, axis: axis)
    }
  }
}

/// `GridView` — a wrapping grid with either a fixed column count
/// (`runs_count`) or a maximum item extent, the two modes Flet exposes.
struct GridViewControlView: View {
  let node: ControlNode

  var body: some View {
    let spacing = CGFloat(node.double("spacing") ?? 10)
    let runSpacing = CGFloat(node.double("run_spacing") ?? 10)

    ScrollView(node.bool("horizontal") == true ? .horizontal : .vertical) {
      LazyVGrid(columns: columns(spacing: spacing), spacing: runSpacing) {
        ControlList(ids: node.childIDs, axis: .none)
      }
      .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
    }
  }

  private func columns(spacing: CGFloat) -> [GridItem] {
    if let runs = node.int("runs_count"), runs > 0 {
      return Array(repeating: GridItem(.flexible(), spacing: spacing), count: runs)
    }
    let extent = CGFloat(node.double("max_extent") ?? 150)
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
    List {
      ForEach(node.childIDs, id: \.self) { childID in
        ControlView(id: childID, axis: .vertical)
      }
      .onMove(perform: reorder)
    }
    .listStyle(.plain)
    .modifier(AlwaysEditing())
  }

  private func reorder(from source: IndexSet, to destination: Int) {
    guard let origin = source.first else { return }
    events.send(
      node.id, "reorder",
      .map([
        "old_index": .int(Int64(origin)),
        // SwiftUI reports the slot *before* removal; Flutter reports the final
        // index, so close the gap when moving down.
        "new_index": .int(Int64(destination > origin ? destination - 1 : destination))
      ]))
  }
}

/// `PageView` — a horizontally paged carousel.
struct PageViewControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    TabView(
      selection: Binding(
        get: { node.int("selected_index") ?? 0 },
        set: { events.commit(node, key: "selected_index", value: .int(Int64($0))) })
    ) {
      ForEach(Array(node.childIDs.enumerated()), id: \.element) { index, childID in
        ControlView(id: childID, axis: .none).tag(index)
      }
    }
    .modifier(PagedTabStyle())
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
    HStack(spacing: 12) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
      } else if node.props["leading"] != nil {
        RufletIcon(value: node.props["leading"], size: 22, color: nil)
      }

      VStack(alignment: .leading, spacing: 2) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
        }
        if let subtitleID = node.controlID(forKey: "subtitle") {
          ControlView(id: subtitleID, axis: .none)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      }
    }
    .padding(ControlProps.edgeInsets(node.props["content_padding"]) ?? EdgeInsets(
      top: 8, leading: 16, bottom: 8, trailing: 16))
    .background(
      (node.bool("selected") ?? false)
        ? MaterialPalette.color(node.string("selected_tile_color") ?? "secondarycontainer")
        : MaterialPalette.color(node.string("bgcolor")))
    .contentShape(Rectangle())
    .modifier(TapReporter(node: node, events: events))
  }
}

/// `ExpansionTile` — a disclosure row that keeps its state on the Ruby side.
struct ExpansionTileControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { node.bool("initially_expanded") ?? node.bool("expanded") ?? false },
        set: { events.commit(node, key: "expanded", value: .bool($0)) })
    ) {
      VStack(alignment: .leading, spacing: 0) {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    } label: {
      HStack(spacing: 12) {
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
        }
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
        }
      }
    }
    .padding(.horizontal, 16)
  }
}

/// `ExpansionPanelList` — several independently expandable panels.
struct ExpansionPanelListControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    VStack(spacing: CGFloat(node.double("spacing") ?? 2)) {
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
          // Flet reports the change on the list, carrying the panel's index.
          guard list.handlesEvent("change") else { return }
          events.send(
            list.id, "change",
            .map([
              "index": .int(Int64(list.childIDs.firstIndex(of: node.id) ?? 0)),
              "expanded": .bool(expanded)
            ]))
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

/// `Tabs` / `TabBar` — a tab strip over `TabBarView` content.
struct TabsControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let tabs = tabNodes
    let selected = node.int("selected_index") ?? 0

    VStack(spacing: 0) {
      Picker(
        "",
        selection: Binding(
          get: { selected },
          set: { events.commit(node, key: "selected_index", value: .int(Int64($0))) })
      ) {
        ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
          tabLabel(tab).tag(index)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal)
      .padding(.vertical, 8)

      if let content = tabs.indices.contains(selected) ? tabs[selected].controlID(forKey: "content") : nil {
        ControlView(id: content, axis: .vertical)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let tabView = effectiveTabView {
        let pages = tabView.childIDs
        if pages.indices.contains(selected) {
          ControlView(id: pages[selected], axis: .vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }

  private var tabNodes: [ControlNode] {
    let owner = effectiveTabBar ?? node
    let ids = owner.controlIDs(forKey: "tabs") + owner.childIDs
    return ids.compactMap { store.node($0) }.filter { $0.type == "Tab" }
  }

  private var effectiveTabBar: ControlNode? {
    node.type == "TabBar" ? node : descendant(ofType: "TabBar", from: node)
  }

  private var effectiveTabView: ControlNode? {
    if let directID = node.controlID(forKey: "tab_bar_view") { return store.node(directID) }
    return descendant(ofType: "TabBarView", from: node)
  }

  private func descendant(ofType type: String, from root: ControlNode) -> ControlNode? {
    var pending = root.props.values.flatMap(controlIDs)
    var visited: Set<Int> = []
    while let id = pending.popLast() {
      guard visited.insert(id).inserted, let child = store.node(id) else { continue }
      if child.type == type { return child }
      pending.append(contentsOf: child.props.values.flatMap(controlIDs))
    }
    return nil
  }

  private func controlIDs(in value: RufletValue) -> [Int] {
    switch value {
    case .controlRef(let id): return [id]
    case .array(let values): return values.flatMap(controlIDs)
    case .map(let values): return values.values.flatMap(controlIDs)
    default: return []
    }
  }

  @ViewBuilder
  private func tabLabel(_ tab: ControlNode) -> some View {
    // `Label` is one semantic view, so SwiftUI passes it to the native picker
    // as one segment. Building an HStack here makes SwiftUI flatten the icon
    // and title into separate segments.
    if let label = tab.string("label") ?? tab.string("text"), !label.isEmpty,
      let symbol = IconMapping.symbol(for: tab.props["icon"])
    {
      Label(label, systemImage: symbol)
        .labelStyle(.titleAndIcon)
    } else if let label = tab.string("label") ?? tab.string("text"), !label.isEmpty {
      Text(label)
    } else if let symbol = IconMapping.symbol(for: tab.props["icon"]) {
      Image(systemName: symbol)
    } else if let contentID = tab.controlID(forKey: "tab_content"),
      let content = store.node(contentID), content.type == "Text"
    {
      Text(content.string("value") ?? "")
    } else {
      Text("Tab")
    }
  }
}

/// `TabBarView` — the pages behind a `TabBar`.
struct TabBarViewControlView: View {
  let node: ControlNode

  var body: some View {
    let selected = node.int("selected_index") ?? 0
    let children = node.childIDs
    if children.indices.contains(selected) {
      ControlView(id: children[selected], axis: .vertical)
    }
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
    let spacing = CGFloat(node.double("column_spacing")
      ?? Double(FletThemeDefaults.dataTableColumnSpacing))

    ScrollView(.horizontal, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: spacing) {
          ForEach(columns, id: \.id) { column in
            headerCell(column)
          }
        }
        .frame(minHeight: CGFloat(node.double("heading_row_height")
          ?? Double(FletThemeDefaults.dataTableHeadingHeight)))
        .font(.subheadline.weight(.semibold))

        tableDivider

        ForEach(rows, id: \.id) { row in
          HStack(spacing: spacing) {
            ForEach(row.controlIDs(forKey: "cells"), id: \.self) { cellID in
              cellContent(cellID)
            }
          }
          .frame(minHeight: CGFloat(node.double("data_row_min_height")
            ?? Double(FletThemeDefaults.dataTableRowMinHeight)))
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            (row.bool("selected") ?? false)
              ? MaterialPalette.color("secondarycontainer", default: .clear) : Color.clear)
          .contentShape(Rectangle())
          .onTapGesture { events.fire(row, "select_changed") }

          if node.double("divider_thickness") ?? 1 > 0 { tableDivider }
        }
      }
      .padding(.horizontal, 12)
    }
  }

  private var tableDivider: some View {
    Rectangle()
      .fill(MaterialPalette.color(for: node, property: "divider_color", default: .clear))
      .frame(height: CGFloat(node.double("divider_thickness") ?? 1))
  }

  @ViewBuilder
  private func headerCell(_ column: ControlNode) -> some View {
    if let labelID = column.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else {
      Text(column.string("label") ?? "")
    }
  }

  @ViewBuilder
  private func cellContent(_ cellID: Int) -> some View {
    if let cell = store.node(cellID) {
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
    } else {
      ControlView(id: cellID, axis: .none)
    }
  }
}

/// Rows are draggable only while the list is editing on iOS; on macOS `onMove`
/// works without an edit mode.
private struct AlwaysEditing: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.environment(\.editMode, .constant(.active))
    #else
      content
    #endif
  }
}
