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
    if let id = node.controlID(forKey: key) {
      ControlView(id: id, axis: .none)
    } else if let text = node.string(key), !text.isEmpty {
      Text(text)
        .lineLimit(maxLines)
        .rufletTextStyle(style)
    }
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
      }
      HStack(spacing: 8) {
        if node.controlID(forKey: "icon") != nil {
          RufletFormFieldSlot(node: node, key: "icon")
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
    guard node.string("hint_text") != nil else { return false }
    return node.controlID(forKey: "label") != nil || node.string("label") != nil
  }

  @ViewBuilder
  private var footer: some View {
    let showsError = node.controlID(forKey: "error") != nil
      || !(node.string("error") ?? "").isEmpty
    let showsCounter = node.controlID(forKey: "counter") != nil
      || !(node.string("counter") ?? "").isEmpty
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

  private var hasHelper: Bool {
    node.controlID(forKey: "helper") != nil || !(node.string("helper") ?? "").isEmpty
  }

  private var constraints: ControlProps.SizeConstraints? {
    ControlProps.sizeConstraints(node.props["size_constraints"])
  }
}
