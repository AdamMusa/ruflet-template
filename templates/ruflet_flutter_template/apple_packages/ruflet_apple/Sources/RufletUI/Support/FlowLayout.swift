import SwiftUI

/// Flutter's `Wrap` along either axis, including item, run, and cross alignment.
struct FlowLayout<Content: View>: View {
  let axis: Axis
  let spacing: CGFloat
  let runSpacing: CGFloat
  let alignment: ControlProps.MainAxisAlignment
  let runAlignment: ControlProps.MainAxisAlignment
  let crossAlignment: ControlProps.CrossAxisAlignment
  @ViewBuilder let content: () -> Content

  init(
    axis: Axis = .horizontal, spacing: CGFloat, runSpacing: CGFloat,
    alignment: ControlProps.MainAxisAlignment = .start,
    runAlignment: ControlProps.MainAxisAlignment = .start,
    crossAlignment: ControlProps.CrossAxisAlignment = .start,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.axis = axis
    self.spacing = spacing
    self.runSpacing = runSpacing
    self.alignment = alignment
    self.runAlignment = runAlignment
    self.crossAlignment = crossAlignment
    self.content = content
  }

  var body: some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
      FlowLayoutEngine(
        axis: axis, spacing: spacing, runSpacing: runSpacing,
        alignment: alignment, runAlignment: runAlignment,
        crossAlignment: crossAlignment
      ) { content() }
    } else if axis == .horizontal {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: crossAlignment.vertical, spacing: spacing) { content() }
      }
    } else {
      ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: crossAlignment.horizontal, spacing: spacing) { content() }
      }
    }
  }
}

enum RufletWrapMath {
  static func crossAlignment(
    _ raw: String?, default defaultValue: ControlProps.CrossAxisAlignment
  ) -> ControlProps.CrossAxisAlignment {
    switch raw?.lowercased() {
    case "start": return .start
    case "end": return .end
    case "center": return .center
    default: return defaultValue
    }
  }

  static func distribution(
    _ alignment: ControlProps.MainAxisAlignment, freeSpace: CGFloat, count: Int
  ) -> (leading: CGFloat, between: CGFloat) {
    guard count > 0 else { return (0, 0) }
    let free = max(freeSpace, 0)
    switch alignment {
    case .start: return (0, 0)
    case .end: return (free, 0)
    case .center: return (free / 2, 0)
    case .spaceBetween: return (0, count > 1 ? free / CGFloat(count - 1) : 0)
    case .spaceAround:
      let gap = free / CGFloat(count)
      return (gap / 2, gap)
    case .spaceEvenly:
      let gap = free / CGFloat(count + 1)
      return (gap, gap)
    }
  }

  static func crossOffset(
    _ alignment: ControlProps.CrossAxisAlignment,
    runExtent: CGFloat, childExtent: CGFloat
  ) -> CGFloat {
    switch alignment {
    case .end: return max(runExtent - childExtent, 0)
    case .center: return max(runExtent - childExtent, 0) / 2
    case .start, .stretch, .baseline: return 0
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private struct FlowLayoutEngine: Layout {
  let axis: Axis
  let spacing: CGFloat
  let runSpacing: CGFloat
  let alignment: ControlProps.MainAxisAlignment
  let runAlignment: ControlProps.MainAxisAlignment
  let crossAlignment: ControlProps.CrossAxisAlignment

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    let proposedMain = main(proposal)
    let runs = makeRuns(subviews: subviews, availableMain: finite(proposedMain) ?? .infinity)
    let contentMain = runs.map(\.main).max() ?? 0
    let contentCross = runs.reduce(0) { $0 + $1.cross }
      + runSpacing * CGFloat(max(runs.count - 1, 0))
    return size(main: min(finite(proposedMain) ?? contentMain, contentMain), cross: contentCross)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    let containerMain = main(bounds.size)
    let containerCross = cross(bounds.size)
    let runs = makeRuns(subviews: subviews, availableMain: containerMain)
    let occupiedCross = runs.reduce(0) { $0 + $1.cross }
      + runSpacing * CGFloat(max(runs.count - 1, 0))
    let runDistribution = RufletWrapMath.distribution(
      runAlignment, freeSpace: containerCross - occupiedCross, count: runs.count)
    var crossCursor = runDistribution.leading

    for run in runs {
      let itemDistribution = RufletWrapMath.distribution(
        alignment, freeSpace: containerMain - run.main, count: run.items.count)
      var mainCursor = itemDistribution.leading
      for item in run.items {
        var childSize = item.size
        if crossAlignment == .stretch {
          if axis == .horizontal { childSize.height = run.cross }
          else { childSize.width = run.cross }
        }
        let childCross = RufletWrapMath.crossOffset(
          crossAlignment, runExtent: run.cross, childExtent: cross(childSize))
        subviews[item.index].place(
          at: point(bounds: bounds, main: mainCursor, cross: crossCursor + childCross),
          anchor: .topLeading,
          proposal: ProposedViewSize(width: childSize.width, height: childSize.height))
        mainCursor += main(childSize) + spacing + itemDistribution.between
      }
      crossCursor += run.cross + runSpacing + runDistribution.between
    }
  }

  private struct Item { let index: Int; let size: CGSize }
  private struct Run {
    var items: [Item] = []
    var main: CGFloat = 0
    var cross: CGFloat = 0
  }

  private func makeRuns(subviews: Subviews, availableMain: CGFloat) -> [Run] {
    var runs: [Run] = []
    var current = Run()
    for index in subviews.indices {
      let childSize = subviews[index].sizeThatFits(.unspecified)
      let childMain = main(childSize)
      let advance = current.items.isEmpty ? childMain : spacing + childMain
      if !current.items.isEmpty, current.main + advance > availableMain {
        runs.append(current)
        current = Run()
      }
      current.items.append(Item(index: index, size: childSize))
      current.main += current.items.count == 1 ? childMain : advance
      current.cross = max(current.cross, cross(childSize))
    }
    if !current.items.isEmpty { runs.append(current) }
    return runs
  }

  private func finite(_ value: CGFloat?) -> CGFloat? {
    guard let value, value.isFinite else { return nil }
    return max(value, 0)
  }
  private func main(_ proposal: ProposedViewSize) -> CGFloat? {
    axis == .horizontal ? proposal.width : proposal.height
  }
  private func main(_ size: CGSize) -> CGFloat { axis == .horizontal ? size.width : size.height }
  private func cross(_ size: CGSize) -> CGFloat { axis == .horizontal ? size.height : size.width }
  private func size(main: CGFloat, cross: CGFloat) -> CGSize {
    axis == .horizontal ? CGSize(width: main, height: cross) : CGSize(width: cross, height: main)
  }
  private func point(bounds: CGRect, main: CGFloat, cross: CGFloat) -> CGPoint {
    axis == .horizontal
      ? CGPoint(x: bounds.minX + main, y: bounds.minY + cross)
      : CGPoint(x: bounds.minX + cross, y: bounds.minY + main)
  }
}
