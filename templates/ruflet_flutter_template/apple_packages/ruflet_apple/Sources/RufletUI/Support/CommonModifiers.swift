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
  /// Both axes are exact. RenderFlex uses this when an expanded child also
  /// participates in a stretched cross axis.
  case tightBoth
  case none

  var requiresTightWidth: Bool { self == .tightHorizontal || self == .tightBoth }
  var requiresTightHeight: Bool { self == .tightVertical || self == .tightBoth }
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
      .modifier(TightConstraintFrame(node: node, axis: axis))
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
      // Flutter's RenderImage cannot paint outside its tight width/height.
      // SwiftUI's asynchronous image stack can retain the bitmap's intrinsic
      // paint bounds after the outer frame changes (most visibly in AppBar
      // titles), so clip only explicitly-sized Image controls at that same
      // point in the layout pipeline.
      .modifier(RufletExplicitImageBounds(node: node))
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

private struct RufletExplicitImageBounds: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if RufletImageLayoutSemantics.clipsExplicitBounds(node) {
      content.clipped()
    } else {
      content
    }
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
/// label; `wrapWithBadge` does both. A visible badge with no label is the
/// small dot, while `label_visible: false` removes the badge altogether.
struct RufletBadgeModifier: ViewModifier {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.layoutDirection) private var layoutDirection

  func body(content: Content) -> some View {
    if let badge = badgeNode {
      if RufletBadgeSemantics.isVisible(badge) {
        content.overlay(alignment: alignment(badge)) {
          RufletBadgeMarker(badge: badge)
            .offset(RufletBadgeSemantics.markerOffset(
              badge, layoutDirection: layoutDirection,
              labelPresent: RufletBadgeSemantics.hasVisibleLabel(badge, in: store.nodes)))
        }
      } else {
        content
      }
    } else if let text = node.string("badge") {
      content.overlay(alignment: .topTrailing) {
        RufletBadgeMarker(fallbackLabel: text)
          .offset(RufletBadgeSemantics.labelOffset(
            nil, layoutDirection: layoutDirection))
      }
    } else {
      content
    }
  }

  private var badgeNode: ControlNode? {
    node.controlID(forKey: "badge").flatMap { store.node($0) }
  }

  private func alignment(_ badge: ControlNode) -> Alignment {
    ControlProps.alignment(badge.props["alignment"]) ?? .topTrailing
  }
}

/// Apple has no public standalone badge view which can host an arbitrary
/// SwiftUI control (the native `.badge` API is limited to rows and tabs).
/// This adapter keeps that native boundary while consuming the exact Flet /
/// Flutter semantic defaults for its arbitrary label slot.
struct RufletBadgeMarker: View {
  var badge: ControlNode?
  var fallbackLabel: String?
  @EnvironmentObject private var store: ControlStore

  init(badge: ControlNode? = nil, fallbackLabel: String? = nil) {
    self.badge = badge
    self.fallbackLabel = fallbackLabel
  }

  @ViewBuilder
  var body: some View {
    if let labelID = visibleLabelID {
      labelled(AnyView(ControlView(id: labelID, axis: .none)))
    } else if let text = badge?.string("label") ?? fallbackLabel {
      labelled(AnyView(Text(text)))
    } else {
      Circle()
        .fill(backgroundColor)
        .frame(width: smallSize, height: smallSize)
    }
  }

  private var visibleLabelID: Int? {
    RufletBadgeSemantics.visibleLabelID(badge, in: store.nodes)
  }

  private func labelled(_ content: AnyView) -> some View {
    content
      .rufletTextStyle(textStyle)
      .padding(
        ControlProps.edgeInsets(badge?.props["padding"])
          ?? EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
      .frame(minWidth: largeSize, minHeight: largeSize)
      .background(Capsule().fill(backgroundColor))
  }

  private var backgroundColor: Color {
    MaterialPalette.color(RufletBadgeSemantics.backgroundColor(badge), default: .red)
  }

  private var textStyle: RufletTextStyle {
    // Badge defaults to Material labelSmall. An explicit `text_style` refines
    // that type role, while `text_color` then wins over the style's colour —
    // the precedence used by Badge's final `copyWith(color:)`.
    var style = RufletTextStyle(map: ["theme_style": .string("label_small")])
    if let badge {
      style.merge(RufletTextStyle(node: badge, styleKey: "text_style"))
    }
    style.color = MaterialPalette.color(RufletBadgeSemantics.textColor(badge), default: .white)
    return style
  }

  /// Six points is the native notification-dot size used by Apple surfaces.
  private var smallSize: CGFloat { CGFloat(badge?.double("small_size") ?? 6) }

  private var largeSize: CGFloat { CGFloat(badge?.double("large_size") ?? 16) }
}

/// Source-pinned behavior from Flutter's `Badge.build` and Flet's
/// `wrapWithBadge`: `label_visible` hides the entire badge; a *missing* label
/// selects the small-dot presentation. They are intentionally not the same
/// state.
enum RufletBadgeSemantics {
  static func isVisible(_ badge: ControlNode) -> Bool {
    badge.bool("label_visible") != false
  }

  static func hasLabel(_ badge: ControlNode) -> Bool {
    badge.controlID(forKey: "label") != nil || badge.string("label") != nil
  }

  static func hasVisibleLabel(
    _ badge: ControlNode, in nodes: [Int: ControlNode]
  ) -> Bool {
    visibleLabelID(badge, in: nodes) != nil || badge.string("label") != nil
  }

  static func visibleLabelID(
    _ badge: ControlNode?, in nodes: [Int: ControlNode]
  ) -> Int? {
    guard let id = badge?.controlID(forKey: "label"),
      nodes[id]?.bool("visible") != false
    else { return nil }
    return id
  }

  static func backgroundColor(_ badge: ControlNode?) -> String {
    nonEmpty(badge?.string("bgcolor")) ?? "error"
  }

  static func textColor(_ badge: ControlNode?) -> String {
    nonEmpty(badge?.string("text_color")) ?? "onerror"
  }

  /// Flutter deliberately ignores alignment and offset for a dot badge. Its
  /// render object pins the dot at the aligned corner with `Offset.zero`;
  /// only a labelled badge consumes the caller/default offset.
  static func markerOffset(
    _ badge: ControlNode?, layoutDirection: LayoutDirection, labelPresent: Bool? = nil
  ) -> CGSize {
    guard labelPresent ?? badge.map({ hasLabel($0) }) ?? true else { return .zero }
    return labelOffset(badge, layoutDirection: layoutDirection)
  }

  static func labelOffset(
    _ badge: ControlNode?, layoutDirection: LayoutDirection
  ) -> CGSize {
    if let map = badge?.map("offset") {
      return CGSize(
        width: CGFloat(map["x"]?.doubleValue ?? 0),
        height: CGFloat(map["y"]?.doubleValue ?? 0))
    }
    return CGSize(width: layoutDirection == .rightToLeft ? -4 : 4, height: -4)
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
    else { return nil }
    return value
  }
}

/// Every name accepted by Flet's `parseMouseCursor`.
///
/// Parsing is kept platform-neutral even though only macOS can install the
/// corresponding pointer. This way an unknown wire value defers to the parent
/// on every Apple platform, just as Flutter's parser returns its default.
enum RufletMouseCursorName: String, CaseIterable {
  case alias, allscroll, basic, cell, click, contextmenu, copy, disappearing
  case forbidden, grab, grabbing, help, move, nodrop, none, precise, progress
  case resizecolumn, resizedown, resizedownleft, resizedownright, resizeleft
  case resizeleftright, resizeright, resizerow, resizeup, resizeupdown
  case resizeupleft, resizeupleftdownright, resizeupright
  case resizeuprightdownleft, text, verticaltext, wait, zoomin, zoomout

  init?(_ wireValue: String?) {
    guard let wireValue else { return nil }
    self.init(rawValue: wireValue.lowercased())
  }
}

/// `mouse_cursor` — Flutter's `SystemMouseCursors` names against AppKit's
/// cursors.
///
/// Only macOS has a pointer to change. iOS carries the property so one Ruby
/// app runs on both, and it is inert there, exactly as it is in Flutter.
struct RufletMouseCursorModifier: ViewModifier {
  let cursorName: String?

  init(node: ControlNode) {
    cursorName = node.string("mouse_cursor")
  }

  init(cursorName: String?) {
    self.cursorName = cursorName
  }

  func body(content: Content) -> some View {
    #if os(macOS)
      if let cursor = Self.cursor(cursorName) {
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
      switch RufletMouseCursorName(name) {
      case .basic: return .arrow
      case .click: return .pointingHand
      case .grab: return .openHand
      case .grabbing: return .closedHand
      case .text: return .iBeam
      case .verticaltext: return .iBeamCursorForVerticalLayout
      case .forbidden, .nodrop: return .operationNotAllowed
      case .contextmenu: return .contextualMenu
      case .copy: return .dragCopy
      case .alias: return .dragLink
      case .precise, .cell: return .crosshair
      case .some(.none):
        // AppKit has no public hidden-cursor singleton. A transparent native
        // cursor preserves Flutter's `none` semantics without drawing a
        // replacement pointer.
        return NSCursor(
          image: NSImage(size: NSSize(width: 1, height: 1)), hotSpot: .zero)
      case .resizeleftright, .resizecolumn: return .resizeLeftRight
      case .resizeupdown, .resizerow: return .resizeUpDown
      case .resizeup: return .resizeUp
      case .resizedown: return .resizeDown
      case .resizeleft: return .resizeLeft
      case .resizeright: return .resizeRight
      case .disappearing: return .disappearingItem
      case .zoomin:
        if #available(macOS 15.0, *) { return .zoomIn }
        return nil
      case .zoomout:
        if #available(macOS 15.0, *) { return .zoomOut }
        return nil
      // AppKit has no semantic counterpart for these Flutter cursors. Let the
      // responder chain retain its cursor rather than substitute a misleading
      // shape (for example, a closed hand for `move`).
      case .allscroll, .help, .move, .progress, .resizedownleft,
        .resizedownright, .resizeupleft, .resizeupleftdownright,
        .resizeupright, .resizeuprightdownleft, .wait, nil:
        return nil
      }
    }
  #endif
}

private struct TightConstraintFrame: ViewModifier {
  let node: ControlNode
  let axis: LayoutAxis

  private var horizontalAlignment: Alignment {
    // Flutter's Icon is a centered glyph inside its constrained square. When
    // a stretched Column gives it the full row width, the glyph remains in
    // the middle rather than moving to the leading edge.
    node.type == "Icon" ? .center : .leading
  }

  func body(content: Content) -> some View {
    if axis.requiresTightWidth && axis.requiresTightHeight {
      content
        .frame(maxWidth: .infinity, alignment: horizontalAlignment)
        .frame(maxHeight: .infinity, alignment: .top)
    } else if axis.requiresTightWidth {
      content.frame(maxWidth: .infinity, alignment: horizontalAlignment)
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
      case .tightHorizontal, .tightVertical, .tightBoth, .none:
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
  @State private var childSize = CGSize.zero

  func body(content: Content) -> some View {
    let presentation = ControlProps.rotationPresentation(node.props["rotate"])
      ?? .init(
        radians: 0, alignment: .center, origin: .zero,
        transformHitTests: true, filterQuality: nil)
    let result = content
      .background(transformSizeReader)
      .modifier(RufletRotationEffect(presentation: presentation, childSize: childSize))
      .onPreferenceChange(RufletTransformSizeKey.self) { childSize = $0 }
    if let animation = ControlProps.animation(node.props["animate_rotation"]) {
      result
        .animation(animation, value: presentation.radians)
        .modifier(
          RufletAnimationEndReporter(
            node: node, animation: node.props["animate_rotation"],
            value: presentation.radians, property: "rotation"))
    } else {
      result
    }
  }
}

private struct RufletScaleModifier: ViewModifier {
  let node: ControlNode
  @State private var childSize = CGSize.zero

  func body(content: Content) -> some View {
    let presentation = ControlProps.scalePresentation(node.props["scale"])
      ?? .init(
        factors: CGSize(width: 1, height: 1), alignment: .center,
        origin: .zero, transformHitTests: true, filterQuality: nil)
    let result = content
      .background(transformSizeReader)
      .modifier(RufletScaleEffect(presentation: presentation, childSize: childSize))
      .onPreferenceChange(RufletTransformSizeKey.self) { childSize = $0 }
    if let animation = ControlProps.animation(node.props["animate_scale"]) {
      result
        .animation(animation, value: presentation.factors)
        .modifier(
          RufletAnimationEndReporter(
            node: node, animation: node.props["animate_scale"], value: presentation.factors,
            property: "scale"))
    } else {
      result
    }
  }
}

private var transformSizeReader: some View {
  GeometryReader { proxy in
    Color.clear.preference(key: RufletTransformSizeKey.self, value: proxy.size)
  }
}

private struct RufletTransformSizeKey: PreferenceKey {
  static var defaultValue = CGSize.zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct RufletRotationEffect: ViewModifier {
  let presentation: ControlProps.RotationPresentation
  let childSize: CGSize

  @ViewBuilder
  func body(content: Content) -> some View {
    if presentation.transformHitTests {
      // SwiftUI's semantic transform moves its native hit-test coordinate
      // space with the pixels, matching Flutter's default.
      content.rotationEffect(
        .radians(presentation.radians), anchor: presentation.anchor(in: childSize))
    } else {
      // Projection effects paint in the transformed coordinate space without
      // moving the view's original native hit-test bounds.
      content.projectionEffect(ProjectionTransform(rotationTransform))
    }
  }

  private var rotationTransform: CGAffineTransform {
    let anchor = presentation.anchor(in: childSize)
    let pivot = CGPoint(x: anchor.x * childSize.width, y: anchor.y * childSize.height)
    return CGAffineTransform(translationX: pivot.x, y: pivot.y)
      .rotated(by: presentation.radians)
      .translatedBy(x: -pivot.x, y: -pivot.y)
  }
}

private struct RufletScaleEffect: ViewModifier {
  let presentation: ControlProps.ScalePresentation
  let childSize: CGSize

  @ViewBuilder
  func body(content: Content) -> some View {
    if presentation.transformHitTests {
      content.scaleEffect(
        x: presentation.factors.width, y: presentation.factors.height,
        anchor: presentation.anchor(in: childSize))
    } else {
      content.projectionEffect(ProjectionTransform(scaleTransform))
    }
  }

  private var scaleTransform: CGAffineTransform {
    let anchor = presentation.anchor(in: childSize)
    let pivot = CGPoint(x: anchor.x * childSize.width, y: anchor.y * childSize.height)
    return CGAffineTransform(translationX: pivot.x, y: pivot.y)
      .scaledBy(x: presentation.factors.width, y: presentation.factors.height)
      .translatedBy(x: -pivot.x, y: -pivot.y)
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

/// Parsed shape accepted by Flet's `parseTooltip`: either a bare string or
/// the structured Tooltip value. Apple exposes tooltip text through native
/// `help`; the remaining fields stay explicit here so wire semantics are not
/// lost and can be adopted if Apple expands that API.
struct RufletTooltipPresentation {
  enum TriggerMode: String {
    case manual, tap, longPress

    init?(_ value: String?) {
      switch value?.lowercased() {
      case "manual": self = .manual
      case "tap": self = .tap
      case "longpress": self = .longPress
      default: return nil
      }
    }
  }

  static let stringWaitDurationMilliseconds = 800.0
  static let defaultBorderRadius = 4.0
  static let nativeHelpLimitations: Set<String> = [
    "decoration", "enable_feedback", "exclude_from_semantics", "exit_duration",
    "margin", "padding", "prefer_below", "show_duration", "size_constraints",
    "tap_to_dismiss", "text_align", "text_style", "trigger_mode", "vertical_offset",
    "wait_duration",
  ]

  let message: String
  let structured: Bool
  let enableFeedback: Bool?
  let tapToDismiss: Bool
  let excludeFromSemantics: Bool?
  let constraints: ControlProps.SizeConstraints?
  let exitDurationMilliseconds: Double?
  let preferBelow: Bool?
  let padding: EdgeInsets?
  let borderRadius: CGFloat
  let backgroundColor: String?
  let textStyle: [String: RufletValue]?
  let verticalOffset: Double?
  let margin: EdgeInsets?
  let mouseCursor: RufletMouseCursorName?
  let textAlign: String?
  let showDurationMilliseconds: Double?
  let waitDurationMilliseconds: Double?
  let triggerMode: TriggerMode?

  init?(_ value: RufletValue?) {
    guard let value, !value.isNull else { return nil }
    if case .string(let message) = value {
      self.message = message
      structured = false
      enableFeedback = nil
      tapToDismiss = true
      excludeFromSemantics = nil
      constraints = nil
      exitDurationMilliseconds = nil
      preferBelow = nil
      padding = nil
      borderRadius = Self.defaultBorderRadius
      backgroundColor = nil
      textStyle = nil
      verticalOffset = nil
      margin = nil
      mouseCursor = nil
      textAlign = nil
      showDurationMilliseconds = nil
      waitDurationMilliseconds = Self.stringWaitDurationMilliseconds
      triggerMode = nil
      return
    }

    guard let map = value.mapValue else { return nil }
    message = map["message"]?.stringValue ?? ""
    structured = true
    enableFeedback = map["enable_feedback"]?.boolValue
    tapToDismiss = map["tap_to_dismiss"]?.boolValue ?? true
    excludeFromSemantics = map["exclude_from_semantics"]?.boolValue
    constraints = ControlProps.sizeConstraints(map["size_constraints"])
    exitDurationMilliseconds = Self.durationMilliseconds(map["exit_duration"])
    preferBelow = map["prefer_below"]?.boolValue
    padding = ControlProps.edgeInsets(map["padding"])
    let decoration = map["decoration"]?.mapValue
    borderRadius = ControlProps.cornerRadius(decoration?["border_radius"])
      ?? Self.defaultBorderRadius
    backgroundColor = decoration?["bgcolor"]?.stringValue ?? map["bgcolor"]?.stringValue
    textStyle = map["text_style"]?.mapValue
    verticalOffset = map["vertical_offset"]?.doubleValue
    margin = ControlProps.edgeInsets(map["margin"])
    mouseCursor = RufletMouseCursorName(map["mouse_cursor"]?.stringValue)
    textAlign = Self.enumValue(
      map["text_align"]?.stringValue,
      accepted: ["center", "end", "justify", "left", "right", "start"])
    showDurationMilliseconds = Self.durationMilliseconds(map["show_duration"])
    waitDurationMilliseconds = Self.durationMilliseconds(map["wait_duration"])
    triggerMode = TriggerMode(map["trigger_mode"]?.stringValue)
  }

  private static func enumValue(_ value: String?, accepted: Set<String>) -> String? {
    guard let value = value?.lowercased(), accepted.contains(value) else { return nil }
    return value
  }

  /// Mirrors Flet's `parseDuration`: numeric values are milliseconds and a
  /// component map is summed after every component is truncated to an Int.
  static func durationMilliseconds(_ value: RufletValue?) -> Double? {
    guard let value, !value.isNull else { return nil }
    if case .int(let milliseconds) = value { return Double(milliseconds) }
    if case .string(let raw) = value { return Double(Int(raw) ?? 0) }
    if case .double = value { return 0 }
    guard let map = value.mapValue else { return 0 }
    func integer(_ key: String) -> Int {
      switch map[key] {
      case .int(let value): return Int(value)
      case .string(let value): return Int(value) ?? 0
      default: return 0
      }
    }
    let microseconds = integer("microseconds")
      + 1_000 * integer("milliseconds")
      + 1_000_000 * integer("seconds")
      + 60_000_000 * integer("minutes")
      + 3_600_000_000 * integer("hours")
      + 86_400_000_000 * integer("days")
    return Double(microseconds) / 1_000
  }
}

private struct RufletTooltipModifier: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if !node.skipsRufletProperty("tooltip"),
      let tooltip = RufletTooltipPresentation(node.props["tooltip"])
    {
      // SwiftUI help is backed by the platform tooltip/accessibility system.
      // It does not expose Flutter's popup geometry, theme, trigger, feedback,
      // or duration knobs, so those are deliberately not hand-drawn here.
      content
        .help(tooltip.message)
        .modifier(RufletMouseCursorModifier(cursorName: tooltip.mouseCursor?.rawValue))
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

  @ViewBuilder
  func body(content: Content) -> some View {
    let disabled = content.disabled(node.bool("disabled") ?? false)
    if let label = RufletControlStateSemantics.label(for: node) {
      disabled.accessibilityLabel(label)
    } else {
      // An omitted label must leave the native control's accessibility tree
      // alone. Applying an empty label here erases the label supplied by
      // Button, Toggle, Picker and the platform text-input bridges.
      disabled
    }
  }
}

enum RufletControlStateSemantics {
  static func label(for node: ControlNode) -> String? {
    node.props["semantics_label"]?.stringValue
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


/// `maintain_bottom_view_padding` holds the bottom safe-area inset while the
/// keyboard is up, which is what Flutter's SafeArea flag does.
struct MaintainBottomInset: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled {
      content.ignoresSafeArea(.keyboard, edges: .bottom)
    } else {
      content
    }
  }
}

/// Material's optical-size axis. SF Symbols carry the same idea in the glyph's
/// point size, so the resolved symbol is scaled against the nominal 24.
struct IconOpticalSize: ViewModifier {
  let value: Double?

  func body(content: Content) -> some View {
    if let value, value > 0 {
      content.scaleEffect(CGFloat(value) / 24)
    } else {
      content
    }
  }
}
