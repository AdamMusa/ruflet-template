import RufletEngine
import RufletProtocol
import SwiftUI

/// `Row` — a horizontal stack.
///
/// `alignment` is the main (horizontal) axis and `vertical_alignment` the
/// cross axis, matching Flutter's `Row`. The distributing alignments
/// (`spaceBetween`/`Around`/`Evenly`) have no SwiftUI stack equivalent, so they
/// are built from interleaved spacers the way Flutter's flex layout does.
struct RowControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  var body: some View {
    let main = ControlProps.MainAxisAlignment(node.string("alignment"))
    // Flutter/Flet Row defaults to a centred cross axis. Using `.start` here
    // top-aligned every icon/text pair whose Ruby omitted the property.
    let cross = ControlProps.CrossAxisAlignment(
      node.string("vertical_alignment"), default: .center)
    let spacing = CGFloat(node.double("spacing") ?? 10)
    let children = node.childIDs
    let tight = node.bool("tight") ?? false

    Group {
      if node.bool("wrap") == true {
        WrappingStack(ids: children, spacing: spacing, runSpacing: CGFloat(node.double("run_spacing") ?? spacing))
      } else {
        HStack(alignment: cross.vertical, spacing: main.usesSpacers && !tight ? 0 : spacing) {
          DistributedChildren(
            ids: children, alignment: main, axis: .horizontal,
            spacing: spacing, tight: tight)
        }
      }
    }
    .modifier(ScrollableStack(node: node, axis: .horizontal))
  }
}

/// `Column` — a vertical stack. `alignment` is the vertical axis here and
/// `horizontal_alignment` the cross axis.
struct ColumnControlView: View {
  let node: ControlNode

  var body: some View {
    let main = ControlProps.MainAxisAlignment(node.string("alignment"))
    let cross = ControlProps.CrossAxisAlignment(node.string("horizontal_alignment"))
    let spacing = CGFloat(node.double("spacing") ?? 10)
    let tight = node.bool("tight") ?? false

    VStack(alignment: cross.horizontal, spacing: main.usesSpacers && !tight ? 0 : spacing) {
      DistributedChildren(
        ids: node.childIDs, alignment: main, axis: .vertical,
        spacing: spacing, tight: tight)
    }
    .modifier(CrossStretch(alignment: cross, axis: .vertical))
    .modifier(ScrollableStack(node: node, axis: .vertical))
  }
}

/// Lays children out with the spacers a distributing `MainAxisAlignment` needs.
private struct DistributedChildren: View {
  let ids: [Int]
  let alignment: ControlProps.MainAxisAlignment
  let axis: LayoutAxis
  let spacing: CGFloat
  let tight: Bool

  var body: some View {
    switch alignment {
    case .start, .center, .end:
      // A plain stack cannot centre or end-align its content unless it is
      // given the room to; the leading/trailing spacers do that, and the
      // stack's own alignment handles the rest.
      if !tight, alignment != .start { Spacer(minLength: 0) }
      ControlList(ids: ids, axis: axis)
      if !tight, alignment != .end { Spacer(minLength: 0) }

    case .spaceBetween:
      ForEach(Array(ids.enumerated()), id: \.element) { index, id in
        if !tight, index > 0 { Spacer(minLength: spacing) }
        ControlView(id: id, axis: axis)
      }

    case .spaceAround:
      ForEach(Array(ids.enumerated()), id: \.element) { index, id in
        if !tight { Spacer(minLength: index == 0 ? spacing / 2 : spacing) }
        ControlView(id: id, axis: axis)
      }
      if !tight { Spacer(minLength: spacing / 2) }

    case .spaceEvenly:
      ForEach(Array(ids.enumerated()), id: \.element) { _, id in
        if !tight { Spacer(minLength: spacing) }
        ControlView(id: id, axis: axis)
      }
      if !tight { Spacer(minLength: spacing) }
    }
  }
}

/// `CrossAxisAlignment.stretch` asks children to fill the cross axis.
private struct CrossStretch: ViewModifier {
  let alignment: ControlProps.CrossAxisAlignment
  let axis: LayoutAxis

  func body(content: Content) -> some View {
    if alignment == .stretch {
      content.frame(
        maxWidth: axis == .vertical ? .infinity : nil,
        maxHeight: axis == .horizontal ? .infinity : nil)
    } else {
      content
    }
  }
}

/// Wraps a stack in a `ScrollView` when Ruby set `scroll`.
///
/// Flet accepts `"auto"`, `"always"`, `"adaptive"`, `"hidden"` and `true`; all
/// of them mean "this stack scrolls" on Apple platforms, where the scroll
/// indicator is already adaptive.
struct ScrollableStack: ViewModifier {
  let node: ControlNode
  let axis: Axis.Set

  func body(content: Content) -> some View {
    if scrolls {
      ScrollView(axis, showsIndicators: node.string("scroll") != "hidden") {
        content
      }
    } else {
      content
    }
  }

  private var scrolls: Bool {
    guard let value = node.props["scroll"], !value.isNull else { return false }
    if let flag = value.boolValue { return flag }
    return value.stringValue != nil
  }
}

/// `Stack` — children drawn on top of one another.
///
/// `host_positioned` in `_internals` tells the renderer that children carry
/// their own `left`/`top`/`right`/`bottom`, which is how Flet expresses
/// Flutter's `Positioned`.
struct StackControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  var body: some View {
    let alignment = ControlProps.alignment(node.props["alignment"]) ?? .topLeading

    ZStack(alignment: alignment) {
      ForEach(node.childIDs, id: \.self) { childID in
        if let child = store.node(childID), isPositioned(child) {
          PositionedChild(node: child, alignment: alignment)
        } else {
          ControlView(id: childID, axis: .none)
        }
      }
    }
  }

  private func isPositioned(_ child: ControlNode) -> Bool {
    ["left", "top", "right", "bottom"].contains { child.props[$0]?.doubleValue != nil }
  }
}

/// A stack child that placed itself.
private struct PositionedChild: View {
  let node: ControlNode
  let alignment: Alignment

  var body: some View {
    let left = node.double("left")
    let top = node.double("top")
    let right = node.double("right")
    let bottom = node.double("bottom")

    ControlView(id: node.id, axis: .none)
      .frame(
        maxWidth: .infinity, maxHeight: .infinity,
        alignment: Alignment(
          horizontal: left != nil ? .leading : (right != nil ? .trailing : alignment.horizontal),
          vertical: top != nil ? .top : (bottom != nil ? .bottom : alignment.vertical)))
      .offset(
        x: left.map { CGFloat($0) } ?? -(right.map { CGFloat($0) } ?? 0),
        y: top.map { CGFloat($0) } ?? -(bottom.map { CGFloat($0) } ?? 0))
      .animation(ControlProps.animation(node.props["animate_position"]), value: node)
  }
}

/// `ResponsiveRow` — children carry a `col` breakpoint map.
///
/// Flet lays these out on a 12-column grid; the same grid is reproduced here
/// against the container width, picking the breakpoint the width falls into.
struct ResponsiveRowControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @State private var availableWidth: CGFloat = 0

  var body: some View {
    let spacing = CGFloat(node.double("spacing") ?? 10)
    let runSpacing = CGFloat(node.double("run_spacing") ?? 10)
    let width = max(availableWidth, 1)
    let breakpoint = Self.breakpoint(for: width)
    let rows = Self.rows(ids: node.childIDs, store: store, breakpoint: breakpoint)

    VStack(alignment: .leading, spacing: runSpacing) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(alignment: .top, spacing: spacing) {
          ForEach(row, id: \.id) { entry in
            ControlView(id: entry.id, axis: .none)
              .frame(width: Self.width(
                columns: entry.columns, total: width,
                spacing: spacing, siblings: row.count))
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      GeometryReader { geometry in
        Color.clear.preference(
          key: ResponsiveRowWidthPreference.self,
          value: geometry.size.width)
      }
    }
    .onPreferenceChange(ResponsiveRowWidthPreference.self) { availableWidth = $0 }
  }

  struct Entry: Identifiable {
    let id: Int
    let columns: Double
  }

  /// Flet's breakpoint names, smallest first.
  static func breakpoint(for width: CGFloat) -> [String] {
    switch width {
    case ..<576: return ["xs"]
    case ..<768: return ["sm", "xs"]
    case ..<992: return ["md", "sm", "xs"]
    case ..<1200: return ["lg", "md", "sm", "xs"]
    default: return ["xl", "lg", "md", "sm", "xs"]
    }
  }

  static func rows(ids: [Int], store: ControlStore, breakpoint: [String]) -> [[Entry]] {
    var rows: [[Entry]] = []
    var current: [Entry] = []
    var used = 0.0

    for id in ids {
      let columns = columnSpan(store.node(id), breakpoint: breakpoint)
      if used + columns > 12, !current.isEmpty {
        rows.append(current)
        current = []
        used = 0
      }
      current.append(Entry(id: id, columns: columns))
      used += columns
    }
    if !current.isEmpty { rows.append(current) }
    return rows
  }

  private static func columnSpan(_ node: ControlNode?, breakpoint: [String]) -> Double {
    guard let value = node?.props["col"] else { return 12 }
    if let uniform = value.doubleValue { return uniform }
    guard let map = value.mapValue else { return 12 }
    for name in breakpoint {
      if let span = map[name]?.doubleValue { return span }
    }
    return 12
  }

  private static func width(
    columns: Double, total: CGFloat, spacing: CGFloat, siblings: Int
  ) -> CGFloat {
    let gaps = spacing * CGFloat(max(siblings - 1, 0))
    return max((total - gaps) * CGFloat(columns / 12), 0)
  }
}

private struct ResponsiveRowWidthPreference: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

/// `Row(wrap: true)` — flows children onto as many lines as they need.
struct WrappingStack: View {
  let ids: [Int]
  let spacing: CGFloat
  let runSpacing: CGFloat

  var body: some View {
    // SwiftUI has no flow layout before iOS 16, so lines are measured with
    // per-child width preferences and grouped as they arrive.
    FlowLayout(spacing: spacing, runSpacing: runSpacing) {
      ForEach(ids, id: \.self) { id in
        ControlView(id: id, axis: .none)
      }
    }
  }
}
