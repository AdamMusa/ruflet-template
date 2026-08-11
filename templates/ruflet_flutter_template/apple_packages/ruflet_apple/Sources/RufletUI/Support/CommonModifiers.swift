import RufletEngine
import RufletProtocol
import SwiftUI

/// The axis a control's parent lays out along.
///
/// Needed because `expand` means "fill the main axis", which is height inside a
/// Column and width inside a Row — the job Flutter's `Expanded` does, signalled
/// by the `host_expanded` internal that `Control#to_patch` sets.
public enum LayoutAxis {
  case vertical
  case horizontal
  /// The parent supplies an exact horizontal constraint, like Flutter's
  /// `BoxConstraints(minWidth: w, maxWidth: w)`. SwiftUI proposals are loose
  /// by default, so controls must explicitly consume this width before they
  /// paint their decoration.
  case tightHorizontal
  case tightVertical
  case none

  var requiresTightWidth: Bool { self == .tightHorizontal }
  var requiresTightHeight: Bool { self == .tightVertical }
}

/// Applies the shared property vocabulary around a control's own body.
///
/// Every control goes through this, which is what keeps `visible`, `opacity`,
/// `expand`, `tooltip`, `rotate` and friends behaving identically across all of
/// them instead of being reimplemented per widget.
struct CommonControlModifiers: ViewModifier {
  let node: ControlNode
  let axis: LayoutAxis

  func body(content: Content) -> some View {
    // Keep this order identical to Flet's LayoutControl in
    // flet/lib/src/controls/base_controls.dart. The ordering is observable:
    // for example opacity is applied before sizing and fractional offset is
    // applied before alignment and margin.
    content
      .modifier(TightConstraintFrame(axis: axis))
      // Padding/background are part of the native control body. They remain
      // closest to the body while individual renderers are migrated away from
      // this compatibility layer.
      .modifier(ControlPaddingModifier(node: node))
      .modifier(DecorationModifier(node: node))
      .modifier(ControlStateModifier(node: node))
      .modifier(FletOpacityModifier(node: node))
      .modifier(FletTooltipModifier(node: node))
      .modifier(FletDirectionalityModifier(node: node))
      .modifier(FletFixedSizeModifier(node: node))
      .modifier(FletRotationModifier(node: node))
      .modifier(FletScaleModifier(node: node))
      .modifier(FletOffsetModifier(node: node))
      .modifier(FletAspectRatioModifier(node: node))
      .modifier(FletAlignmentModifier(node: node))
      .modifier(FletMarginModifier(node: node))
      // Positioned is implemented by Stack/Overlay because SwiftUI, like
      // Flutter, needs the parent constraints to resolve left+right/top+bottom.
      .modifier(FletSizeChangeModifier(node: node))
      .modifier(FletExpandModifier(node: node, axis: axis))
  }
}

/// Constructor defaults owned by Flet's shared LayoutControl rather than an
/// individual widget. Keeping them here prevents a renderer family from
/// inventing a different fallback.
enum FletBaseControlDefaults {
  static let sizeChangeIntervalMilliseconds = 10
}

private struct TightConstraintFrame: ViewModifier {
  let axis: LayoutAxis

  func body(content: Content) -> some View {
    if axis.requiresTightWidth {
      content.frame(maxWidth: .infinity, alignment: .leading)
    } else if axis.requiresTightHeight {
      content.frame(maxHeight: .infinity, alignment: .top)
    } else {
      content
    }
  }
}

// MARK: - Size

private struct FletFixedSizeModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    if node.skipsFletProperty("width") || node.skipsFletProperty("height") {
      return AnyView(content)
    }
    let width = node.double("width").map { CGFloat($0) }
    let height = node.double("height").map { CGFloat($0) }
    let sized = content
      .modifier(FixedSize(width: width, height: height))
    if let animation = ControlProps.animation(node.props["animate_size"]) {
      return AnyView(sized.animation(animation, value: CGSize(width: width ?? -1, height: height ?? -1)))
    }
    return AnyView(sized)
  }
}

private struct FixedSize: ViewModifier {
  let width: CGFloat?
  let height: CGFloat?

  func body(content: Content) -> some View {
    if let width, let height {
      content
        .modifier(ParentConstrainedWidth(requested: width))
        .frame(minHeight: height, maxHeight: height)
    } else if let width {
      content.modifier(ParentConstrainedWidth(requested: width))
    } else if let height {
      content.frame(height: height)
    } else {
      content
    }
  }
}

/// Flutter resolves `SizedBox(width:)` inside the constraints supplied by its
/// parent: `width: 560` becomes 390 on a 390-point phone, while `width: 320`
/// remains exactly 320. A custom Layout gives SwiftUI those same tight width
/// constraints; `ViewThatFits` is not equivalent because it can choose a
/// child's smaller intrinsic width.
private struct ParentConstrainedWidth: ViewModifier {
  let requested: CGFloat

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 16.0, macOS 13.0, *) {
      ParentConstrainedWidthLayout(requested: requested) { content }
    } else {
      // The iOS 15 fallback still accepts the parent's finite proposal and
      // treats the Ruby width as a ceiling.
      content.frame(maxWidth: requested)
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct ParentConstrainedWidthLayout: Layout {
  let requested: CGFloat

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let width = resolvedWidth(proposal.width)
    let measured = child.sizeThatFits(
      ProposedViewSize(width: width, height: proposal.height))
    return CGSize(width: width, height: measured.height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    guard let child = subviews.first else { return }
    child.place(
      at: bounds.origin, anchor: .topLeading,
      proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
  }

  private func resolvedWidth(_ proposed: CGFloat?) -> CGFloat {
    FletConstraintMath.width(requested: requested, proposed: proposed)
  }
}

enum FletConstraintMath {
  static func width(requested: CGFloat, proposed: CGFloat?) -> CGFloat {
    guard let proposed, proposed.isFinite else { return max(requested, 0) }
    return min(max(requested, 0), max(proposed, 0))
  }
}

private struct FletExpandModifier: ViewModifier {
  let node: ControlNode
  let axis: LayoutAxis

  func body(content: Content) -> some View {
    let flex = node.int("expand") ?? (node.bool("expand") == true ? 1 : 0)
    let loose = node.bool("expand_loose") == true
    if flex > 0 && node.hostExpanded {
      switch axis {
      case .horizontal:
        content.frame(maxWidth: .infinity, alignment: loose ? .leading : .center)
      case .vertical:
        content.frame(maxHeight: .infinity, alignment: loose ? .top : .center)
      case .tightHorizontal, .tightVertical, .none:
        content
      }
    } else {
      content
    }
  }
}

private struct FletAspectRatioModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    if let ratio = node.double("aspect_ratio").map({ CGFloat($0) }) {
      content.aspectRatio(ratio, contentMode: .fit)
    } else {
      content
    }
  }
}

// MARK: - Padding

private struct ControlPaddingModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let ownsPadding = ["Container", "View", "ListView", "GridView", "AppBar"].contains(node.type)
    return content.padding(
      ownsPadding ? EdgeInsets() : (ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets()))
  }
}

// MARK: - Transform

private struct FletOpacityModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let opacity = node.double("opacity") ?? 1
    let result = content.opacity(opacity)
    if let animation = ControlProps.animation(node.props["animate_opacity"]) {
      result.animation(animation, value: opacity)
    } else {
      result
    }
  }
}

private struct FletRotationModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let rotation = ControlProps.rotation(node.props["rotate"]) ?? .zero
    let result = content.rotationEffect(rotation)
    if let animation = ControlProps.animation(node.props["animate_rotation"]) {
      result.animation(animation, value: rotation.radians)
    } else {
      result
    }
  }
}

private struct FletScaleModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let scale = ControlProps.scale(node.props["scale"]) ?? CGSize(width: 1, height: 1)
    let result = content.scaleEffect(x: scale.width, y: scale.height)
    if let animation = ControlProps.animation(node.props["animate_scale"]) {
      result.animation(animation, value: scale)
    } else {
      result
    }
  }
}

private struct FletOffsetModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let offset = ControlProps.offset(node.props["offset"])
    let result = content.modifier(FractionalTranslationModifier(fraction: offset))
    if let animation = ControlProps.animation(node.props["animate_offset"]) {
      result.animation(animation, value: offset ?? .zero)
    } else {
      result
    }
  }
}

private struct FletMarginModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    if node.skipsFletProperty("margin") {
      return AnyView(content)
    }
    let margin = ControlProps.edgeInsets(node.props["margin"])
    let result = content.padding(margin ?? EdgeInsets())
    if let animation = ControlProps.animation(node.props["animate_margin"]) {
      return AnyView(result.animation(animation, value: margin ?? EdgeInsets()))
    }
    return AnyView(result)
  }
}

private struct FletDirectionalityModifier: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    // Flet only inserts Directionality for rtl=true. Otherwise the inherited
    // page/application direction must remain untouched.
    if node.bool("rtl") == true {
      content.environment(\.layoutDirection, .rightToLeft)
    } else {
      content
    }
  }
}

private struct FletTooltipModifier: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if !node.skipsFletProperty("tooltip"), let tooltip = node.string("tooltip"), !tooltip.isEmpty {
      content.help(tooltip)
    } else {
      content
    }
  }
}

private struct FletAlignmentModifier: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if let alignment = ControlProps.continuousAlignment(node.props["align"]) {
      if #available(iOS 16.0, macOS 13.0, *) {
        FletAlignLayout(alignment: alignment) { content }
      } else {
        content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: ControlProps.alignment(node.props["align"]) ?? .center)
      }
    } else {
      content
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct FletAlignLayout: Layout {
  let alignment: FletAlignment

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let childSize = child.sizeThatFits(proposal)
    return CGSize(
      width: proposal.width.flatMap { $0.isFinite ? max($0, 0) : nil } ?? childSize.width,
      height: proposal.height.flatMap { $0.isFinite ? max($0, 0) : nil } ?? childSize.height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
    guard let child = subviews.first else { return }
    let childSize = child.sizeThatFits(proposal)
    let origin = FletGeometry.alignedOrigin(
      alignment: alignment, containerSize: bounds.size, childSize: childSize)
    child.place(
      at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
      anchor: .topLeading,
      proposal: ProposedViewSize(width: childSize.width, height: childSize.height))
  }
}

private struct FletSizeChangeModifier: ViewModifier {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var lastSize: CGSize?
  @State private var lastDispatch = Date.distantPast
  @State private var pendingToken = UUID()

  func body(content: Content) -> some View {
    if node.handlesEvent("size_change") {
      content
        .background(
          GeometryReader { proxy in
            Color.clear.preference(key: FletObservedSizeKey.self, value: proxy.size)
          })
        .onPreferenceChange(FletObservedSizeKey.self, perform: report)
    } else {
      content
    }
  }

  private func report(_ size: CGSize) {
    guard size != lastSize else { return }
    let interval = max(
      node.int("size_change_interval")
        ?? FletBaseControlDefaults.sizeChangeIntervalMilliseconds,
      0)
    let elapsed = Date().timeIntervalSince(lastDispatch) * 1000
    if lastSize != nil, interval > 0, elapsed < Double(interval) {
      let token = UUID()
      pendingToken = token
      DispatchQueue.main.asyncAfter(deadline: .now() + (Double(interval) - elapsed) / 1000) {
        guard pendingToken == token else { return }
        dispatch(size)
      }
    } else {
      dispatch(size)
    }
  }

  private func dispatch(_ size: CGSize) {
    lastSize = size
    lastDispatch = Date()
    events.fire(node, "size_change", data: .map([
      "w": .double(size.width), "h": .double(size.height)
    ]))
  }
}

private struct FletObservedSizeKey: PreferenceKey {
  static let defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private extension ControlNode {
  func skipsFletProperty(_ property: String) -> Bool {
    internals["skip_properties"]?.arrayValue?.contains {
      $0.stringValue == property
    } == true
  }
}

/// SwiftUI's `offset` is absolute points, while Flet delegates to Flutter's
/// `FractionalTranslation`. Measure without changing the child's proposed or
/// reported size, then translate by that intrinsic size. This also preserves
/// Flet's paint-only behavior: siblings are laid out as if no offset existed.
private struct FractionalTranslationModifier: ViewModifier {
  let fraction: CGSize?
  @State private var childSize: CGSize = .zero

  func body(content: Content) -> some View {
    guard let fraction else { return AnyView(content) }
    let translation = FletGeometry.fractionalTranslation(
      fraction: fraction, childSize: childSize)
    return AnyView(
      content
        .background(
          GeometryReader { proxy in
            Color.clear.preference(key: FractionalChildSizeKey.self, value: proxy.size)
          })
        .onPreferenceChange(FractionalChildSizeKey.self) { childSize = $0 }
        .offset(x: translation.width, y: translation.height))
  }
}

private struct FractionalChildSizeKey: PreferenceKey {
  static let defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

// MARK: - Decoration

private struct DecorationModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    // `bgcolor` on a leaf control paints behind it; Container handles its own
    // richer decoration and does not set this.
    let ownsBackground = [
      "Container", "ProgressBar", "ProgressRing", "ElevatedButton", "FilledButton",
      "FilledTonalButton", "OutlinedButton", "TextButton", "IconButton", "FilledIconButton",
      "FilledTonalIconButton", "OutlinedIconButton", "FloatingActionButton"
    ].contains(node.type)
    let background = ownsBackground ? nil : MaterialPalette.color(node.string("bgcolor"))
    return content.background(background)
  }
}

// MARK: - Interaction

private struct ControlStateModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    content
      .disabled(node.bool("disabled") ?? false)
      .accessibilityLabel(node.string("semantics_label") ?? "")
  }
}

extension View {
  /// Applies the shared vocabulary, then honours `visible`.
  ///
  /// `visible: false` removes the control rather than hiding it, matching
  /// Flutter's `Visibility` default that Flet relies on.
  @ViewBuilder
  func rufletCommon(_ node: ControlNode, axis: LayoutAxis) -> some View {
    if node.bool("visible") == false {
      EmptyView()
    } else {
      modifier(CommonControlModifiers(node: node, axis: axis))
    }
  }
}
