import SwiftUI

private struct RufletCrossAxisStretchAxisKey: EnvironmentKey {
  static let defaultValue: Axis? = nil
}

extension EnvironmentValues {
  var rufletCrossAxisStretchAxis: Axis? {
    get { self[RufletCrossAxisStretchAxisKey.self] }
    set { self[RufletCrossAxisStretchAxisKey.self] = newValue }
  }
}

/// iOS 16/macOS 13-compatible counterpart of Flutter's Expanded/Flexible
/// parent-data layout. SwiftUI's ordinary `layoutPriority` does not divide
/// remaining space by flex factors, so the hosting Row/Column/View measures its
/// fixed children and assigns the exact remainder proportionally.
@MainActor
struct RufletFlexibleAxisStack: View {
  let axis: Axis
  let children: [RufletControl]
  let spacing: CGFloat
  let horizontalAlignment: HorizontalAlignment
  let verticalAlignment: VerticalAlignment
  let frameAlignment: Alignment
  let mainAxisAlignment: RufletMainAxisAlignment
  let crossAxisStretch: Bool
  let tight: Bool
  var fixedMainExtents: [Int: CGFloat] = [:]

  @State private var availableMainExtent: CGFloat = 0
  @State private var intrinsicMainExtents: [Int: CGFloat] = [:]

  @ViewBuilder
  var body: some View {
    if #available(macOS 13.0, iOS 16.0, *) {
      // Single-pass RenderFlex port: no GeometryReader, no PreferenceKey and
      // no @State feedback, so SwiftUI settles the stack in one layout pass
      // instead of converging over several.
      RufletFlexLayout(
        axis: axis,
        spacing: spacing,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisStretch: crossAxisStretch,
        crossAxisAlignment: resolvedCrossAlignment,
        tight: tight
      ) {
        ForEach(children, id: \.id) { child in
          ControlWidget(control: child)
            // CrossAxisAlignment.stretch gives every child a tight cross-axis
            // constraint. The legacy stack already applied this frame; the
            // single-pass Layout path must do the same so intrinsic Text/Icon
            // children occupy the full Row/Column cross extent.
            .modifier(RufletCrossAxisStretchModifier(axis: axis, enabled: crossAxisStretch))
            .layoutValue(
              key: RufletFlexParentDataKey.self,
              value: fixedMainExtents[child.id] == nil
                ? rufletExpansionContract(for: child) : nil)
        }
      }
    } else {
      legacyBody
    }
  }

  private var resolvedCrossAlignment: RufletFlexCrossAlignment {
    if axis == .horizontal {
      switch verticalAlignment {
      case .top: return .start
      case .bottom: return .end
      default: return .center
      }
    }
    switch horizontalAlignment {
    case .trailing: return .end
    case .center: return .center
    default: return .start
    }
  }

  private var legacyBody: some View {
    Group {
      if axis == .horizontal {
        HStack(alignment: verticalAlignment, spacing: resolvedSpacing) {
          stackChildren
        }
        .padding(.horizontal, mainAxisInset)
        .frame(maxWidth: tight ? nil : .infinity, alignment: resolvedFrameAlignment)
      } else {
        VStack(alignment: horizontalAlignment, spacing: resolvedSpacing) {
          stackChildren
        }
        .padding(.vertical, mainAxisInset)
        .frame(maxHeight: tight ? nil : .infinity, alignment: resolvedFrameAlignment)
      }
    }
    .background {
      GeometryReader { proxy in
        Color.clear.preference(
          key: RufletFlexContainerExtentKey.self,
          value: axis == .horizontal ? proxy.size.width : proxy.size.height)
      }
    }
    .onPreferenceChange(RufletFlexContainerExtentKey.self) { availableMainExtent = $0 }
    .onPreferenceChange(RufletFlexChildExtentKey.self) { extents in
      intrinsicMainExtents.merge(extents) { _, latest in latest }
    }
  }

  @ViewBuilder
  private var stackChildren: some View {
    ForEach(children, id: \.id) { child in
      ControlWidget(control: child)
        .modifier(RufletCrossAxisStretchModifier(axis: axis, enabled: crossAxisStretch))
        .modifier(
          RufletIntrinsicMainAxisModifier(
            axis: axis,
            enabled: rufletExpansionContract(for: child) == nil
              && fixedMainExtents[child.id] == nil)
        )
        .modifier(
          RufletFlexAllocationModifier(
            axis: axis,
            contract: rufletExpansionContract(for: child),
            allocatedExtent: fixedMainExtents[child.id] ?? allocatedExtent(for: child))
        )
        .background {
          if rufletExpansionContract(for: child) == nil {
            GeometryReader { proxy in
              Color.clear.preference(
                key: RufletFlexChildExtentKey.self,
                value: [child.id: axis == .horizontal ? proxy.size.width : proxy.size.height])
            }
          }
        }
    }
  }

  private func allocatedExtent(for child: RufletControl) -> CGFloat? {
    if let fixed = fixedMainExtents[child.id] { return fixed }
    guard let expansion = rufletExpansionContract(for: child) else { return nil }
    let flexTotal =
      children
      .filter { fixedMainExtents[$0.id] == nil }
      .compactMap { rufletExpansionContract(for: $0)?.flex }
      .reduce(0, +)
    guard flexTotal > 0, availableMainExtent > 0 else { return nil }
    let fixedExtent =
      children
      .filter {
        fixedMainExtents[$0.id] != nil || rufletExpansionContract(for: $0) == nil
      }
      .reduce(CGFloat.zero) {
        $0 + (fixedMainExtents[$1.id] ?? intrinsicMainExtents[$1.id] ?? 0)
      }
    return rufletFlexAllocation(
      availableExtent: availableMainExtent,
      fixedExtent: fixedExtent,
      spacing: spacing,
      childCount: children.count,
      flex: expansion.flex,
      totalFlex: flexTotal)
  }

  private var resolvedSpacing: CGFloat {
    guard !tight else { return spacing }
    let distribution = rufletMainAxisDistribution(
      alignment: mainAxisAlignment,
      availableExtent: availableMainExtent,
      occupiedExtent: occupiedMainExtent,
      childCount: children.count)
    return spacing + distribution.additionalGap
  }

  private var mainAxisInset: CGFloat {
    guard !tight else { return 0 }
    switch mainAxisAlignment {
    case .spaceAround, .spaceEvenly:
      return rufletMainAxisDistribution(
        alignment: mainAxisAlignment,
        availableExtent: availableMainExtent,
        occupiedExtent: occupiedMainExtent,
        childCount: children.count
      ).edgeInset
    default:
      // Start/end/center are supplied by the containing frame rather than
      // symmetric padding. SpaceBetween has no edge inset.
      return 0
    }
  }

  private var occupiedMainExtent: CGFloat {
    let fixedExtent =
      children
      .filter {
        fixedMainExtents[$0.id] != nil || rufletExpansionContract(for: $0) == nil
      }
      .reduce(CGFloat.zero) {
        $0 + (fixedMainExtents[$1.id] ?? intrinsicMainExtents[$1.id] ?? 0)
      }
    let flexExtent =
      children
      .filter { fixedMainExtents[$0.id] == nil }
      .compactMap { allocatedExtent(for: $0) }
      .reduce(0, +)
    let gaps = spacing * CGFloat(max(children.count - 1, 0))
    return fixedExtent + flexExtent + gaps
  }

  private var resolvedFrameAlignment: Alignment {
    switch mainAxisAlignment {
    case .end:
      return axis == .horizontal ? .trailing : .bottom
    case .center:
      return .center
    default:
      return frameAlignment
    }
  }
}

struct RufletMainAxisDistribution: Equatable {
  let edgeInset: CGFloat
  let additionalGap: CGFloat
}

/// Pure counterpart of Flutter's MainAxisAlignment free-space distribution.
/// The Row/Column `spacing` value is already included in `occupiedExtent`;
/// this result describes only the remaining alignment space.
func rufletMainAxisDistribution(
  alignment: RufletMainAxisAlignment,
  availableExtent: CGFloat,
  occupiedExtent: CGFloat,
  childCount: Int
) -> RufletMainAxisDistribution {
  guard availableExtent > 0, childCount > 0 else {
    return RufletMainAxisDistribution(edgeInset: 0, additionalGap: 0)
  }
  let free = max(availableExtent - occupiedExtent, 0)
  switch alignment {
  case .end:
    return RufletMainAxisDistribution(edgeInset: free, additionalGap: 0)
  case .center:
    return RufletMainAxisDistribution(edgeInset: free / 2, additionalGap: 0)
  case .spaceBetween where childCount > 1:
    return RufletMainAxisDistribution(
      edgeInset: 0, additionalGap: free / CGFloat(childCount - 1))
  case .spaceAround:
    let gap = free / CGFloat(childCount)
    return RufletMainAxisDistribution(edgeInset: gap / 2, additionalGap: gap)
  case .spaceEvenly:
    let gap = free / CGFloat(childCount + 1)
    return RufletMainAxisDistribution(edgeInset: gap, additionalGap: gap)
  default:
    return RufletMainAxisDistribution(edgeInset: 0, additionalGap: 0)
  }
}

/// Pure form of Flutter's Flex remaining-space allocation, shared by the
/// native Row/Column/View host and its contract tests.
func rufletFlexAllocation(
  availableExtent: CGFloat,
  fixedExtent: CGFloat,
  spacing: CGFloat,
  childCount: Int,
  flex: Int,
  totalFlex: Int
) -> CGFloat? {
  guard availableExtent > 0, flex > 0, totalFlex > 0 else { return nil }
  let gaps = spacing * CGFloat(max(childCount - 1, 0))
  let remaining = max(availableExtent - fixedExtent - gaps, 0)
  return remaining * CGFloat(flex) / CGFloat(totalFlex)
}

/// Flutter's `RenderFlex` lays a non-flex child out with **no maximum** on the
/// main axis (`BoxConstraints(maxHeight: ...)` for a horizontal flex), so the
/// child takes its intrinsic extent and the row overflows when it does not fit.
/// A SwiftUI stack instead compresses its children, and `Text` is the most
/// compressible thing in the row — so labels beside an icon are squeezed to
/// nothing while the icon keeps its size. That is why "Run", "Files" and
/// "Read-only preview" vanished while their icons stayed.
private struct RufletIntrinsicMainAxisModifier: ViewModifier {
  let axis: Axis
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.fixedSize(horizontal: axis == .horizontal, vertical: axis == .vertical)
    } else {
      content
    }
  }
}

private struct RufletCrossAxisStretchModifier: ViewModifier {
  let axis: Axis
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled, axis == .horizontal {
      // Flutter gives a stretched child a tight cross-axis constraint without
      // changing where that child's contents paint inside the new box.
      // SwiftUI's frame defaults to centered content, which made a stretched
      // Column center Text and other intrinsic children unexpectedly.
      content
        .environment(\.rufletCrossAxisStretchAxis, axis)
        .frame(maxHeight: .infinity, alignment: .top)
    } else if enabled {
      content
        .environment(\.rufletCrossAxisStretchAxis, axis)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      content
    }
  }
}

private struct RufletFlexAllocationModifier: ViewModifier {
  let axis: Axis
  let contract: RufletExpansionContract?
  let allocatedExtent: CGFloat?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let contract, let allocatedExtent {
      if axis == .horizontal {
        if contract.loose {
          content.frame(maxWidth: allocatedExtent)
        } else {
          content.frame(width: allocatedExtent)
        }
      } else if contract.loose {
        content.frame(maxHeight: allocatedExtent)
      } else {
        content.frame(height: allocatedExtent)
      }
    } else {
      content
    }
  }
}

private struct RufletFlexContainerExtentKey: PreferenceKey {
  static let defaultValue = CGFloat.zero
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct RufletFlexChildExtentKey: PreferenceKey {
  static let defaultValue: [Int: CGFloat] = [:]
  static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
    value.merge(nextValue()) { _, latest in latest }
  }
}
