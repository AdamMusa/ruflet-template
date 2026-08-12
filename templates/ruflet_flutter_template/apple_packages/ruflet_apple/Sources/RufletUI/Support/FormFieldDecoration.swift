import RufletEngine
import RufletProtocol
import SwiftUI

/// The furniture Flet wraps a text field in: a label above, and the helper,
/// error and counter row below.
///
/// Flet lets each of `helper`, `error`, `counter`, `prefix` and `suffix` be
/// either a control or a plain string — `form_field.dart` builds a widget when
/// the property holds a control and falls back to `getString` when it does not
/// — so every slot resolves the same way here.
struct RufletFormFieldSlot: View {
  let node: ControlNode
  let key: String
  var styleKey: String?
  var maxLines: Int?
  var fallbackColor: Color?

  var body: some View {
    if let id = resolvedControl {
      ControlView(id: id, axis: .none)
    } else if let text = resolvedText, !text.isEmpty {
      Text(text)
        .lineLimit(maxLines)
        .rufletTextStyle(style)
    }
  }

  /// Ruby spells these three ways depending on the control's vintage: a bare
  /// `helper`, a `hint_content` for the control form, and a `helper_text` for
  /// the string form. Only one ever arrives, so trying each in turn is
  /// unambiguous.
  private var resolvedControl: Int? {
    node.controlID(forKey: key) ?? node.controlID(forKey: "\(key)_content")
  }

  private var resolvedText: String? {
    if key == "counter" {
      return RufletTextFieldDefaults.counterText(
        node.string(key) ?? node.string("\(key)_text"),
        value: node.string("value") ?? "",
        maxLength: node.int("max_length"))
    }
    return node.string(key) ?? node.string("\(key)_text")
  }

  private var style: RufletTextStyle {
    // A missing style map leaves every field nil, so the same initialiser
    // serves the slots Ruby styled and the ones it did not.
    var style = RufletTextStyle(node: node, styleKey: styleKey ?? "\(key)_style")
    if style.size == nil, style.themeStyle == nil { style.themeStyle = Font.TextStyle.caption }
    if style.color == nil { style.color = fallbackColor }
    return style
  }
}

/// `FormField.icon` accepts either a control or an icon value. Keep that wire
/// distinction intact instead of accidentally rendering a bare icon name as
/// text when the native field is decorated.
private struct RufletFormFieldIconSlot: View {
  let node: ControlNode

  var body: some View {
    if let id = node.controlID(forKey: "icon") {
      ControlView(id: id, axis: .none)
    } else {
      RufletIcon(value: node.props["icon"])
    }
  }
}

/// Wraps a field in its label, helper, error and counter.
///
/// An error replaces the helper rather than joining it, which is what
/// Material's InputDecorator does.
struct RufletFormFieldDecoration: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      if hasLabel {
        RufletFormFieldSlot(node: node, key: "label", styleKey: "label_style")
          // `align_label_with_hint` lines the label up with the hint rather
          // than centring it on a multiline field's box.
          .padding(.leading, node.bool("align_label_with_hint") == true ? labelInset : 0)
      }
      HStack(spacing: 8) {
        if node.props["icon"] != nil {
          RufletFormFieldIconSlot(node: node)
        }
        content
      }
      footer
    }
    .frame(
      minWidth: constraints?.minWidth, maxWidth: constraints?.maxWidth,
      minHeight: constraints?.minHeight, maxHeight: constraints?.maxHeight)
  }

  /// A collapsed field draws no label at all, the way InputDecoration.collapsed
  /// does, and Flet keeps the label inside the field as a placeholder when
  /// nothing else names it.
  private var hasLabel: Bool {
    guard node.bool("collapsed") != true else { return false }
    // With no hint the label sits inside the field as the placeholder, so
    // drawing it above as well would say the same thing twice.
    guard node.string("hint_text") != nil else { return false }
    return has("label")
  }

  /// True when Ruby supplied the slot in any of its spellings.
  func has(_ key: String) -> Bool {
    node.controlID(forKey: key) != nil || node.controlID(forKey: "\(key)_content") != nil
      || !(node.string(key) ?? node.string("\(key)_text") ?? "").isEmpty
  }

  @ViewBuilder
  private var footer: some View {
    let showsError = has("error")
    let showsCounter = has("counter") || RufletTextFieldDefaults.hasDefaultCounter(node)
    if showsError || showsCounter || hasHelper {
      HStack(alignment: .top) {
        if showsError {
          RufletFormFieldSlot(
            node: node, key: "error", styleKey: "error_style",
            maxLines: node.int("error_max_lines"), fallbackColor: .red)
        } else if hasHelper {
          RufletFormFieldSlot(
            node: node, key: "helper", styleKey: "helper_style",
            maxLines: node.int("helper_max_lines"), fallbackColor: .secondary)
        }
        if showsCounter {
          Spacer(minLength: 8)
          RufletFormFieldSlot(
            node: node, key: "counter", styleKey: "counter_style",
            fallbackColor: .secondary)
        }
      }
    }
  }

  private var hasHelper: Bool { has("helper") }

  private var constraints: ControlProps.SizeConstraints? {
    ControlProps.sizeConstraints(node.props["size_constraints"])
  }

  /// The label sits over the field's own content inset when it is aligned
  /// with the hint rather than with the decoration's edge.
  private var labelInset: CGFloat {
    // Match the InputDecorator inset, including its omitted Material 3
    // outline default, while the editor remains the native Apple primitive.
    RufletTextFieldDefaults.contentPadding(node).leading
  }
}

/// `menu_style` is Flutter's `MenuStyle`: the surface a dropdown or popup
/// menu is drawn on, carried as a map of the same names a Container uses.
struct MenuSurfaceStyle: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    guard let style = value?.mapValue else { return AnyView(content) }
    let radius = ControlProps.cornerRadius(style["shape"]?.mapValue?["radius"]) ?? 0
    return AnyView(
      content
        .background(
          RoundedRectangle(cornerRadius: radius)
            .fill(MaterialPalette.color(style["bgcolor"]?.stringValue, default: .clear)))
        .padding(ControlProps.edgeInsets(style["padding"]) ?? EdgeInsets())
        .shadow(
          color: MaterialPalette.color(
            style["shadow_color"]?.stringValue, default: .black.opacity(0.2)),
          radius: CGFloat(style["elevation"]?.doubleValue ?? 0)))
  }
}
