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

  @ViewBuilder
  var body: some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
      ResponsiveGridLayout(
        spans: node.childIDs.map { store.node($0)?.props["col"] },
        columns: node.props["columns"],
        spacing: node.props["spacing"],
        runSpacing: node.props["run_spacing"],
        breakpoints: ResponsiveGridMath.breakpoints(node.props["breakpoints"]),
        alignment: node.string("alignment") ?? "start",
        verticalAlignment: node.string("vertical_alignment") ?? "start"
      ) {
        ForEach(node.childIDs, id: \.self) { id in
          ControlView(id: id, axis: .none)
        }
      }
      // Flutter's LayoutBuilder always receives its parent's finite maximum
      // width. Claiming that proposal here prevents an intrinsic-width parent
      // Column from collapsing the whole 12-column grid to a narrow strip.
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(node.childIDs, id: \.self) { id in
          ControlView(id: id, axis: .none)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

enum ResponsiveGridMath {
  static let defaultBreakpoints: [String: Double] = [
    "xs": 0, "sm": 576, "md": 768, "lg": 992, "xl": 1200, "xxl": 1400,
  ]

  static func breakpoints(_ value: RufletValue?) -> [String: Double] {
    guard let map = value?.mapValue else { return defaultBreakpoints }
    let parsed = map.reduce(into: [String: Double]()) { result, entry in
      if let number = entry.value.doubleValue { result[entry.key] = number }
    }
    return parsed.isEmpty ? defaultBreakpoints : parsed
  }

  /// Exact equivalent of Flet's `getBreakpointNumber`: start with the unnamed
  /// value (or the supplied default), then choose the matching breakpoint with
  /// the greatest threshold.
  static func value(
    _ source: RufletValue?, default defaultValue: Double,
    width: CGFloat, breakpoints: [String: Double]
  ) -> Double {
    if let scalar = source?.doubleValue { return scalar }
    guard let map = source?.mapValue else { return defaultValue }
    var selected = map[""]?.doubleValue ?? defaultValue
    var highest = -Double.infinity
    for (name, candidate) in map {
      guard !name.isEmpty, let threshold = breakpoints[name],
        CGFloat(threshold) <= width, threshold >= highest,
        let number = candidate.doubleValue
      else { continue }
      highest = threshold
      selected = number
    }
    return selected
  }

  static func lines(spans: [Double], columns: Double) -> [[Int]] {
    var result: [[Int]] = []
    var current: [Int] = []
    var used = 0.0
    for index in spans.indices {
      let span = min(max(spans[index], 0), columns)
      if used + span > columns, !current.isEmpty {
        result.append(current)
        current = []
        used = 0
      }
      current.append(index)
      used += span
    }
    if !current.isEmpty { result.append(current) }
    return result
  }

  /// Flet computes one grid-column width, then adds internal gaps for a child
  /// spanning multiple columns. This is intentionally not based on sibling
  /// count; partial final rows keep the same widths as full rows.
  static func itemWidth(
    span: Double, columns: Double, total: CGFloat, spacing: CGFloat
  ) -> CGFloat {
    guard columns > 0 else { return 0 }
    let columnWidth = (total - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    return max(columnWidth * CGFloat(span) + spacing * CGFloat(span - 1), 0)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private struct ResponsiveGridLayout: Layout {
  let spans: [RufletValue?]
  let columns: RufletValue?
  let spacing: RufletValue?
  let runSpacing: RufletValue?
  let breakpoints: [String: Double]
  let alignment: String
  let verticalAlignment: String

  struct Line {
    let indices: [Int]
    let sizes: [CGSize]
    let width: CGFloat
    let height: CGFloat
  }

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    let width = finiteWidth(proposal.width, subviews: subviews)
    let metrics = resolved(width: width, subviews: subviews)
    let height = metrics.lines.reduce(0) { $0 + $1.height }
      + metrics.runSpacing * CGFloat(max(metrics.lines.count - 1, 0))
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    let metrics = resolved(width: bounds.width, subviews: subviews)
    var y = bounds.minY
    for line in metrics.lines {
      let distribution = horizontalDistribution(
        lineWidth: line.width, available: bounds.width,
        count: line.indices.count, baseSpacing: metrics.spacing)
      var x = bounds.minX + distribution.offset
      for position in line.indices.indices {
        let index = line.indices[position]
        let size = line.sizes[position]
        let verticalOffset: CGFloat
        switch verticalAlignment.lowercased() {
        case "center": verticalOffset = (line.height - size.height) / 2
        case "end": verticalOffset = line.height - size.height
        default: verticalOffset = 0
        }
        subviews[index].place(
          at: CGPoint(x: x, y: y + verticalOffset), anchor: .topLeading,
          proposal: ProposedViewSize(width: size.width, height: size.height))
        x += size.width + distribution.spacing
      }
      y += line.height + metrics.runSpacing
    }
  }

  private func resolved(width: CGFloat, subviews: Subviews)
    -> (lines: [Line], spacing: CGFloat, runSpacing: CGFloat)
  {
    let columnCount = max(ResponsiveGridMath.value(
      columns, default: 12, width: width, breakpoints: breakpoints), 1)
    let gap = CGFloat(ResponsiveGridMath.value(
      spacing, default: 10, width: width, breakpoints: breakpoints))
    let runGap = CGFloat(ResponsiveGridMath.value(
      runSpacing, default: 10, width: width, breakpoints: breakpoints))
    let resolvedSpans = subviews.indices.map { index in
      min(max(ResponsiveGridMath.value(
        index < spans.count ? spans[index] : nil,
        default: 12, width: width, breakpoints: breakpoints), 0), columnCount)
    }
    let lineIndices = ResponsiveGridMath.lines(spans: resolvedSpans, columns: columnCount)
    let lines = lineIndices.map { indices -> Line in
      let sizes = indices.map { index -> CGSize in
        let itemWidth = ResponsiveGridMath.itemWidth(
          span: resolvedSpans[index], columns: columnCount, total: width, spacing: gap)
        return subviews[index].sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
      }
      return Line(
        indices: indices, sizes: sizes,
        width: sizes.reduce(0) { $0 + $1.width } + gap * CGFloat(max(sizes.count - 1, 0)),
        height: sizes.map(\.height).max() ?? 0)
    }
    return (lines, gap, runGap)
  }

  private func finiteWidth(_ proposal: CGFloat?, subviews: Subviews) -> CGFloat {
    if let proposal, proposal.isFinite { return max(proposal, 0) }
    return subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
  }

  private func horizontalDistribution(
    lineWidth: CGFloat, available: CGFloat, count: Int, baseSpacing: CGFloat
  ) -> (offset: CGFloat, spacing: CGFloat) {
    let remainder = max(available - lineWidth, 0)
    switch alignment.lowercased() {
    case "center": return (remainder / 2, baseSpacing)
    case "end": return (remainder, baseSpacing)
    case "spacebetween" where count > 1:
      return (0, baseSpacing + remainder / CGFloat(count - 1))
    case "spacearound" where count > 0:
      let extra = remainder / CGFloat(count)
      return (extra / 2, baseSpacing + extra)
    case "spaceevenly" where count > 0:
      let extra = remainder / CGFloat(count + 1)
      return (extra, baseSpacing + extra)
    default: return (0, baseSpacing)
    }
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
