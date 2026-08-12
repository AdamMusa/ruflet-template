import RufletEngine
import RufletProtocol
import SwiftUI
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

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
    let main = ControlProps.MainAxisAlignment(node.rufletString("alignment"))
    // Flutter/Flet Row defaults to a centred cross axis. Using `.start` here
    // top-aligned every icon/text pair whose Ruby omitted the property.
    let cross = ControlProps.CrossAxisAlignment(
      node.rufletString("vertical_alignment"), default: .center)
    let spacing = CGFloat(node.rufletDouble("spacing"))
    let children = node.childIDs
    let tight = node.rufletBool("tight")

    Group {
      if node.bool("wrap") == true {
        WrappingStack(
          ids: children, spacing: spacing,
          runSpacing: CGFloat(node.rufletDouble("run_spacing")),
          alignment: main,
          runAlignment: ControlProps.MainAxisAlignment(node.rufletString("run_alignment")),
          crossAlignment: RufletWrapMath.crossAlignment(
            node.string("vertical_alignment"), default: .center))
      } else if hasFlexChildren, #available(iOS 16.0, macOS 13.0, *) {
        RufletFlexLayout(
          axis: .horizontal, spacing: spacing, mainAlignment: main,
          crossAlignment: cross, tight: tight
        ) {
          ForEach(children, id: \.self) { id in
            RufletFlexChild(id: id, axis: .horizontal)
          }
        }
      } else {
        HStack(alignment: cross.vertical, spacing: main.usesSpacers && !tight ? 0 : spacing) {
          DistributedChildren(
            ids: children, alignment: main, axis: .horizontal,
            spacing: spacing, tight: tight)
        }
      }
    }
    // `intrinsic_height` sizes the row to its tallest child rather than to
    // the space it was offered.
    .fixedSize(horizontal: false, vertical: node.rufletBool("intrinsic_height"))
    .modifier(ScrollableStack(
      node: node, axis: node.rufletBool("wrap") ? .vertical : .horizontal))
  }

  private var hasFlexChildren: Bool {
    node.childIDs.contains { id in
      guard let child = store.node(id) else { return false }
      return RufletFlexMath.flex(child.props["expand"]) > 0
    }
  }
}

/// `Column` — a vertical stack. `alignment` is the vertical axis here and
/// `horizontal_alignment` the cross axis.
struct ColumnControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  @ViewBuilder
  var body: some View {
    let main = ControlProps.MainAxisAlignment(node.rufletString("alignment"))
    let cross = ControlProps.CrossAxisAlignment(node.rufletString("horizontal_alignment"))
    let spacing = CGFloat(node.rufletDouble("spacing"))
    let tight = node.rufletBool("tight")

    Group {
      if node.rufletBool("wrap") {
        // A wrapping Column is Flutter's Wrap: children run down a column and
        // start a new one when the run is full, spaced by run_spacing and
        // placed by run_alignment.
        FlowLayout(
          axis: .vertical,
          spacing: spacing,
          runSpacing: CGFloat(node.rufletDouble("run_spacing")),
          alignment: main,
          runAlignment: ControlProps.MainAxisAlignment(node.rufletString("run_alignment")),
          crossAlignment: RufletWrapMath.crossAlignment(
            node.string("horizontal_alignment"), default: .start)
        ) {
          ForEach(node.childIDs, id: \.self) { id in
            ControlView(id: id, axis: .none)
          }
        }
      } else if hasFlexChildren, #available(iOS 16.0, macOS 13.0, *) {
        RufletFlexLayout(
          axis: .vertical, spacing: spacing, mainAlignment: main,
          crossAlignment: cross, tight: tight
        ) {
          ForEach(node.childIDs, id: \.self) { id in
            RufletFlexChild(id: id, axis: .vertical)
          }
        }
      } else {
        VStack(alignment: cross.horizontal, spacing: main.usesSpacers && !tight ? 0 : spacing) {
          DistributedChildren(
            ids: node.childIDs, alignment: main, axis: .vertical,
            spacing: spacing, tight: tight)
        }
      }
    }
    .modifier(CrossStretch(alignment: cross, axis: .vertical))
    // `intrinsic_width` sizes the column to its widest child rather than to
    // the space it was offered.
    .fixedSize(horizontal: node.rufletBool("intrinsic_width"), vertical: false)
    .modifier(ScrollableStack(
      node: node, axis: node.rufletBool("wrap") ? .horizontal : .vertical))
  }

  private var hasFlexChildren: Bool {
    node.childIDs.contains { id in
      guard let child = store.node(id) else { return false }
      return RufletFlexMath.flex(child.props["expand"]) > 0
    }
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

struct RufletPageScrollCommand: Equatable {
  let targetID: Int
  let offset: Double?
  let delta: Double?
  let scrollKey: RufletValue?
  let duration: Double
  let curve: String
  let token: String

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue,
      let targetID = map["target_id"]?.intValue,
      let token = map["token"]?.stringValue
    else { return nil }
    self.targetID = targetID
    offset = map["offset"]?.doubleValue
    delta = map["delta"]?.doubleValue
    scrollKey = map["scroll_key"].flatMap { $0.isNull ? nil : $0 }
    duration = map["duration"]?.doubleValue ?? 0
    curve = map["curve"]?.stringValue ?? "ease"
    self.token = token
  }
}

private struct RufletPageScrollCommandKey: EnvironmentKey {
  static let defaultValue: RufletPageScrollCommand? = nil
}

extension EnvironmentValues {
  var rufletPageScrollCommand: RufletPageScrollCommand? {
    get { self[RufletPageScrollCommandKey.self] }
    set { self[RufletPageScrollCommandKey.self] = newValue }
  }
}

@MainActor
private final class RufletNativeScrollDriver: ObservableObject {
  #if canImport(UIKit)
    weak var scrollView: UIScrollView?

    func move(offset: Double?, delta: Double?, duration: Double, curve: String, axis: Axis.Set) {
      guard let scrollView else { return }
      let current = axis == .horizontal ? scrollView.contentOffset.x : scrollView.contentOffset.y
      let maximum = axis == .horizontal
        ? max(0, scrollView.contentSize.width - scrollView.bounds.width)
        : max(0, scrollView.contentSize.height - scrollView.bounds.height)
      var target = offset.map { CGFloat($0) } ?? current + CGFloat(delta ?? 0)
      if let offset, offset < 0 { target = maximum + CGFloat(offset) + 1 }
      target = min(max(0, target), maximum)
      var point = scrollView.contentOffset
      if axis == .horizontal { point.x = target } else { point.y = target }
      guard duration >= 1 else {
        scrollView.setContentOffset(point, animated: false)
        return
      }
      UIView.animate(
        withDuration: duration / 1_000,
        delay: 0,
        options: animationOptions(curve),
        animations: { scrollView.contentOffset = point })
    }

    private func animationOptions(_ curve: String) -> UIView.AnimationOptions {
      switch curve.lowercased() {
      case "linear": return .curveLinear
      case "ease_in", "easein": return .curveEaseIn
      case "ease_out", "easeout": return .curveEaseOut
      default: return .curveEaseInOut
      }
    }
  #elseif canImport(AppKit)
    weak var scrollView: NSScrollView?

    func move(offset: Double?, delta: Double?, duration: Double, curve _: String, axis: Axis.Set) {
      guard let scrollView else { return }
      let clip = scrollView.contentView
      let current = axis == .horizontal ? clip.bounds.origin.x : clip.bounds.origin.y
      let documentSize = scrollView.documentView?.bounds.size ?? .zero
      let maximum = axis == .horizontal
        ? max(0, documentSize.width - clip.bounds.width)
        : max(0, documentSize.height - clip.bounds.height)
      var target = offset.map { CGFloat($0) } ?? current + CGFloat(delta ?? 0)
      if let offset, offset < 0 { target = maximum + CGFloat(offset) + 1 }
      target = min(max(0, target), maximum)
      var point = clip.bounds.origin
      if axis == .horizontal { point.x = target } else { point.y = target }
      guard duration >= 1 else {
        clip.setBoundsOrigin(point)
        scrollView.reflectScrolledClipView(clip)
        return
      }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = duration / 1_000
        clip.animator().setBoundsOrigin(point)
      }
    }
  #endif
}

#if canImport(UIKit)
private struct RufletNativeScrollLocator: UIViewRepresentable {
  @ObservedObject var driver: RufletNativeScrollDriver
  func makeUIView(context: Context) -> UIView { UIView(frame: .zero) }
  func updateUIView(_ view: UIView, context: Context) {
    DispatchQueue.main.async {
      var ancestor = view.superview
      while let candidate = ancestor {
        if let scrollView = candidate as? UIScrollView {
          driver.scrollView = scrollView
          return
        }
        ancestor = candidate.superview
      }
    }
  }
}
#elseif canImport(AppKit)
private struct RufletNativeScrollLocator: NSViewRepresentable {
  @ObservedObject var driver: RufletNativeScrollDriver
  func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }
  func updateNSView(_ view: NSView, context: Context) {
    DispatchQueue.main.async {
      var ancestor = view.superview
      while let candidate = ancestor {
        if let scrollView = candidate as? NSScrollView {
          driver.scrollView = scrollView
          return
        }
        ancestor = candidate.superview
      }
    }
  }
}
#endif

/// Wraps a stack in a `ScrollView` when Ruby set `scroll`.
///
/// Flet accepts `"auto"`, `"always"`, `"adaptive"`, `"hidden"` and `true`; all
/// of them mean "this stack scrolls" on Apple platforms, where the scroll
/// indicator is already adaptive.
struct ScrollableStack: ViewModifier {
  let node: ControlNode
  let axis: Axis.Set
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletPageScrollCommand) private var pageScrollCommand
  @Environment(\.rufletScaffoldHost) private var scaffold
  @EnvironmentObject private var store: ControlStore
  @StateObject private var nativeDriver = RufletNativeScrollDriver()
  @State private var viewportExtent: CGFloat = 0
  @State private var previousPixels: CGFloat = 0
  @State private var lastScrollReports: [String: Date] = [:]
  @State private var hasScrollSample = false
  @State private var scrollEndToken = UUID()
  @State private var isScrolling = false

  func body(content: Content) -> some View {
    if scrolls {
      ScrollViewReader { proxy in
      ScrollView(axis, showsIndicators: node.string("scroll") != "hidden") {
        content
          .background(RufletNativeScrollLocator(driver: nativeDriver))
          .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: StackScrollSampleKey.self,
              value: StackScrollSample(
                pixels: axis == .horizontal
                  ? -proxy.frame(in: .named("ruflet-stack-scroll-\(node.id)")).minX
                  : -proxy.frame(in: .named("ruflet-stack-scroll-\(node.id)")).minY,
                contentExtent: axis == .horizontal ? proxy.size.width : proxy.size.height))
          })
      }
      .coordinateSpace(name: "ruflet-stack-scroll-\(node.id)")
      .background(
        GeometryReader { proxy in
          Color.clear.preference(
            key: StackScrollViewportKey.self,
            value: axis == .horizontal ? proxy.size.width : proxy.size.height)
        })
      .onPreferenceChange(StackScrollViewportKey.self) { viewportExtent = $0 }
      .onPreferenceChange(StackScrollSampleKey.self) { sample in
        // Scaffold/AppBar scroll-under behavior is host state, not an
        // `on_scroll` subscription. Always publish the real body offset.
        scaffold?.reportScroll(sourceID: node.id, offset: max(0, sample.pixels))
        guard node.handlesEvent("scroll") else { return }
        let pixels = max(0, sample.pixels)
        let delta = pixels - previousPixels
        guard hasScrollSample else {
          hasScrollSample = true
          previousPixels = pixels
          return
        }
        guard abs(delta) > 0.001 else { return }
        if !isScrolling {
          isScrolling = true
          reportScroll(type: "start", sample: sample, pixels: pixels)
        }
        reportScroll(type: "update", sample: sample, pixels: pixels, delta: delta)
        previousPixels = pixels
        let token = UUID()
        scrollEndToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
          guard scrollEndToken == token else { return }
          isScrolling = false
          reportScroll(type: "end", sample: sample, pixels: pixels)
        }
      }
      // `auto_scroll` keeps the end in view as children arrive, which is what
      // Flet's auto-scrolling controller does.
      .onChange(of: node.childIDs.count) { _ in
        guard node.bool("auto_scroll") == true, let last = node.childIDs.last else { return }
        withAnimation { proxy.scrollTo(last, anchor: axis == .horizontal ? .trailing : .bottom) }
      }
      .onChange(of: pageScrollCommand) { command in
        guard let command, command.targetID == node.id else { return }
        if let targetID = scrollTargetID(command.scrollKey) {
          let animation = command.duration >= 1
            ? Animation.easeInOut(duration: command.duration / 1_000)
            : nil
          withAnimation(animation) { proxy.scrollTo(targetID) }
        } else {
          nativeDriver.move(
            offset: command.offset,
            delta: command.delta,
            duration: command.duration,
            curve: command.curve,
            axis: axis)
        }
      }
      .onDisappear { scaffold?.removeScrollSource(node.id) }
      }
    } else {
      content
    }
  }

  private var scrolls: Bool {
    guard let value = node.props["scroll"], !value.isNull else { return false }
    if let flag = value.boolValue { return flag }
    guard let mode = value.stringValue?.lowercased() else { return false }
    return ["auto", "adaptive", "always", "hidden"].contains(mode)
  }

  private func scrollTargetID(_ key: RufletValue?) -> Int? {
    guard let key else { return nil }
    if let id = key.intValue, store.node(id) != nil { return id }
    guard let name = key.stringValue else { return nil }
    return store.nodes.values.first(where: { candidate in
      candidate.props["key"]?.stringValue == name
        || candidate.props["key"]?.intValue.map(String.init) == name
    })?.id
  }

  private func reportScroll(
    type: String, sample: StackScrollSample, pixels: CGFloat, delta: CGFloat? = nil
  ) {
    let now = Date()
    let interval = TimeInterval(node.int("scroll_interval") ?? 10) / 1_000
    if let previous = lastScrollReports[type], now.timeIntervalSince(previous) <= interval { return }
    lastScrollReports[type] = now
    var data: [String: RufletValue] = [
      "pixels": .double(Double(pixels)),
      "min_scroll_extent": .double(0),
      "max_scroll_extent": .double(Double(max(0, sample.contentExtent - viewportExtent))),
      "viewport_dimension": .double(Double(viewportExtent)),
      "event_type": .string(type),
    ]
    if let delta { data["scroll_delta"] = .double(Double(delta)) }
    events.fire(node, "scroll", data: .map(data))
  }
}

private struct StackScrollSample: Equatable {
  var pixels: CGFloat = 0
  var contentExtent: CGFloat = 0
}

private struct StackScrollSampleKey: PreferenceKey {
  static var defaultValue = StackScrollSample()
  static func reduce(value: inout StackScrollSample, nextValue: () -> StackScrollSample) {
    value = nextValue()
  }
}

private struct StackScrollViewportKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
    let alignment = ControlProps.continuousAlignment(node.props["alignment"]) ?? .topLeft

    ZStack {
      ForEach(node.childIDs, id: \.self) { childID in
        if let child = store.node(childID), isPositioned(child) {
          PositionedChild(node: child, alignment: alignment)
        } else {
          RufletStackAlignedChild(alignment: alignment, fit: stackFit) {
            ControlView(id: childID, axis: .none)
          }
            // `fit: expand` makes every non-positioned child fill the stack;
            // `passthrough` leaves the constraints alone.
        }
      }
    }
    .modifier(StackClip(behavior: node.rufletString("clip_behavior")))
  }

  private var stackFit: RufletStackFit {
    RufletStackFit(rawValue: node.string("fit")?.lowercased() ?? "loose") ?? .loose
  }

  private func isPositioned(_ child: ControlNode) -> Bool {
    child.props["animate_position"] != nil
      || ["left", "top", "right", "bottom"].contains { child.props[$0]?.doubleValue != nil }
  }
}

private struct StackClip: ViewModifier {
  let behavior: String
  func body(content: Content) -> some View {
    behavior.lowercased() == "none" ? AnyView(content) : AnyView(content.clipped())
  }
}

/// Gives every loose Stack child the Stack's bounds and positions its own
/// intrinsic box with Flutter's continuous Alignment(x, y) formula.
private struct RufletStackAlignedChild<Content: View>: View {
  let alignment: RufletAlignment
  let fit: RufletStackFit
  @ViewBuilder let content: () -> Content

  var body: some View {
    if #available(iOS 16.0, macOS 13.0, *) {
      RufletStackAlignmentLayout(alignment: alignment, fit: fit) { content() }
    } else {
      content().frame(
        maxWidth: fit == .expand ? .infinity : nil,
        maxHeight: fit == .expand ? .infinity : nil,
        alignment: .center)
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RufletStackAlignmentLayout: Layout {
  let alignment: RufletAlignment
  let fit: RufletStackFit

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let intrinsic = child.sizeThatFits(fit == .loose ? .unspecified : proposal)
    return CGSize(
      width: proposal.width.flatMap { $0.isFinite ? max($0, 0) : nil } ?? intrinsic.width,
      height: proposal.height.flatMap { $0.isFinite ? max($0, 0) : nil } ?? intrinsic.height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    guard let child = subviews.first else { return }
    let size: CGSize
    switch fit {
    case .expand: size = bounds.size
    case .passthrough:
      size = child.sizeThatFits(ProposedViewSize(width: bounds.width, height: bounds.height))
    case .loose: size = child.sizeThatFits(.unspecified)
    }
    let origin = RufletGeometry.alignedOrigin(
      alignment: alignment, containerSize: bounds.size, childSize: size)
    child.place(
      at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
      anchor: .topLeading,
      proposal: ProposedViewSize(width: size.width, height: size.height))
  }
}

private enum RufletStackFit: String { case loose, expand, passthrough }

/// A stack child that placed itself.
private struct PositionedChild: View {
  let node: ControlNode
  let alignment: RufletAlignment

  @ViewBuilder
  var body: some View {
    let animated = node.props["animate_position"] != nil
    let hasInsets = ["left", "top", "right", "bottom"].contains { node.double($0) != nil }
    let left = node.double("left") ?? (animated && !hasInsets ? 0 : nil)
    let top = node.double("top") ?? (animated && !hasInsets ? 0 : nil)
    let right = node.double("right")
    let bottom = node.double("bottom")

    if #available(iOS 16.0, macOS 13.0, *) {
      RufletPositionedLayout(
        left: left.map { CGFloat($0) }, top: top.map { CGFloat($0) },
        right: right.map { CGFloat($0) }, bottom: bottom.map { CGFloat($0) },
        alignment: alignment
      ) {
        ControlView(id: node.id, axis: .none)
      }
      .animation(ControlProps.animation(node.props["animate_position"]), value: node)
    } else {
      // Layout protocol is unavailable on iOS 15. Preserve the previous
      // placement fallback there; all supported macOS versions and modern
      // iOS hosts use the exact Flet constraint implementation above.
      ControlView(id: node.id, axis: .none)
        .frame(
          maxWidth: .infinity, maxHeight: .infinity,
          alignment: .center
        )
        .offset(
          x: left.map { CGFloat($0) } ?? -(right.map { CGFloat($0) } ?? 0),
          y: top.map { CGFloat($0) } ?? -(bottom.map { CGFloat($0) } ?? 0)
        )
        .animation(ControlProps.animation(node.props["animate_position"]), value: node)
    }
  }
}

/// Flutter's `Positioned` turns opposing insets into tight constraints. For
/// example, a child with `left: 20, right: 30` in a 300-point Stack is exactly
/// 250 points wide. An aligned SwiftUI frame does not provide that constraint;
/// this Layout does, before the child measures and paints its decoration.
@available(iOS 16.0, macOS 13.0, *)
private struct RufletPositionedLayout: Layout {
  let left: CGFloat?
  let top: CGFloat?
  let right: CGFloat?
  let bottom: CGFloat?
  let alignment: RufletAlignment

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let intrinsic = child.sizeThatFits(.unspecified)
    return PositionedConstraintMath.containerSize(
      proposal: proposal, intrinsic: intrinsic,
      left: left, top: top, right: right, bottom: bottom)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    guard let child = subviews.first else { return }
    let intrinsic = child.sizeThatFits(.unspecified)
    let childSize = PositionedConstraintMath.childSize(
      container: bounds.size, intrinsic: intrinsic,
      left: left, top: top, right: right, bottom: bottom)
    let origin = PositionedConstraintMath.origin(
      container: bounds.size, child: childSize,
      left: left, top: top, right: right, bottom: bottom,
      alignment: alignment)
    child.place(
      at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
      anchor: .topLeading,
      proposal: ProposedViewSize(width: childSize.width, height: childSize.height))
  }
}

enum PositionedConstraintMath {
  @available(iOS 16.0, macOS 13.0, *)
  static func containerSize(
    proposal: ProposedViewSize, intrinsic: CGSize,
    left: CGFloat?, top: CGFloat?, right: CGFloat?, bottom: CGFloat?
  ) -> CGSize {
    CGSize(
      width: finite(proposal.width) ?? intrinsic.width + (left ?? 0) + (right ?? 0),
      height: finite(proposal.height) ?? intrinsic.height + (top ?? 0) + (bottom ?? 0))
  }

  static func childSize(
    container: CGSize, intrinsic: CGSize,
    left: CGFloat?, top: CGFloat?, right: CGFloat?, bottom: CGFloat?
  ) -> CGSize {
    CGSize(
      width: left != nil && right != nil
        ? max(container.width - (left ?? 0) - (right ?? 0), 0) : intrinsic.width,
      height: top != nil && bottom != nil
        ? max(container.height - (top ?? 0) - (bottom ?? 0), 0) : intrinsic.height)
  }

  static func origin(
    container: CGSize, child: CGSize,
    left: CGFloat?, top: CGFloat?, right: CGFloat?, bottom: CGFloat?,
    alignment: RufletAlignment
  ) -> CGPoint {
    CGPoint(
      x: left ?? right.map { container.width - $0 - child.width }
        ?? alignedOffset(available: container.width - child.width, alignment: alignment.x),
      y: top ?? bottom.map { container.height - $0 - child.height }
        ?? alignedOffset(available: container.height - child.height, alignment: alignment.y))
  }

  private static func finite(_ value: CGFloat?) -> CGFloat? {
    guard let value, value.isFinite else { return nil }
    return max(value, 0)
  }

  private static func alignedOffset(available: CGFloat, alignment: Double) -> CGFloat {
    available * CGFloat((alignment + 1) / 2)
  }
}

/// `ResponsiveRow` — children carry a `col` breakpoint map.
///
/// Flet lays these out on a 12-column grid; the same grid is reproduced here
/// against the container width, picking the breakpoint the width falls into.
struct ResponsiveRowControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @State private var viewWidth: CGFloat = 0

  @ViewBuilder
  var body: some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
      ResponsiveGridLayout(
        spans: node.childIDs.map { store.node($0)?.props["col"] },
        columns: node.props["columns"],
        spacing: node.props["spacing"],
        runSpacing: node.props["run_spacing"],
        breakpoints: ResponsiveGridMath.breakpoints(node.props["breakpoints"]),
        breakpointWidth: viewWidth > 0 ? viewWidth : nil,
        alignment: node.string("alignment") ?? "start",
        verticalAlignment: node.string("vertical_alignment") ?? "start"
      ) {
        ForEach(node.childIDs, id: \.self) { id in
          ControlView(id: id, axis: ResponsiveGridMath.childLayoutAxis)
            // Flet wraps every child in a ConstrainedBox whose minWidth and
            // maxWidth are identical. The flexible frame is SwiftUI's
            // equivalent: it consumes the exact width proposed by the grid.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      // Flutter's LayoutBuilder always receives its parent's finite maximum
      // width. Claiming that proposal here prevents an intrinsic-width parent
      // Column from collapsing the whole 12-column grid to a narrow strip.
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RufletViewportWidthReader { width in
        if abs(viewWidth - width) > 0.5 { viewWidth = width }
      })
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

#if canImport(UIKit)
private struct RufletViewportWidthReader: UIViewRepresentable {
  let update: (CGFloat) -> Void
  func makeUIView(context: Context) -> UIView { UIView(frame: .zero) }
  func updateUIView(_ view: UIView, context: Context) {
    DispatchQueue.main.async { update(view.window?.bounds.width ?? 0) }
  }
}
#elseif canImport(AppKit)
private struct RufletViewportWidthReader: NSViewRepresentable {
  let update: (CGFloat) -> Void
  func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }
  func updateNSView(_ view: NSView, context: Context) {
    DispatchQueue.main.async { update(view.window?.contentView?.bounds.width ?? 0) }
  }
}
#else
private struct RufletViewportWidthReader: View {
  let update: (CGFloat) -> Void
  var body: some View { Color.clear }
}
#endif

enum ResponsiveGridMath {
  static let childLayoutAxis: LayoutAxis = .tightHorizontal

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
      let span = max(spans[index], 0)
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

  static func constrainedItemSize(width: CGFloat, measured: CGSize) -> CGSize {
    CGSize(width: width, height: measured.height)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private struct ResponsiveGridLayout: Layout {
  let spans: [RufletValue?]
  let columns: RufletValue?
  let spacing: RufletValue?
  let runSpacing: RufletValue?
  let breakpoints: [String: Double]
  let breakpointWidth: CGFloat?
  let alignment: String
  let verticalAlignment: String

  struct Line {
    let indices: [Int]
    let sizes: [CGSize]
    let width: CGFloat
    let height: CGFloat
    let baselines: [CGFloat]
    let baselineAbove: CGFloat
  }

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    let width = finiteWidth(proposal.width, subviews: subviews)
    let metrics = resolved(width: width, subviews: subviews)
    let height =
      metrics.lines.reduce(0) { $0 + $1.height }
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
        switch verticalAlignment.lowercased().replacingOccurrences(of: "_", with: "") {
        case "center": verticalOffset = (line.height - size.height) / 2
        case "end": verticalOffset = line.height - size.height
        case "baseline": verticalOffset = line.baselineAbove - line.baselines[position]
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
    let responsiveWidth = breakpointWidth ?? width
    let columnCount = max(
      ResponsiveGridMath.value(
        columns, default: 12, width: responsiveWidth, breakpoints: breakpoints), 1)
    let gridGap = CGFloat(
      ResponsiveGridMath.value(
        spacing, default: 10, width: responsiveWidth, breakpoints: breakpoints))
    let placementGap = gridGap - 0.1
    let runGap = CGFloat(
      ResponsiveGridMath.value(
        runSpacing, default: 10, width: responsiveWidth,
        breakpoints: ResponsiveGridMath.defaultBreakpoints))
    let resolvedSpans = subviews.indices.map { index in
      max(
        ResponsiveGridMath.value(
          index < spans.count ? spans[index] : nil,
          default: 12, width: responsiveWidth, breakpoints: breakpoints), 0)
    }
    let lineIndices = ResponsiveGridMath.lines(spans: resolvedSpans, columns: columnCount)
    let lines = lineIndices.map { indices -> Line in
      var sizes = indices.map { index -> CGSize in
        let itemWidth = ResponsiveGridMath.itemWidth(
          span: resolvedSpans[index], columns: columnCount, total: width, spacing: gridGap)
        let measured = subviews[index].sizeThatFits(
          ProposedViewSize(width: itemWidth, height: nil))
        // Flet uses ConstrainedBox(minWidth == maxWidth == childWidth).
        // A SwiftUI child may report its smaller intrinsic width even after
        // receiving a finite proposal, so preserve only its measured height
        // and make the grid's computed width authoritative.
        return ResponsiveGridMath.constrainedItemSize(
          width: itemWidth, measured: measured)
      }
      var baselines = indices.indices.map { position -> CGFloat in
        let index = indices[position]
        let dimensions = subviews[index].dimensions(
          in: ProposedViewSize(width: sizes[position].width, height: sizes[position].height))
        let baseline = dimensions[.firstTextBaseline]
        return baseline.isFinite ? baseline : sizes[position].height
      }
      var baselineAbove = baselines.max() ?? 0
      var lineHeight = sizes.map(\.height).max() ?? 0
      if verticalAlignment.lowercased() == "baseline" {
        let below = sizes.indices.map { max(sizes[$0].height - baselines[$0], 0) }.max() ?? 0
        lineHeight = baselineAbove + below
      } else if verticalAlignment.lowercased() == "stretch" {
        sizes = sizes.map { CGSize(width: $0.width, height: lineHeight) }
        baselines = sizes.map(\.height)
        baselineAbove = lineHeight
      }
      return Line(
        indices: indices, sizes: sizes,
        width: sizes.reduce(0) { $0 + $1.width }
          + placementGap * CGFloat(max(sizes.count - 1, 0)),
        height: lineHeight, baselines: baselines, baselineAbove: baselineAbove)
    }
    return (lines, placementGap, runGap)
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
  let alignment: ControlProps.MainAxisAlignment
  let runAlignment: ControlProps.MainAxisAlignment
  let crossAlignment: ControlProps.CrossAxisAlignment

  var body: some View {
    // SwiftUI has no flow layout before iOS 16, so lines are measured with
    // per-child width preferences and grouped as they arrive.
    FlowLayout(
      axis: .horizontal, spacing: spacing, runSpacing: runSpacing,
      alignment: alignment, runAlignment: runAlignment,
      crossAlignment: crossAlignment
    ) {
      ForEach(ids, id: \.self) { id in
        ControlView(id: id, axis: .none)
      }
    }
  }
}
