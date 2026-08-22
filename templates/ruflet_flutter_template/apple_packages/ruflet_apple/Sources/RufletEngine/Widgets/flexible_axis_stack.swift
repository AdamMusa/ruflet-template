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
            .modifier(
              RufletCrossAxisStretchModifier(
                axis: axis,
                enabled: crossAxisStretch,
                horizontalPaintAlignment: rufletStretchedHorizontalPaintAlignment(for: child))
            )
            .layoutValue(
              key: RufletFlexParentDataKey.self,
              value: fixedMainExtents[child.id] == nil
                ? rufletExpansionContract(for: child) : nil
            )
            .layoutValue(
              key: RufletFlexCrossAxisSizingKey.self,
              value: rufletFlexCrossAxisSizing(for: child, in: axis))
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
        .modifier(
          RufletCrossAxisStretchModifier(
            axis: axis,
            enabled: crossAxisStretch,
            horizontalPaintAlignment: rufletStretchedHorizontalPaintAlignment(for: child))
        )
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

/// Resolves the controls whose Flutter render objects consume a bounded loose
/// cross-axis constraint. Wrapper controls inherit the behavior of their
/// content, so this remains protocol-driven even through Container/Card/etc.
@MainActor
func rufletFlexCrossAxisSizing(
  for control: RufletControl,
  in axis: Axis
) -> RufletFlexCrossAxisSizing {
  rufletFlexCrossAxisSizing(for: control, in: axis, visited: [])
}

@MainActor
private func rufletFlexCrossAxisSizing(
  for control: RufletControl,
  in axis: Axis,
  visited: Set<Int>
) -> RufletFlexCrossAxisSizing {
  guard !visited.contains(control.id) else { return .intrinsic }
  var visited = visited
  visited.insert(control.id)

  let type = control.type.replacingOccurrences(of: "_", with: "").lowercased()
  switch (axis, type) {
  case (.vertical, "row") where !control.boolean("tight", default: false):
    return .bounded
  case (.horizontal, "column") where !control.boolean("tight", default: false):
    return .bounded
  case (.vertical, "column")
  where control.string("horizontal_alignment")?.lowercased() == "stretch":
    // Flutter passes every non-flex Column child a finite loose width. A
    // nested Column that explicitly requests CrossAxisAlignment.stretch then
    // consumes that maximum. Measuring it with an unspecified SwiftUI width
    // instead shrinks the complete subtree to an arbitrary intrinsic child.
    return .bounded
  case (.horizontal, "row")
  where control.string("vertical_alignment")?.lowercased() == "stretch":
    return .bounded
  default:
    break
  }

  switch type {
  case "listtile", "cupertinolisttile":
    return .bounded
  case "slider", "adaptiveslider", "cupertinoslider", "rangeslider":
    // Flutter sliders consume the finite loose width supplied by a Column.
    // Measuring their UIKit bridge with an unspecified width collapses the
    // native track to zero and leaves only the thumb visible and hittable.
    return axis == .vertical ? .bounded : .intrinsic
  case "textfield", "cupertinotextfield", "dropdown", "dropdownm2":
    return (parseExpand(control.dynamicValue("expand"), 0) ?? 0) > 0
      ? .bounded : .intrinsic
  case "container":
    if control.value("alignment") != nil { return .bounded }
    guard axis == .vertical ? control.number("width") == nil : control.number("height") == nil,
      let child = control.child("content", visibleOnly: false)?.unwrapComponent()
    else { return .intrinsic }
    return rufletFlexCrossAxisSizing(for: child, in: axis, visited: visited)
  case "card", "gesture_detector", "semantics", "selection_area", "safe_area",
    "transparent_pointer", "shader_mask", "hero", "dismissible", "screenshot":
    guard let child = control.child("content", visibleOnly: false)?.unwrapComponent() else {
      return .intrinsic
    }
    return rufletFlexCrossAxisSizing(for: child, in: axis, visited: visited)
  default:
    return .intrinsic
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
  let horizontalPaintAlignment: RufletStretchedHorizontalPaintAlignment

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
        .frame(maxWidth: .infinity, alignment: horizontalPaintAlignment.swiftUI)
    } else {
      content
    }
  }
}

enum RufletStretchedHorizontalPaintAlignment: Equatable {
  case leading
  case center
  case trailing

  var swiftUI: Alignment {
    switch self {
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    }
  }
}

/// Flutter gives a child of a `Column(crossAxisAlignment: stretch)` a tight
/// width. The child's own renderer then decides where its pixels live inside
/// that width: `Text.textAlign` positions text, while `Icon` centers its glyph.
/// A SwiftUI `frame(maxWidth:)` must be told that paint alignment explicitly;
/// using `.leading` for every control discarded those Flet semantics even
/// though the wire properties arrived intact.
@MainActor
func rufletStretchedHorizontalPaintAlignment(
  for control: RufletControl
) -> RufletStretchedHorizontalPaintAlignment {
  switch control.type.lowercased() {
  case "text":
    switch control.string("text_align")?.lowercased() {
    case "center": return .center
    case "end", "right": return .trailing
    default: return .leading
    }
  case "icon":
    return .center
  default:
    return .leading
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
