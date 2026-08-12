import RufletEngine
import RufletProtocol
import SwiftUI

enum RufletFlexMath {
  static func flex(_ value: RufletValue?) -> Double {
    switch value {
    case .bool(true): return 1
    case .int(let factor): return max(Double(factor), 0)
    case .double(let factor): return max(factor, 0)
    case .string(let raw):
      if raw.lowercased() == "true" { return 1 }
      return max(Double(raw) ?? 0, 0)
    default: return 0
    }
  }

  static func allocations(available: CGFloat, flexes: [Double]) -> [CGFloat] {
    let total = flexes.reduce(0, +)
    guard total > 0 else { return Array(repeating: 0, count: flexes.count) }
    return flexes.map { max(available, 0) * CGFloat($0 / total) }
  }

  static func stretching(_ size: CGSize, axis: LayoutAxis, crossExtent: CGFloat) -> CGSize {
    axis == .horizontal
      ? CGSize(width: size.width, height: max(crossExtent, 0))
      : CGSize(width: max(crossExtent, 0), height: size.height)
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct FlexValueKey: LayoutValueKey {
  static let defaultValue: Double = 0
}

@available(iOS 16.0, macOS 13.0, *)
private struct LooseFlexValueKey: LayoutValueKey {
  static let defaultValue = false
}

@available(iOS 16.0, macOS 13.0, *)
struct RufletFlexChild: View {
  let id: Int
  let axis: LayoutAxis
  @EnvironmentObject private var store: ControlStore

  @ViewBuilder
  var body: some View {
    let node = store.node(id)
    let flex = RufletFlexMath.flex(node?.props["expand"])
    let loose = node?.bool("expand_loose") ?? false
    let childAxis: LayoutAxis = flex > 0 && !loose
      ? (axis == .horizontal ? .tightHorizontal : .tightVertical)
      : .none

    ControlView(id: id, axis: childAxis)
      .layoutValue(key: FlexValueKey.self, value: flex)
      .layoutValue(key: LooseFlexValueKey.self, value: loose)
  }
}

/// Flutter's RenderFlex distributes remaining main-axis space by integer flex
/// factors. SwiftUI's HStack/VStack only know “flexible or not”, which made
/// `expand: 1` and `expand: 2` receive equal shares. This layout preserves the
/// Flet flex factor and its `Expanded` versus `Flexible` (loose) distinction.
@available(iOS 16.0, macOS 13.0, *)
struct RufletFlexLayout: Layout {
  let axis: LayoutAxis
  let spacing: CGFloat
  let mainAlignment: ControlProps.MainAxisAlignment
  let crossAlignment: ControlProps.CrossAxisAlignment
  let tight: Bool

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    let result = measurement(proposal: proposal, subviews: subviews)
    return axis == .horizontal
      ? CGSize(width: result.main, height: result.cross)
      : CGSize(width: result.cross, height: result.main)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    let resolvedProposal = ProposedViewSize(width: bounds.width, height: bounds.height)
    let result = measurement(proposal: resolvedProposal, subviews: subviews)
    let occupied = result.sizes.reduce(0) { $0 + main($1) }
      + spacing * CGFloat(max(subviews.count - 1, 0))
    let remaining = max(result.main - occupied, 0)
    let distribution = distributionOffsets(remaining: remaining, count: subviews.count)
    var cursor = distribution.leading

    for index in subviews.indices {
      let size = result.sizes[index]
      let crossOffset = crossAlignment == .baseline
        ? result.baselineAbove - result.baselines[index]
        : crossOrigin(container: result.cross, child: cross(size))
      let point = axis == .horizontal
        ? CGPoint(x: bounds.minX + cursor, y: bounds.minY + crossOffset)
        : CGPoint(x: bounds.minX + crossOffset, y: bounds.minY + cursor)
      subviews[index].place(
        at: point, anchor: .topLeading,
        proposal: ProposedViewSize(width: size.width, height: size.height))
      cursor += main(size) + spacing + distribution.between
    }
  }

  private func measurement(proposal: ProposedViewSize, subviews: Subviews) -> Result {
    let proposedMain = axis == .horizontal ? proposal.width : proposal.height
    let proposedCross = axis == .horizontal ? proposal.height : proposal.width
    let baseSpacing = spacing * CGFloat(max(subviews.count - 1, 0))
    let flexes = subviews.map { $0[FlexValueKey.self] }
    var sizes = Array(repeating: CGSize.zero, count: subviews.count)
    var fixedMain: CGFloat = 0

    for index in subviews.indices where flexes[index] <= 0 {
      let childProposal = axis == .horizontal
        ? ProposedViewSize(width: nil, height: proposedCross)
        : ProposedViewSize(width: proposedCross, height: nil)
      sizes[index] = subviews[index].sizeThatFits(childProposal)
      fixedMain += main(sizes[index])
    }

    let finiteMain = proposedMain.flatMap { $0.isFinite ? max($0, 0) : nil }
    let available = max((finiteMain ?? fixedMain) - fixedMain - baseSpacing, 0)
    let shares = RufletFlexMath.allocations(available: available, flexes: flexes)
    for index in subviews.indices where flexes[index] > 0 {
      let childProposal = axis == .horizontal
        ? ProposedViewSize(width: shares[index], height: proposedCross)
        : ProposedViewSize(width: proposedCross, height: shares[index])
      sizes[index] = subviews[index].sizeThatFits(childProposal)
      if !subviews[index][LooseFlexValueKey.self] {
        if axis == .horizontal { sizes[index].width = shares[index] }
        else { sizes[index].height = shares[index] }
      }
    }

    // A SwiftUI proposal is loose; Flutter's stretch constraint is tight.
    if crossAlignment == .stretch,
      let proposedCross, proposedCross.isFinite
    {
      for index in subviews.indices {
        sizes[index] = RufletFlexMath.stretching(
          sizes[index], axis: axis, crossExtent: proposedCross)
      }
    }

    let baselines = subviews.indices.map { index -> CGFloat in
      guard crossAlignment == .baseline, axis == .horizontal else { return cross(sizes[index]) }
      let dimensions = subviews[index].dimensions(
        in: ProposedViewSize(width: sizes[index].width, height: sizes[index].height))
      let baseline = dimensions[.firstTextBaseline]
      return baseline.isFinite ? baseline : sizes[index].height
    }
    let baselineAbove = baselines.max() ?? 0
    let baselineBelow = sizes.indices.map {
      max(cross(sizes[$0]) - baselines[$0], 0)
    }.max() ?? 0
    let usedMain = sizes.reduce(0) { $0 + main($1) } + baseSpacing
    let mainSize = !tight ? (finiteMain ?? usedMain) : usedMain
    let measuredCross = crossAlignment == .baseline && axis == .horizontal
      ? baselineAbove + baselineBelow : (sizes.map(cross).max() ?? 0)
    return Result(
      main: mainSize, cross: proposedCross ?? measuredCross, sizes: sizes,
      baselines: baselines, baselineAbove: baselineAbove)
  }

  private func distributionOffsets(remaining: CGFloat, count: Int) -> (leading: CGFloat, between: CGFloat) {
    guard count > 0 else { return (0, 0) }
    switch mainAlignment {
    case .start: return (0, 0)
    case .end: return (remaining, 0)
    case .center: return (remaining / 2, 0)
    case .spaceBetween: return (0, count > 1 ? remaining / CGFloat(count - 1) : 0)
    case .spaceAround:
      let gap = remaining / CGFloat(count)
      return (gap / 2, gap)
    case .spaceEvenly:
      let gap = remaining / CGFloat(count + 1)
      return (gap, gap)
    }
  }

  private func crossOrigin(container: CGFloat, child: CGFloat) -> CGFloat {
    switch crossAlignment {
    case .start, .baseline, .stretch: return 0
    case .end: return max(container - child, 0)
    case .center: return max(container - child, 0) / 2
    }
  }

  private func main(_ size: CGSize) -> CGFloat { axis == .horizontal ? size.width : size.height }
  private func cross(_ size: CGSize) -> CGFloat { axis == .horizontal ? size.height : size.width }

  private struct Result {
    let main: CGFloat
    let cross: CGFloat
    var sizes: [CGSize]
    let baselines: [CGFloat]
    let baselineAbove: CGFloat
  }
}
