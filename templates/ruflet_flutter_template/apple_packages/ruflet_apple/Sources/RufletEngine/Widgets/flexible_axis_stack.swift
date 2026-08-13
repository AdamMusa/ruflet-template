import SwiftUI

/// iOS 15/macOS 13-compatible counterpart of Flutter's Expanded/Flexible
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
  let crossAxisStretch: Bool
  let tight: Bool

  @State private var availableMainExtent: CGFloat = 0
  @State private var intrinsicMainExtents: [Int: CGFloat] = [:]

  var body: some View {
    Group {
      if axis == .horizontal {
        HStack(alignment: verticalAlignment, spacing: spacing) {
          stackChildren
        }
        .frame(maxWidth: tight ? nil : .infinity, alignment: frameAlignment)
      } else {
        VStack(alignment: horizontalAlignment, spacing: spacing) {
          stackChildren
        }
        .frame(maxHeight: tight ? nil : .infinity, alignment: frameAlignment)
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
          RufletFlexAllocationModifier(
            axis: axis,
            contract: rufletExpansionContract(for: child),
            allocatedExtent: allocatedExtent(for: child))
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
    guard let expansion = rufletExpansionContract(for: child) else { return nil }
    let flexTotal = children.compactMap { rufletExpansionContract(for: $0)?.flex }.reduce(0, +)
    guard flexTotal > 0, availableMainExtent > 0 else { return nil }
    let fixedExtent =
      children
      .filter { rufletExpansionContract(for: $0) == nil }
      .reduce(CGFloat.zero) { $0 + (intrinsicMainExtents[$1.id] ?? 0) }
    return rufletFlexAllocation(
      availableExtent: availableMainExtent,
      fixedExtent: fixedExtent,
      spacing: spacing,
      childCount: children.count,
      flex: expansion.flex,
      totalFlex: flexTotal)
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

private struct RufletCrossAxisStretchModifier: ViewModifier {
  let axis: Axis
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled, axis == .horizontal {
      content.frame(maxHeight: .infinity)
    } else if enabled {
      content.frame(maxWidth: .infinity)
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
