import RufletProtocol
import SwiftUI

@MainActor
/// Applies the pinned Flet `BaseControl` contract to an extension-owned view.
///
/// Custom `RufletExtension` implementations should wrap non-layout controls
/// with this type so opacity, tooltip, directionality, and base animation
/// behavior stay identical to built-in controls.
public struct BaseControl<Content: View>: View {
  @ObservedObject var control: RufletControl
  let child: Content

  public init(control: RufletControl, @ViewBuilder child: () -> Content) {
    self.control = control
    self.child = child()
  }

  public init(control: RufletControl, child: Content) {
    self.control = control
    self.child = child
  }

  public var body: some View {
    child
      .modifier(RufletBaseControlModifier(control: control))
      .modifier(RufletExpandableModifier(control: control))
  }
}

@MainActor
/// Applies the pinned Flet `LayoutControl` contract to an extension-owned view.
///
/// This is the native Swift counterpart of the wrapper used by Flet extension
/// widgets. It preserves the shared size, transform, alignment, margin, badge,
/// opacity, tooltip, RTL, and animation-event behavior.
public struct LayoutControl<Content: View>: View {
  @ObservedObject var control: RufletControl
  let child: Content

  public init(control: RufletControl, @ViewBuilder child: () -> Content) {
    self.control = control
    self.child = child()
  }

  public init(control: RufletControl, child: Content) {
    self.control = control
    self.child = child
  }

  public var body: some View {
    child
      .modifier(RufletLayoutControlModifier(control: control))
      .modifier(RufletBaseControlModifier(control: control))
      .modifier(RufletExpandableModifier(control: control))
  }
}

@MainActor
private struct RufletBaseControlModifier: ViewModifier {
  @ObservedObject var control: RufletControl

  func body(content: Content) -> some View {
    content
      .opacity(control.number("opacity") ?? 1)
      .animation(
        parseAnimation(control.dynamicValue("animate_opacity"))?.animation,
        value: control.number("opacity") ?? 1
      )
      .modifier(
        RufletTooltipModifier(
          text: control.skipsProperty("tooltip") ? nil : control.string("tooltip"))
      )
      .environment(
        \.layoutDirection, control.boolean("rtl", default: false) ? .rightToLeft : .leftToRight
      )
      .modifier(RufletOpacityCompletionModifier(control: control))
  }
}

@MainActor
private struct RufletLayoutControlModifier: ViewModifier {
  @ObservedObject var control: RufletControl

  func body(content: Content) -> some View {
    let rotation = parseRotationDetails(control.dynamicValue("rotate"))
    let scale = parseScale(control.dynamicValue("scale"))
    let offset = parseOffset(control.dynamicValue("offset"))
    let alignment = parseAlignment(control.dynamicValue("align"))
    let margin = control.skipsProperty("margin") ? nil : parseMargin(control.dynamicValue("margin"))
    let size = rufletSizeContract(for: control)
    let scaleAnimation = parseAnimation(control.dynamicValue("animate_scale"))

    content
      .modifier(RufletConstrainedSizeModifier(size: size))
      .animation(parseAnimation(control.dynamicValue("animate_size"))?.animation, value: size)
      .rotationEffect(
        .radians(rotation?.angle ?? 0),
        anchor: rotation?.alignment.unitPoint ?? .center
      )
      .animation(
        parseAnimation(control.dynamicValue("animate_rotation"))?.animation,
        value: rotation?.angle ?? 0
      )
      .scaleEffect(
        x: scaleAnimation == nil ? (scale?.scaleX ?? scale?.scale ?? 1) : (scale?.scale ?? 1),
        y: scaleAnimation == nil ? (scale?.scaleY ?? scale?.scale ?? 1) : (scale?.scale ?? 1),
        anchor: scale?.alignment.unitPoint ?? .center
      )
      .animation(scaleAnimation?.animation, value: scale?.scale ?? 1)
      .modifier(RufletFractionalOffsetModifier(offset: offset))
      .animation(
        parseAnimation(control.dynamicValue("animate_offset"))?.animation, value: offset ?? .zero
      )
      .modifier(RufletAspectRatioModifier(ratio: control.number("aspect_ratio")))
      .modifier(RufletAlignmentModifier(alignment: alignment))
      .animation(parseAnimation(control.dynamicValue("animate_align"))?.animation, value: alignment)
      .padding(margin ?? EdgeInsets())
      .animation(
        parseAnimation(control.dynamicValue("animate_margin"))?.animation, value: margin?.top ?? 0
      )
      .modifier(RufletPositionedControlModifier(control: control))
      .modifier(RufletBadgeModifier(control: control))
      .modifier(RufletSizeChangeModifier(control: control))
      .modifier(RufletLayoutAnimationCompletionModifier(control: control))
  }
}

struct RufletConstrainedSizeModifier: ViewModifier {
  let size: RufletSizeContract
  var alignment: Alignment = .center
  /// Flutter's `Container` wraps its child in `Align` as soon as `alignment`
  /// is set, and an `Align` without width/height factors expands to fill the
  /// incoming bounded constraints before positioning the child. Without this
  /// the container shrink-wraps and the alignment is unobservable.
  var fillsAvailableSpace = false

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(macOS 13.0, iOS 16.0, *) {
      // Flutter tightens an explicit extent against the constraints supplied
      // by its parent. A 560pt Container is therefore 560pt in an unbounded
      // Row, but becomes the available 353pt inside an iPhone View. SwiftUI's
      // ordinary fixed frame cannot express both cases: setting `minWidth`
      // overflows the phone and omitting it lets an over-subscribed Row crush
      // the child. Read the actual proposal just as RenderBox reads its
      // BoxConstraints and resolve the requested extent against it.
      RufletConstrainedSizeLayout(
        size: size,
        alignment: alignment,
        fillsAvailableSpace: fillsAvailableSpace
      ) {
        content
      }
    } else {
      // On the legacy compatibility path, the Row/Column wrapper uses
      // fixedSize on non-flex children. A clamping frame can therefore honor
      // bounded parents without losing unbounded main-axis extents.
      content.frame(
        idealWidth: size.width,
        maxWidth: size.width ?? (fillsAvailableSpace ? .infinity : nil),
        idealHeight: size.height,
        maxHeight: size.height ?? (fillsAvailableSpace ? .infinity : nil),
        alignment: alignment)
    }
  }
}

@available(macOS 13.0, iOS 16.0, *)
private struct RufletConstrainedSizeLayout: Layout {
  let size: RufletSizeContract
  let alignment: Alignment
  let fillsAvailableSpace: Bool

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    // A Flet Container does not need a child to have geometry: width/height
    // still size its decoration. SwiftUI removes EmptyView from a custom
    // Layout's subviews, so returning zero here made childless colored boxes
    // disappear (and made their implicit size/position animations invisible).
    guard let subview = subviews.first else {
      return CGSize(
        width: rufletConstrainedExtent(
          requested: size.width,
          proposed: proposal.width,
          measured: 0,
          fillsAvailableSpace: fillsAvailableSpace),
        height: rufletConstrainedExtent(
          requested: size.height,
          proposed: proposal.height,
          measured: 0,
          fillsAvailableSpace: fillsAvailableSpace))
    }
    let childProposal = ProposedViewSize(
      width: rufletConstrainedProposal(requested: size.width, proposed: proposal.width),
      height: rufletConstrainedProposal(requested: size.height, proposed: proposal.height))
    let measured = subview.sizeThatFits(childProposal)
    return CGSize(
      width: rufletConstrainedExtent(
        requested: size.width,
        proposed: proposal.width,
        measured: measured.width,
        fillsAvailableSpace: fillsAvailableSpace),
      height: rufletConstrainedExtent(
        requested: size.height,
        proposed: proposal.height,
        measured: measured.height,
        fillsAvailableSpace: fillsAvailableSpace))
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    guard let subview = subviews.first else { return }
    let childProposal = ProposedViewSize(
      width: size.width == nil ? proposal.width : bounds.width,
      height: size.height == nil ? proposal.height : bounds.height)
    let childSize = subview.sizeThatFits(childProposal)
    let freeWidth = max(bounds.width - childSize.width, 0)
    let freeHeight = max(bounds.height - childSize.height, 0)
    let origin = CGPoint(
      x: bounds.minX + freeWidth * alignment.horizontalFactor,
      y: bounds.minY + freeHeight * alignment.verticalFactor)
    subview.place(at: origin, anchor: .topLeading, proposal: childProposal)
  }
}

/// Resolves a Flet explicit extent against the finite maximum supplied by its
/// parent. A nil/infinite proposal represents Flutter's unbounded constraint.
func rufletConstrainedExtent(
  requested: CGFloat?,
  proposed: CGFloat?,
  measured: CGFloat,
  fillsAvailableSpace: Bool
) -> CGFloat {
  if let requested {
    guard let proposed, proposed.isFinite else { return requested }
    return min(requested, max(proposed, 0))
  }
  if fillsAvailableSpace, let proposed, proposed.isFinite {
    return max(proposed, 0)
  }
  return measured
}

private func rufletConstrainedProposal(requested: CGFloat?, proposed: CGFloat?) -> CGFloat? {
  guard let requested else { return proposed }
  guard let proposed, proposed.isFinite else { return requested }
  return min(requested, max(proposed, 0))
}

private extension Alignment {
  var horizontalFactor: CGFloat {
    switch self {
    case .leading, .topLeading, .bottomLeading: return 0
    case .trailing, .topTrailing, .bottomTrailing: return 1
    default: return 0.5
    }
  }

  var verticalFactor: CGFloat {
    switch self {
    case .top, .topLeading, .topTrailing: return 0
    case .bottom, .bottomLeading, .bottomTrailing: return 1
    default: return 0.5
    }
  }
}

struct RufletSizeContract: Equatable {
  let width: CGFloat?
  let height: CGFloat?
}

@MainActor
func rufletSizeContract(for control: RufletControl) -> RufletSizeContract {
  guard !control.skipsProperty("width"), !control.skipsProperty("height") else {
    return RufletSizeContract(width: nil, height: nil)
  }
  return RufletSizeContract(
    width: control.number("width").map { CGFloat($0) },
    height: control.number("height").map { CGFloat($0) })
}

private struct RufletTooltipModifier: ViewModifier {
  let text: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let text {
      #if os(macOS)
        content.help(text)
      #elseif os(iOS)
        content.accessibilityHint(Text(text))
      #endif
    } else {
      content
    }
  }
}

private struct RufletFractionalOffsetModifier: ViewModifier {
  let offset: CGSize?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let offset {
      content.overlay {
        GeometryReader { proxy in
          Color.clear.preference(key: RufletControlSizeKey.self, value: proxy.size)
        }
        .allowsHitTesting(false)
      }
      .modifier(RufletMeasuredOffset(offset: offset))
    } else {
      content
    }
  }
}

enum RufletExpansionAxis: Equatable {
  case horizontal
  case vertical
}

struct RufletExpansionContract: Equatable {
  let flex: Int
  let loose: Bool
  let axis: RufletExpansionAxis
}

@MainActor
func rufletExpansionContract(for control: RufletControl) -> RufletExpansionContract? {
  guard let flex = parseExpand(control.dynamicValue("expand")),
    control.parent?.internals?["host_expanded"]?.bool == true
  else { return nil }

  let axis: RufletExpansionAxis
  switch control.parent?.type.lowercased() {
  case "row": axis = .horizontal
  default: axis = .vertical
  }
  return RufletExpansionContract(
    flex: flex,
    loose: control.boolean("expand_loose", default: false),
    axis: axis)
}

@MainActor
private struct RufletExpandableModifier: ViewModifier {
  @ObservedObject var control: RufletControl

  @ViewBuilder
  func body(content: Content) -> some View {
    if let expansion = rufletExpansionContract(for: control) {
      switch (expansion.axis, expansion.loose) {
      case (.horizontal, false):
        content
          .frame(maxWidth: .infinity)
          .layoutPriority(Double(expansion.flex))
      case (.vertical, false):
        content
          .frame(maxHeight: .infinity)
          .layoutPriority(Double(expansion.flex))
      case (_, true):
        content.layoutPriority(Double(expansion.flex))
      }
    } else {
      content
    }
  }
}

struct RufletPositionContract: Equatable {
  let left: CGFloat?
  let top: CGFloat?
  let right: CGFloat?
  let bottom: CGFloat?
  let animation: ImplicitAnimationDetails?
  let hosted: Bool

  var isPositioned: Bool {
    animation != nil || left != nil || top != nil || right != nil || bottom != nil
  }

  var resolvedLeft: CGFloat? {
    animation != nil && left == nil && top == nil && right == nil && bottom == nil ? 0 : left
  }

  var resolvedTop: CGFloat? {
    animation != nil && left == nil && top == nil && right == nil && bottom == nil ? 0 : top
  }

  var signature: String {
    [resolvedLeft, resolvedTop, right, bottom]
      .map { $0.map(String.init(describing:)) ?? "nil" }
      .joined(separator: ":")
  }
}

@MainActor
func rufletPositionContract(for control: RufletControl) -> RufletPositionContract {
  RufletPositionContract(
    left: control.number("left").map { CGFloat($0) },
    top: control.number("top").map { CGFloat($0) },
    right: control.number("right").map { CGFloat($0) },
    bottom: control.number("bottom").map { CGFloat($0) },
    animation: parseAnimation(control.dynamicValue("animate_position")),
    hosted: control.parent?.internals?["host_positioned"]?.bool == true)
}

@MainActor
private struct RufletPositionedControlModifier: ViewModifier {
  @ObservedObject var control: RufletControl

  @ViewBuilder
  func body(content: Content) -> some View {
    let position = rufletPositionContract(for: control)
    if position.isPositioned, !position.hosted {
      ErrorControl(
        "Error displaying \(control.type)",
        description:
          "Control can be positioned absolutely with \"left\", \"top\", \"right\" and \"bottom\" properties inside Stack control only and page.overlay."
      )
    } else if position.isPositioned {
      GeometryReader { proxy in
        positioned(content, contract: position, containerSize: proxy.size)
      }
      .animation(position.animation?.animation, value: position.signature)
      .modifier(RufletPositionCompletionModifier(control: control, contract: position))
    } else {
      content
    }
  }

  private func alignment(_ position: RufletPositionContract) -> Alignment {
    let horizontal: HorizontalAlignment =
      position.right != nil && position.resolvedLeft == nil ? .trailing : .leading
    let vertical: VerticalAlignment =
      position.bottom != nil && position.resolvedTop == nil ? .bottom : .top
    return Alignment(horizontal: horizontal, vertical: vertical)
  }

  private func positioned(
    _ content: Content,
    contract position: RufletPositionContract,
    containerSize: CGSize
  ) -> some View {
    let width = positionedExtent(
      total: containerSize.width,
      leading: position.resolvedLeft,
      trailing: position.right)
    let height = positionedExtent(
      total: containerSize.height,
      leading: position.resolvedTop,
      trailing: position.bottom)
    let x = position.resolvedLeft ?? -(position.right ?? 0)
    let y = position.resolvedTop ?? -(position.bottom ?? 0)

    return
      content
      .frame(width: width, height: height)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(position))
      .offset(x: x, y: y)
  }

  private func positionedExtent(
    total: CGFloat,
    leading: CGFloat?,
    trailing: CGFloat?
  ) -> CGFloat? {
    guard let leading, let trailing else { return nil }
    return max(total - leading - trailing, 0)
  }
}

@MainActor
private struct RufletPositionCompletionModifier: ViewModifier {
  @ObservedObject var control: RufletControl
  let contract: RufletPositionContract
  @State private var task: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .onChange(of: contract.signature) { _ in schedule() }
      .onDisappear { task?.cancel() }
  }

  private func schedule() {
    guard let animation = contract.animation else { return }
    task?.cancel()
    task = Task { @MainActor in
      try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(animation.duration))
      guard !Task.isCancelled else { return }
      control.triggerEvent("animation_end", data: .string("position"))
    }
  }
}

private struct RufletMeasuredOffset: ViewModifier {
  let offset: CGSize
  @State private var size: CGSize = .zero

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(RufletControlSizeKey.self) { size = $0 }
      .offset(x: size.width * offset.width, y: size.height * offset.height)
  }
}

/// Flet only wraps a control in `AspectRatio` when `aspect_ratio` is set.
/// SwiftUI's `aspectRatio(nil, contentMode:)` is not a no-op — it adopts the
/// child's own ideal aspect ratio and fits the child inside the proposal, which
/// silently shrinks every control and collapses expanding frames.
private struct RufletAspectRatioModifier: ViewModifier {
  let ratio: Double?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let ratio, ratio > 0 {
      content.aspectRatio(CGFloat(ratio), contentMode: .fit)
    } else {
      content
    }
  }
}

private struct RufletAlignmentModifier: ViewModifier {
  let alignment: RufletAlignment?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let alignment {
      content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.swiftUI)
    } else {
      content
    }
  }
}

@MainActor
private struct RufletBadgeModifier: ViewModifier {
  @ObservedObject var control: RufletControl

  @ViewBuilder
  func body(content: Content) -> some View {
    if !control.skipsProperty("badge"), let badge = control.child("badge", visibleOnly: false) {
      content.overlay(
        alignment: parseAlignment(badge.dynamicValue("alignment"), RufletAlignment(x: 1, y: -1))!
          .swiftUI
      ) {
        if badge.boolean("label_visible", default: true) {
          if let label = badge.buildTextOrWidget("label") {
            label
              .foregroundStyle(parseColor(badge.string("text_color")) ?? .white)
              .padding(
                parsePadding(badge.dynamicValue("padding"))
                  ?? RufletLayoutDefaults.badge
              )
              .background(parseColor(badge.string("bgcolor")) ?? .red, in: Capsule())
              .offset(
                x: parseOffset(badge.dynamicValue("offset"))?.width ?? 0,
                y: parseOffset(badge.dynamicValue("offset"))?.height ?? 0
              )
          }
        }
      }
    } else if !control.skipsProperty("badge"), let badge = control.string("badge") {
      content.overlay(alignment: .topTrailing) {
        Text(badge)
          .font(.caption2)
          .foregroundStyle(.white)
          .padding(RufletLayoutDefaults.badge)
          .background(.red, in: Capsule())
      }
    } else {
      content
    }
  }
}

@MainActor
private struct RufletSizeChangeModifier: ViewModifier {
  @ObservedObject var control: RufletControl
  @State private var lastSize: CGSize?
  @State private var pendingTask: Task<Void, Never>?
  @State private var lastDispatch = ProcessInfo.processInfo.systemUptime

  func body(content: Content) -> some View {
    content
      .background {
        if control.boolean("on_size_change", default: false) {
          GeometryReader { proxy in
            Color.clear.preference(key: RufletReportedSizeKey.self, value: proxy.size)
          }
        }
      }
      .onPreferenceChange(RufletReportedSizeKey.self, perform: sizeChanged)
      .onDisappear { pendingTask?.cancel() }
  }

  private func sizeChanged(_ size: CGSize) {
    guard control.boolean("on_size_change", default: false), lastSize != size else { return }
    let interval = Double(control.integer("size_change_interval", default: 10) ?? 10) / 1_000
    let elapsed = ProcessInfo.processInfo.systemUptime - lastDispatch
    pendingTask?.cancel()
    if lastSize != nil, elapsed < interval {
      pendingTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(interval - elapsed))
        guard !Task.isCancelled else { return }
        dispatch(size)
      }
    } else {
      dispatch(size)
    }
  }

  private func dispatch(_ size: CGSize) {
    lastSize = size
    lastDispatch = ProcessInfo.processInfo.systemUptime
    control.triggerEvent(
      "size_change", data: ["w": .double(size.width), "h": .double(size.height)])
  }
}

private struct RufletControlSizeKey: PreferenceKey {
  static let defaultValue = CGSize.zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct RufletReportedSizeKey: PreferenceKey {
  static let defaultValue = CGSize.zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

@MainActor
private struct RufletOpacityCompletionModifier: ViewModifier {
  @ObservedObject var control: RufletControl
  @State private var task: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .onChange(of: control.number("opacity") ?? 1) { _ in
        schedule("opacity", property: "animate_opacity")
      }
      .onDisappear { task?.cancel() }
  }

  private func schedule(_ name: String, property: String) {
    guard control.boolean("on_animation_end", default: false),
      let animation = parseAnimation(control.dynamicValue(property))
    else { return }
    task?.cancel()
    task = Task { @MainActor in
      try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(animation.duration))
      guard !Task.isCancelled else { return }
      control.triggerEvent("animation_end", data: .string(name))
    }
  }
}

@MainActor
private struct RufletLayoutAnimationCompletionModifier: ViewModifier {
  @ObservedObject var control: RufletControl
  @State private var tasks: [String: Task<Void, Never>] = [:]

  @ViewBuilder
  func body(content: Content) -> some View {
    // Each of these five observers materializes a wire value and renders it
    // through `String(describing:)` on every body evaluation of every layout
    // control in the tree. `schedule` already refuses to fire without an
    // `animation_end` subscriber, so the work is dead weight until then.
    if control.boolean("on_animation_end", default: false) {
      observed(content)
    } else {
      content
    }
  }

  private func observed(_ content: Content) -> some View {
    content
      .onChange(of: control.dynamicValue("rotate").map(String.init(describing:)) ?? "") { _ in
        schedule("rotation", "animate_rotation")
      }
      .onChange(of: control.dynamicValue("scale").map(String.init(describing:)) ?? "") { _ in
        schedule("scale", "animate_scale")
      }
      .onChange(of: control.dynamicValue("offset").map(String.init(describing:)) ?? "") { _ in
        schedule("offset", "animate_offset")
      }
      .onChange(of: control.dynamicValue("align").map(String.init(describing:)) ?? "") { _ in
        schedule("align", "animate_align")
      }
      .onChange(of: control.dynamicValue("margin").map(String.init(describing:)) ?? "") { _ in
        schedule("margin", "animate_margin")
      }
      .onDisappear {
        for task in tasks.values {
          task.cancel()
        }
        tasks.removeAll()
      }
  }

  private func schedule(_ name: String, _ property: String) {
    guard control.boolean("on_animation_end", default: false),
      let animation = parseAnimation(control.dynamicValue(property))
    else { return }
    tasks[name]?.cancel()
    tasks[name] = Task { @MainActor in
      try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(animation.duration))
      guard !Task.isCancelled else { return }
      control.triggerEvent("animation_end", data: .string(name))
    }
  }
}
