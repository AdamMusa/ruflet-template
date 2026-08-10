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
  case none

  var requiresTightWidth: Bool { self == .tightHorizontal }
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
    content
      .modifier(TightConstraintFrame(axis: axis))
      .modifier(SizeModifier(node: node, axis: axis))
      .modifier(PaddingModifier(node: node))
      .modifier(TransformModifier(node: node))
      .modifier(DecorationModifier(node: node))
      .modifier(ControlAnimationModifier(node: node))
      .modifier(InteractionModifier(node: node))
  }
}

private struct TightConstraintFrame: ViewModifier {
  let axis: LayoutAxis

  func body(content: Content) -> some View {
    if axis.requiresTightWidth {
      content.frame(maxWidth: .infinity, alignment: .leading)
    } else {
      content
    }
  }
}

private struct ControlAnimationModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let value = node.props["animate"] ?? node.props["animate_size"]
      ?? node.props["animate_scale"] ?? node.props["animate_opacity"]
      ?? node.props["animate_rotation"] ?? node.props["animate_offset"]
      ?? node.props["animate_position"] ?? node.props["animate_align"]
    if let animation = ControlProps.animation(value) {
      content.animation(animation, value: node)
    } else {
      content
    }
  }
}

// MARK: - Size

private struct SizeModifier: ViewModifier {
  let node: ControlNode
  let axis: LayoutAxis

  func body(content: Content) -> some View {
    let width = node.double("width").map { CGFloat($0) }
    let height = node.double("height").map { CGFloat($0) }
    // `expand` is truthy or a flex integer; either way it means "take the
    // available main-axis space". `expand_loose` asks for at most that.
    let expands = (node.props["expand"]?.boolValue ?? false) || (node.int("expand") ?? 0) > 0
    let loose = node.bool("expand_loose") ?? false
    let ratio = node.double("aspect_ratio").map { CGFloat($0) }

    // Each of these is applied only when the control asked for it. An
    // unconditional `.aspectRatio(nil, contentMode: .fit)` is not the no-op it
    // looks like — it letterboxes the view inside its parent — and an
    // always-on `.frame` pins an intrinsic size the control never wanted.
    return
      content
      .modifier(FixedSize(width: width, height: height))
      .modifier(ExpandingFrame(expands: expands, axis: axis, loose: loose))
      .modifier(AspectRatio(ratio: ratio))
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

private struct ExpandingFrame: ViewModifier {
  let expands: Bool
  let axis: LayoutAxis
  let loose: Bool

  func body(content: Content) -> some View {
    if expands {
      switch axis {
      case .horizontal:
        content.frame(maxWidth: .infinity, alignment: loose ? .leading : .center)
      case .vertical:
        content.frame(maxHeight: .infinity, alignment: loose ? .top : .center)
      case .tightHorizontal, .none:
        content
      }
    } else {
      content
    }
  }
}

private struct AspectRatio: ViewModifier {
  let ratio: CGFloat?

  func body(content: Content) -> some View {
    if let ratio {
      content.aspectRatio(ratio, contentMode: .fit)
    } else {
      content
    }
  }
}

// MARK: - Padding

private struct PaddingModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let ownsPadding = ["Container", "View", "ListView", "GridView", "AppBar"].contains(node.type)
    return content
      .padding(ownsPadding ? EdgeInsets() : (ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets()))
      .padding(ControlProps.edgeInsets(node.props["margin"]) ?? EdgeInsets())
  }
}

// MARK: - Transform

private struct TransformModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let scale = ControlProps.scale(node.props["scale"])
    let offset = ControlProps.offset(node.props["offset"])

    return
      content
      .rotationEffect(ControlProps.rotation(node.props["rotate"]) ?? .zero)
      .scaleEffect(x: scale?.width ?? 1, y: scale?.height ?? 1)
      .offset(x: offset?.width ?? 0, y: offset?.height ?? 0)
      .opacity(node.double("opacity") ?? 1)
  }
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

private struct InteractionModifier: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    content
      .disabled(node.bool("disabled") ?? false)
      .help(node.string("tooltip") ?? "")
      .accessibilityLabel(node.string("semantics_label") ?? "")
      .environment(\.layoutDirection, (node.bool("rtl") ?? false) ? .rightToLeft : .leftToRight)
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
