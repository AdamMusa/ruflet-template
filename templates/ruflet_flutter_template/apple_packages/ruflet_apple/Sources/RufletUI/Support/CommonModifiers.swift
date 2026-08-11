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
      .modifier(RufletOpacityModifier(node: node))
      .modifier(RufletTooltipModifier(node: node))
      .modifier(RufletDirectionalityModifier(node: node))
      .modifier(RufletFixedSizeModifier(node: node))
      .modifier(RufletRotationModifier(node: node))
      .modifier(RufletScaleModifier(node: node))
      .modifier(RufletOffsetModifier(node: node))
      .modifier(RufletAspectRatioModifier(node: node))
      .modifier(RufletAlignmentModifier(node: node))
      .modifier(RufletMarginModifier(node: node))
      // Positioned is implemented by Stack/Overlay because SwiftUI, like
      // Flutter, needs the parent constraints to resolve left+right/top+bottom.
      .modifier(RufletBadgeModifier(node: node))
      .modifier(RufletSizeChangeModifier(node: node))
      .modifier(RufletExpandModifier(node: node, axis: axis))
      // Flutter resolves the cursor from the whole hit-tested stack, so this
      // sits outside the layout chain rather than in Flet's order.
      .modifier(RufletMouseCursorModifier(node: node))
  }
}

/// Constructor defaults owned by Flet's shared LayoutControl rather than an
/// individual widget. Keeping them here prevents a renderer family from
/// inventing a different fallback.
enum RufletBaseControlDefaults {
  static let sizeChangeIntervalMilliseconds = 10
}

/// `badge` — the count or dot Material hangs off a control's corner.
///
/// Flet takes either a Badge control or a bare value, which it wraps in a
/// label; `wrapWithBadge` does both. A badge with no visible label is the
/// small dot, which is Flutter's behaviour when `label_visible` is false.
struct RufletBadgeModifier: ViewModifier {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  func body(content: Content) -> some View {
    if let badge = badgeNode {
      content.overlay(alignment: alignment(badge)) {
        marker(badge).offset(offset(badge))
      }
    } else if let text = node.string("badge"), !text.isEmpty {
      content.overlay(alignment: .topTrailing) {
        label(Text(text), on: nil).offset(x: 4, y: -4)
      }
    } else {
      content
    }
  }

  private var badgeNode: ControlNode? {
    node.controlID(forKey: "badge").flatMap { store.node($0) }
  }

  @ViewBuilder
  private func marker(_ badge: ControlNode) -> some View {
    if badge.bool("label_visible") == false {
      Circle()
        .fill(MaterialPalette.color(badge.string("bgcolor"), default: .red))
        .frame(
          width: CGFloat(badge.double("small_size") ?? 6),
          height: CGFloat(badge.double("small_size") ?? 6))
    } else if let labelID = badge.controlID(forKey: "label") {
      label(AnyView(ControlView(id: labelID, axis: .none)), on: badge)
    } else {
      label(Text(badge.string("label") ?? ""), on: badge)
    }
  }

  private func label(_ content: some View, on badge: ControlNode?) -> some View {
    let large = CGFloat(badge?.double("large_size") ?? 16)
    return content
      .rufletTextStyle(textStyle(badge))
      .padding(
        ControlProps.edgeInsets(badge?.props["padding"])
          ?? EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
      .frame(minWidth: large, minHeight: large)
      .background(
        Capsule().fill(MaterialPalette.color(badge?.string("bgcolor"), default: .red)))
  }

  private func textStyle(_ badge: ControlNode?) -> RufletTextStyle {
    guard let badge else { return RufletTextStyle() }
    var style = RufletTextStyle(node: badge, styleKey: "text_style")
    if style.color == nil {
      style.color = MaterialPalette.color(badge.string("text_color"), default: .white)
    }
    if style.size == nil, style.themeStyle == nil { style.themeStyle = Font.TextStyle.caption2 }
    return style
  }

  private func alignment(_ badge: ControlNode) -> Alignment {
    ControlProps.alignment(badge.props["alignment"]) ?? .topTrailing
  }

  private func offset(_ badge: ControlNode) -> CGSize {
    guard let map = badge.map("offset") else { return CGSize(width: 4, height: -4) }
    return CGSize(
      width: CGFloat(map["x"]?.doubleValue ?? 4), height: CGFloat(map["y"]?.doubleValue ?? -4))
  }
}

/// `mouse_cursor` — Flutter's `SystemMouseCursors` names against AppKit's
/// cursors.
///
/// Only macOS has a pointer to change. iOS carries the property so one Ruby
/// app runs on both, and it is inert there, exactly as it is in Flutter.
struct RufletMouseCursorModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    #if os(macOS)
      if let cursor = Self.cursor(node.string("mouse_cursor")) {
        content.onHover { inside in
          if inside { cursor.push() } else { NSCursor.pop() }
        }
      } else {
        content
      }
    #else
      content
    #endif
  }

  #if os(macOS)
    /// AppKit has no cursor for several of Flutter's names, and the ones it
    /// does have it spells differently. A name with no counterpart leaves the
    /// cursor alone rather than guessing at a lookalike.
    static func cursor(_ name: String?) -> NSCursor? {
      switch name?.lowercased() {
      case "click", "grab": return .openHand
      case "grabbing", "move", "allscroll": return .closedHand
      case "text": return .iBeam
      case "verticaltext": return .iBeamCursorForVerticalLayout
      case "forbidden", "nodrop": return .operationNotAllowed
      case "contextmenu": return .contextualMenu
      case "copy": return .dragCopy
      case "alias": return .dragLink
      case "precise", "cell": return .crosshair
      case "none": return .none
      case "resizeleftright", "resizecolumn": return .resizeLeftRight
      case "resizeupdown", "resizerow": return .resizeUpDown
      case "resizeup": return .resizeUp
      case "resizedown": return .resizeDown
      case "resizeleft": return .resizeLeft
      case "resizeright": return .resizeRight
      case "disappearing": return .disappearingItem
      default: return nil
      }
    }
  #endif
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

private struct RufletFixedSizeModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    if node.skipsRufletProperty("width") || node.skipsRufletProperty("height") {
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
    RufletConstraintMath.width(requested: requested, proposed: proposed)
  }
}

enum RufletConstraintMath {
  static func width(requested: CGFloat, proposed: CGFloat?) -> CGFloat {
    guard let proposed, proposed.isFinite else { return max(requested, 0) }
    return min(max(requested, 0), max(proposed, 0))
  }
}

private struct RufletExpandModifier: ViewModifier {
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

private struct RufletAspectRatioModifier: ViewModifier {
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

private struct RufletOpacityModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let opacity = node.double("opacity") ?? 1
    let result = content.opacity(opacity)
    if let animation = ControlProps.animation(node.props["animate_opacity"]) {
      result
        .animation(animation, value: opacity)
        .modifier(
          RufletAnimationEndReporter(
            node: node, animation: node.props["animate_opacity"], value: opacity,
            property: "opacity"))
    } else {
      result
    }
  }
}

private struct RufletRotationModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let rotation = ControlProps.rotation(node.props["rotate"]) ?? .zero
    let result = content.rotationEffect(rotation)
    if let animation = ControlProps.animation(node.props["animate_rotation"]) {
      result
        .animation(animation, value: rotation.radians)
        .modifier(
          RufletAnimationEndReporter(
            node: node, animation: node.props["animate_rotation"],
            value: rotation.radians, property: "rotation"))
    } else {
      result
    }
  }
}

private struct RufletScaleModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let scale = ControlProps.scale(node.props["scale"]) ?? CGSize(width: 1, height: 1)
    let result = content.scaleEffect(x: scale.width, y: scale.height)
    if let animation = ControlProps.animation(node.props["animate_scale"]) {
      result
        .animation(animation, value: scale)
        .modifier(
          RufletAnimationEndReporter(
            node: node, animation: node.props["animate_scale"], value: scale,
            property: "scale"))
    } else {
      result
    }
  }
}

private struct RufletOffsetModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let offset = ControlProps.offset(node.props["offset"])
    let result = content.modifier(FractionalTranslationModifier(fraction: offset))
    if let animation = ControlProps.animation(node.props["animate_offset"]) {
      result
        .animation(animation, value: offset ?? .zero)
        .modifier(
          RufletAnimationEndReporter(
            node: node, animation: node.props["animate_offset"], value: offset ?? .zero,
            property: "offset"))
    } else {
      result
    }
  }
}

private struct RufletMarginModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    if node.skipsRufletProperty("margin") {
      return AnyView(content)
    }
    let margin = ControlProps.edgeInsets(node.props["margin"])
    let result = content.padding(margin ?? EdgeInsets())
    if let animation = ControlProps.animation(node.props["animate_margin"]) {
      return AnyView(
        result
          .animation(animation, value: margin ?? EdgeInsets())
          .modifier(
            RufletAnimationEndReporter(
              node: node, animation: node.props["animate_margin"],
              value: margin ?? EdgeInsets(), property: "margin")))
    }
    return AnyView(result)
  }
}

private struct RufletDirectionalityModifier: ViewModifier {
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

private struct RufletTooltipModifier: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if !node.skipsRufletProperty("tooltip"), let tooltip = node.string("tooltip"), !tooltip.isEmpty {
      content.help(tooltip)
    } else {
      content
    }
  }
}

private struct RufletAlignmentModifier: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if let alignment = ControlProps.continuousAlignment(node.props["align"]) {
      if #available(iOS 16.0, macOS 13.0, *) {
        RufletAlignLayout(alignment: alignment) { content }
          .animation(ControlProps.animation(node.props["animate_align"]), value: alignment)
          .modifier(
            RufletAnimationEndReporter(
              node: node, animation: node.props["animate_align"], value: alignment,
              property: "align"))
      } else {
        content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: ControlProps.alignment(node.props["align"]) ?? .center)
      }
    } else {
      content
    }
  }
}

private struct RufletAnimationEndReporter<Value: Equatable>: ViewModifier {
  let node: ControlNode
  let animation: RufletValue?
  let value: Value
  let property: String
  @Environment(\.rufletEvents) private var events
  @State private var pendingToken = UUID()

  func body(content: Content) -> some View {
    guard node.handlesEvent("animation_end"),
      let duration = ControlProps.animationDurationSeconds(animation)
    else { return AnyView(content) }

    return AnyView(
      content.onChange(of: value) { _ in
        let token = UUID()
        pendingToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
          guard pendingToken == token else { return }
          events.fire(node, "animation_end", data: .string(property))
        }
      })
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RufletAlignLayout: Layout {
  let alignment: RufletAlignment

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
    let origin = RufletGeometry.alignedOrigin(
      alignment: alignment, containerSize: bounds.size, childSize: childSize)
    child.place(
      at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
      anchor: .topLeading,
      proposal: ProposedViewSize(width: childSize.width, height: childSize.height))
  }
}

private struct RufletSizeChangeModifier: ViewModifier {
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
            Color.clear.preference(key: RufletObservedSizeKey.self, value: proxy.size)
          })
        .onPreferenceChange(RufletObservedSizeKey.self, perform: report)
    } else {
      content
    }
  }

  private func report(_ size: CGSize) {
    guard size != lastSize else { return }
    let interval = max(
      node.int("size_change_interval")
        ?? RufletBaseControlDefaults.sizeChangeIntervalMilliseconds,
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

private struct RufletObservedSizeKey: PreferenceKey {
  static let defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private extension ControlNode {
  func skipsRufletProperty(_ property: String) -> Bool {
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
    let translation = RufletGeometry.fractionalTranslation(
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
    // `Button` is the canonical wire type the Ruby side sends; `ElevatedButton`
    // is its alias. Both must be here or the button's fill is painted twice,
    // once by this modifier and once by the button style.
    let ownsBackground = [
      "Container", "ProgressBar", "ProgressRing", "Button", "ElevatedButton", "FilledButton",
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
