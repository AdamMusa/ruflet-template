import RufletEngine
import RufletProtocol
import SwiftUI

/// The chrome a Flet text field resolves from its own properties and its
/// interaction state.
///
/// Material's TextField and Cupertino's read the same names for all of this —
/// `form_field.dart` serves both — so one resolver keeps them from drifting.
struct RufletFieldStyling {
  let node: ControlNode
  var focused = false
  var hovering = false

  /// `shift_enter` implies multiline the way Flet's textfield.dart reads it,
  /// and a min_lines above one does too.
  var isMultiline: Bool {
    node.bool("multiline") == true || node.bool("shift_enter") == true
      || (node.int("min_lines") ?? 1) > 1
  }

  /// Flutter defaults max_lines to one on a single-line field and leaves a
  /// multiline one unbounded.
  var maxLines: Int? { node.int("max_lines") ?? (isMultiline ? nil : 1) }

  var minLines: Int { node.int("min_lines") ?? 3 }

  /// Flet layers the field's text: `text_style` first, then `text_size`, then
  /// `focused_color` while focused and `color` otherwise.
  var textStyle: RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "text_style")
    if let size = node.double("text_size") { style.size = CGFloat(size) }
    let resting = MaterialPalette.color(node.string("color"))
    let active = MaterialPalette.color(node.string("focused_color"))
    if let color = focused ? (active ?? resting) : resting { style.color = color }
    return style
  }

  /// The input configuration, with the resolved text style folded in so the
  /// field and its style cannot disagree about who painted the text.
  var traits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    traits.textColor = textStyle.color
    traits.fontSize = textStyle.size
    return traits
  }

  /// `dense` and `collapsed` are Material's two tighter insets; anything else
  /// takes `content_padding`, or `padding` where Cupertino sends that.
  var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    if let padding = ControlProps.edgeInsets(node.props["padding"]) { return padding }
    if node.bool("collapsed") == true { return EdgeInsets() }
    let inset: CGFloat = node.bool("dense") == true ? 4 : 8
    return EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
  }

  var scrollPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["scroll_padding"])
      ?? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
  }

  var fitsParent: Bool { node.bool("fit_parent_size") == true }

  var cornerRadius: CGFloat {
    ControlProps.cornerRadius(node.props["border_radius"]) ?? 8
  }

  var clipBehavior: String { node.string("clip_behavior") ?? "hardEdge" }

  /// `text_vertical_align` runs -1 (top) to 1 (bottom), the way Flutter's
  /// alignment axes do.
  var verticalAlignment: VerticalAlignment {
    switch node.double("text_vertical_align") {
    case .some(let value) where value <= -0.5: return .top
    case .some(let value) where value >= 0.5: return .bottom
    default: return .center
    }
  }

  var hasError: Bool {
    node.controlID(forKey: "error") != nil
      || !(node.string("error") ?? node.string("error_text") ?? "").isEmpty
  }

  /// Material resolves a field's fill from its interaction state, so the
  /// focused, hovered and resting colours are tried in that order.
  func background(default fallback: Color) -> Color {
    if focused, let focusedFill = MaterialPalette.color(node.string("focused_bgcolor")) {
      return focusedFill
    }
    if hovering, let hover = MaterialPalette.color(node.string("hover_color")) {
      return hover
    }
    if let explicit = MaterialPalette.color(node.string("bgcolor")) { return explicit }
    if node.bool("filled") == true {
      return MaterialPalette.color(node.string("fill_color"), default: fallback)
    }
    return MaterialPalette.color(node.string("fill_color"), default: fallback)
  }

  func borderColor(default fallback: Color) -> Color {
    if hasError {
      return MaterialPalette.color(for: node, property: "error_border_color", default: .red)
    }
    if focused,
      let active = MaterialPalette.color(
        node.string("focused_border_color") ?? node.string("focus_color"))
    {
      return active
    }
    return MaterialPalette.color(for: node, property: "border_color", default: fallback)
  }

  var borderWidth: CGFloat {
    let resting = node.double("border_width") ?? 1
    guard focused else { return CGFloat(resting) }
    return CGFloat(node.double("focused_border_width") ?? resting)
  }

  var drawsBorder: Bool { node.string("border")?.lowercased() != "none" }
}
