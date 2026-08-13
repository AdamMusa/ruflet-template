import SwiftUI

/// iOS 15/macOS 13-compatible counterpart of Flutter's `Wrap` render box.
/// SwiftUI's `Layout` protocol is newer than Ruflet's deployment floor, so
/// children are measured once and a deterministic, testable plan positions
/// every run with the pinned spacing/alignment contract.
struct RufletFlowLayout: View {
  let axis: Axis
  let spacing: Double
  let runSpacing: Double
  let alignment: RufletMainAxisAlignment
  let runAlignment: RufletMainAxisAlignment
  let crossAlignment: RufletWrapCrossAlignment
  let crossExtent: CGFloat?
  let children: [AnyView]

  @State private var childSizes: [Int: CGSize] = [:]
  @State private var contentSize = CGSize.zero

  var body: some View {
    GeometryReader { proxy in
      let sizes = children.indices.map { childSizes[$0] ?? .zero }
      let plan = rufletFlowPlan(
        axis: axis,
        availableMainExtent: axis == .horizontal ? proxy.size.width : proxy.size.height,
        availableCrossExtent: crossExtent,
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        runAlignment: runAlignment,
        crossAlignment: crossAlignment,
        itemSizes: sizes)

      ZStack(alignment: .topLeading) {
        ForEach(Array(children.enumerated()), id: \.offset) { index, child in
          child
            .fixedSize()
            .background {
              GeometryReader { childProxy in
                Color.clear.preference(
                  key: RufletFlowChildSizeKey.self,
                  value: [index: childProxy.size])
              }
            }
            .offset(
              x: plan.positions.indices.contains(index) ? plan.positions[index].x : 0,
              y: plan.positions.indices.contains(index) ? plan.positions[index].y : 0)
        }
      }
      .frame(
        width: axis == .horizontal ? proxy.size.width : plan.contentSize.width,
        height: axis == .horizontal ? plan.contentSize.height : proxy.size.height,
        alignment: .topLeading
      )
      .preference(key: RufletFlowContentSizeKey.self, value: plan.contentSize)
    }
    .frame(
      width: axis == .vertical ? contentSize.width : nil,
      height: axis == .horizontal ? contentSize.height : nil
    )
    .onPreferenceChange(RufletFlowChildSizeKey.self) { childSizes = $0 }
    .onPreferenceChange(RufletFlowContentSizeKey.self) { contentSize = $0 }
  }
}

struct RufletFlowPlan: Equatable {
  let positions: [CGPoint]
  let contentSize: CGSize
}

private struct RufletFlowRun {
  var indices: [Int] = []
  var mainExtent = CGFloat.zero
  var crossExtent = CGFloat.zero
}

/// Pure Flutter Wrap-compatible run planner shared by Row, Column and
/// ResponsiveRow and exercised independently from SwiftUI rendering.
func rufletFlowPlan(
  axis: Axis,
  availableMainExtent: CGFloat,
  availableCrossExtent: CGFloat?,
  spacing: CGFloat,
  runSpacing: CGFloat,
  alignment: RufletMainAxisAlignment,
  runAlignment: RufletMainAxisAlignment,
  crossAlignment: RufletWrapCrossAlignment,
  itemSizes: [CGSize]
) -> RufletFlowPlan {
  guard !itemSizes.isEmpty else {
    return RufletFlowPlan(positions: [], contentSize: .zero)
  }

  let boundedMain = availableMainExtent > 0 ? availableMainExtent : .greatestFiniteMagnitude
  var runs: [RufletFlowRun] = []
  var run = RufletFlowRun()

  for (index, size) in itemSizes.enumerated() {
    let main = axis == .horizontal ? size.width : size.height
    let cross = axis == .horizontal ? size.height : size.width
    let proposed = run.indices.isEmpty ? main : run.mainExtent + spacing + main
    if !run.indices.isEmpty, proposed > boundedMain {
      runs.append(run)
      run = RufletFlowRun()
    }
    if !run.indices.isEmpty { run.mainExtent += spacing }
    run.indices.append(index)
    run.mainExtent += main
    run.crossExtent = max(run.crossExtent, cross)
  }
  if !run.indices.isEmpty { runs.append(run) }

  let naturalCross =
    runs.reduce(CGFloat.zero) { $0 + $1.crossExtent }
    + runSpacing * CGFloat(max(runs.count - 1, 0))
  let containerCross = availableCrossExtent ?? naturalCross
  let runDistribution = rufletMainAxisDistribution(
    alignment: runAlignment,
    availableExtent: containerCross,
    occupiedExtent: naturalCross,
    childCount: runs.count)
  let resolvedRunSpacing = runSpacing + runDistribution.additionalGap
  var positions = Array(repeating: CGPoint.zero, count: itemSizes.count)
  var crossCursor = runDistribution.edgeInset

  for run in runs {
    let mainDistribution = rufletMainAxisDistribution(
      alignment: alignment,
      availableExtent: availableMainExtent,
      occupiedExtent: run.mainExtent,
      childCount: run.indices.count)
    let resolvedSpacing = spacing + mainDistribution.additionalGap
    var mainCursor = mainDistribution.edgeInset

    for index in run.indices {
      let size = itemSizes[index]
      let itemMain = axis == .horizontal ? size.width : size.height
      let itemCross = axis == .horizontal ? size.height : size.width
      let crossOffset: CGFloat
      switch crossAlignment {
      case .end: crossOffset = run.crossExtent - itemCross
      case .center: crossOffset = (run.crossExtent - itemCross) / 2
      case .start: crossOffset = 0
      }
      positions[index] =
        axis == .horizontal
        ? CGPoint(x: mainCursor, y: crossCursor + crossOffset)
        : CGPoint(x: crossCursor + crossOffset, y: mainCursor)
      mainCursor += itemMain + resolvedSpacing
    }
    crossCursor += run.crossExtent + resolvedRunSpacing
  }

  let usedMain = min(
    availableMainExtent,
    runs.map(\.mainExtent).max() ?? 0)
  return RufletFlowPlan(
    positions: positions,
    contentSize: axis == .horizontal
      ? CGSize(width: usedMain, height: containerCross)
      : CGSize(width: containerCross, height: usedMain))
}

private struct RufletFlowChildSizeKey: PreferenceKey {
  static let defaultValue: [Int: CGSize] = [:]
  static func reduce(value: inout [Int: CGSize], nextValue: () -> [Int: CGSize]) {
    value.merge(nextValue()) { _, latest in latest }
  }
}

private struct RufletFlowContentSizeKey: PreferenceKey {
  static let defaultValue = CGSize.zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
