import SwiftUI

/// Apple-native port of Flet's `GridViewControl`.
@MainActor
public struct GridViewControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      notified(
        AnyView(
          ScrollableControl(
            control: control,
            scrollDirection: horizontal ? .horizontal : .vertical
          ) { grid }))
    }
  }

  private var grid: AnyView {
    let scroll = ScrollView(
      horizontal ? .horizontal : .vertical,
      showsIndicators: showsIndicators
    ) {
      RufletNativeGrid(
        controls: orderedControls,
        horizontal: horizontal,
        runsCount: runsCount,
        maxExtent: maxExtent.map { CGFloat($0) },
        spacing: spacing,
        runSpacing: runSpacing,
        childAspectRatio: childAspectRatio,
        configuration: viewportConfiguration
      )
      .padding(padding)
      .overlay(alignment: .topLeading) { RufletScrollViewportAttachment() }
    }
    .modifier(
      RufletCollectionSemanticsModifier(
        childCount: viewportConfiguration.resolvedSemanticChildCount(
          actualCount: orderedControls.count)))

    if clipBehavior == "none" {
      return AnyView(scroll)
    }
    return AnyView(
      scroll.clipped(
        antialiased: clipBehavior == "antialias"
          || clipBehavior == "antialiaswithsavelayer"))
  }

  private func notified(_ content: AnyView) -> AnyView {
    guard control.boolean("on_scroll", default: false) else { return content }
    return AnyView(ScrollNotificationControl(control: control) { content })
  }

  private var orderedControls: [RufletControl] {
    let controls = control.children("controls")
    return reverse ? Array(controls.reversed()) : controls
  }

  private var viewportConfiguration: RufletCollectionViewportConfiguration {
    RufletCollectionViewportConfiguration(control: control)
  }

  private var horizontal: Bool { control.boolean("horizontal", default: false) }
  private var reverse: Bool { control.boolean("reverse", default: false) }
  private var runsCount: Int { control.integer("runs_count", default: 1) ?? 1 }
  private var maxExtent: Double? { control.number("max_extent") }
  private var spacing: CGFloat { CGFloat(control.number("spacing", default: 10) ?? 10) }
  private var runSpacing: CGFloat {
    CGFloat(control.number("run_spacing", default: 10) ?? 10)
  }
  private var childAspectRatio: CGFloat {
    CGFloat(control.number("child_aspect_ratio", default: 1) ?? 1)
  }
  private var padding: EdgeInsets {
    parsePadding(control.dynamicValue("padding")) ?? EdgeInsets()
  }
  private var clipBehavior: String {
    control.string("clip_behavior", default: "hardEdge")!.lowercased()
  }

  private var showsIndicators: Bool {
    let mode = parseEnum(
      RufletScrollMode.self,
      control.string("scroll"),
      RufletScrollMode.none)!
    return mode != .none && mode != .hidden
  }
}

/// A pure counterpart of Flutter's two `SliverGridDelegate` variants. It is
/// deliberately testable without mounting SwiftUI so the exact run count,
/// child geometry, and cache grouping remain contract assertions.
@MainActor
struct RufletGridPlan: Equatable {
  let trackCount: Int
  let itemCrossExtent: CGFloat
  let itemMainExtent: CGFloat
  let contentMainExtent: CGFloat
  let primaryGroups: [[Int]]
  let cacheGroups: [[[Int]]]

  init(
    itemCount: Int,
    availableCrossExtent: CGFloat,
    runsCount: Int,
    maxExtent: CGFloat?,
    spacing: CGFloat,
    runSpacing: CGFloat,
    childAspectRatio: CGFloat,
    configuration: RufletCollectionViewportConfiguration
  ) {
    let crossExtent = max(availableCrossExtent, 1)
    if let maxExtent, maxExtent > 0 {
      trackCount = max(
        Int(ceil(crossExtent / (maxExtent + runSpacing))),
        1)
    } else {
      trackCount = max(runsCount, 1)
    }
    itemCrossExtent = max(
      (crossExtent - runSpacing * CGFloat(max(trackCount - 1, 0)))
        / CGFloat(trackCount),
      0)
    itemMainExtent = itemCrossExtent / max(childAspectRatio, 0.000_001)
    primaryGroups = Array(0..<itemCount).rufletChunked(count: trackCount)
    contentMainExtent =
      itemMainExtent * CGFloat(primaryGroups.count)
      + spacing * CGFloat(max(primaryGroups.count - 1, 0))
    cacheGroups = primaryGroups.rufletChunked(
      count: configuration.prefetchGroupSize(
        estimatedItemExtent: itemMainExtent + spacing))
  }
}

@MainActor
private struct RufletNativeGrid: View {
  let controls: [RufletControl]
  let horizontal: Bool
  let runsCount: Int
  let maxExtent: CGFloat?
  let spacing: CGFloat
  let runSpacing: CGFloat
  let childAspectRatio: CGFloat
  let configuration: RufletCollectionViewportConfiguration

  @State private var measuredMainExtent = CGFloat.zero

  var body: some View {
    GeometryReader { proxy in
      let crossExtent = horizontal ? proxy.size.height : proxy.size.width
      let plan = RufletGridPlan(
        itemCount: controls.count,
        availableCrossExtent: crossExtent,
        runsCount: runsCount,
        maxExtent: maxExtent,
        spacing: spacing,
        runSpacing: runSpacing,
        childAspectRatio: childAspectRatio,
        configuration: configuration)
      grid(plan)
        .preference(
          key: RufletGridMainExtentKey.self,
          value: plan.contentMainExtent)
    }
    .frame(
      width: horizontal ? measuredMainExtent : nil,
      height: horizontal ? nil : measuredMainExtent
    )
    .onPreferenceChange(RufletGridMainExtentKey.self) {
      measuredMainExtent = $0
    }
  }

  @ViewBuilder
  private func grid(_ plan: RufletGridPlan) -> some View {
    if configuration.buildsOnDemand {
      if horizontal {
        LazyHStack(spacing: spacing) {
          ForEach(Array(plan.cacheGroups.enumerated()), id: \.offset) { _, cacheGroup in
            HStack(spacing: spacing) { primaryGroups(cacheGroup, plan: plan) }
          }
        }
      } else {
        LazyVStack(spacing: spacing) {
          ForEach(Array(plan.cacheGroups.enumerated()), id: \.offset) { _, cacheGroup in
            VStack(spacing: spacing) { primaryGroups(cacheGroup, plan: plan) }
          }
        }
      }
    } else if horizontal {
      HStack(spacing: spacing) { primaryGroups(plan.primaryGroups, plan: plan) }
    } else {
      VStack(spacing: spacing) { primaryGroups(plan.primaryGroups, plan: plan) }
    }
  }

  @ViewBuilder
  private func primaryGroups(_ groups: [[Int]], plan: RufletGridPlan) -> some View {
    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
      if horizontal {
        VStack(spacing: runSpacing) { cells(group, plan: plan) }
          .frame(height: crossExtent(plan), alignment: .top)
      } else {
        HStack(spacing: runSpacing) { cells(group, plan: plan) }
          .frame(width: crossExtent(plan), alignment: .leading)
      }
    }
  }

  @ViewBuilder
  private func cells(_ indices: [Int], plan: RufletGridPlan) -> some View {
    ForEach(indices, id: \.self) { index in
      if controls.indices.contains(index) {
        let child = controls[index]
        ControlWidget(control: child)
          .frame(
            width: horizontal ? plan.itemMainExtent : plan.itemCrossExtent,
            height: horizontal ? plan.itemCrossExtent : plan.itemMainExtent
          )
          .id(child.string("key") ?? String(child.id))
      }
    }
  }

  private func crossExtent(_ plan: RufletGridPlan) -> CGFloat {
    plan.itemCrossExtent * CGFloat(plan.trackCount)
      + runSpacing * CGFloat(max(plan.trackCount - 1, 0))
  }
}

private struct RufletGridMainExtentKey: PreferenceKey {
  static let defaultValue = CGFloat.zero
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
