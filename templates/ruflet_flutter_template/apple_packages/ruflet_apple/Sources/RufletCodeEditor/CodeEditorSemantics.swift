import Foundation
import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

/// The complete property surface read by Flet 0.80.5's `CodeEditorControl`.
/// Keeping this as data prevents the native text view from inventing defaults.
struct CodeEditorConfiguration: Equatable {
  struct Gutter: Equatable {
    var width: CGFloat = 80
    var margin: CGFloat = 10
    var showErrors = true
    var showFoldingHandles = true
    var showLineNumbers = true
    var backgroundToken: String?
    var textStyle: [String: RufletValue] = [:]

    var visible: Bool { showErrors || showFoldingHandles || showLineNumbers }
  }

  let language: String
  let themeName: String?
  let themeStyles: [String: RufletValue]
  let textStyle: [String: RufletValue]
  let padding: EdgeInsets
  let gutter: Gutter
  let autocomplete: Bool
  let autocompleteWords: [String]
  let readOnly: Bool
  let autofocus: Bool
  let disabled: Bool

  init(node: ControlNode) {
    language = node.string("language")?.lowercased() ?? ""
    let theme = node.props["code_theme"]
    themeName = theme?.stringValue ?? theme?["name"]?.stringValue
    if let map = theme?.mapValue {
      if let nested = map["styles"]?.mapValue {
        themeStyles = nested
      } else {
        themeStyles = map.filter { $0.key != "name" }
      }
    } else {
      themeStyles = [:]
    }
    textStyle = node.map("text_style") ?? [:]
    padding = ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets()

    var parsed = Gutter()
    if let map = node.map("gutter_style") {
      if let value = map["width"]?.doubleValue { parsed.width = CGFloat(value) }
      if let value = map["margin"]?.doubleValue {
        parsed.margin = CGFloat(value)
      } else if let insets = ControlProps.edgeInsets(map["margin"]) {
        // Pinned Flet averages the horizontal EdgeInsets for GutterStyle.
        parsed.margin = (insets.leading + insets.trailing) / 2
      }
      if let value = map["show_errors"]?.boolValue { parsed.showErrors = value }
      if let value = map["show_folding_handles"]?.boolValue { parsed.showFoldingHandles = value }
      if let value = map["show_line_numbers"]?.boolValue { parsed.showLineNumbers = value }
      parsed.backgroundToken = map["background_color"]?.stringValue
      parsed.textStyle = map["text_style"]?.mapValue ?? [:]
    }
    gutter = parsed
    autocomplete = node.bool("autocomplete") ?? false
    autocompleteWords = node.array("autocomplete_words")?.map(Self.dartString) ?? []
    readOnly = node.bool("read_only") ?? false
    autofocus = node.bool("autofocus") ?? false
    disabled = node.bool("disabled") == true
  }

  var dark: Bool {
    let name = themeName?.lowercased() ?? ""
    return name.contains("dark") || name.contains("monokai") || name.contains("dracula")
      || name.contains("atom-one-dark") || name.contains("vs2015")
  }

  var fontSize: CGFloat { CGFloat(textStyle["size"]?.doubleValue ?? 14) }
  var fontFamily: String? { textStyle["font_family"]?.stringValue }
  var editorInsets: EdgeInsets {
    EdgeInsets(
      top: padding.top,
      leading: padding.leading + (gutter.visible ? gutter.width + gutter.margin : 0),
      bottom: padding.bottom,
      trailing: padding.trailing)
  }

  /// Mirrors Dart's `value.map((e) => e.toString())` used by the plugin.
  static func dartString(_ value: RufletValue) -> String {
    switch value {
    case .null: return "null"
    case .bool(let value): return value ? "true" : "false"
    case .int(let value): return String(value)
    case .double(let value): return String(value)
    case .string(let value), .extended(_, let value): return value
    case .binary(let value): return "[" + value.map(String.init).joined(separator: ", ") + "]"
    case .array(let value): return "[" + value.map(Self.dartString).joined(separator: ", ") + "]"
    case .map(let value):
      return "{" + value.keys.sorted().map {
        "\($0): \(Self.dartString(value[$0]!))"
      }.joined(separator: ", ") + "}"
    case .controlRef(let value): return String(value)
    }
  }
}

enum CodeEditorValueEvents {
  static func commit(_ node: ControlNode, value: String, to events: RufletEventSink) {
    let wireValue = RufletValue.string(value)
    events.setLocal(node.id, "value", wireValue)
    events.update(node.id, ["value": wireValue])
    events.fire(node, "change", data: wireValue)
  }
}

enum CodeEditorCommandArguments {
  /// Mirrors Flet's `parseInt(args["line_number"])`: only an integer or a
  /// decimal string is accepted. In particular, RufletValue's permissive
  /// `intValue` conversion must not turn booleans or doubles into line zero.
  static func foldLine(_ value: RufletValue?) -> Int? {
    switch value {
    case .int(let value):
      return Int(exactly: value)
    case .string(let value):
      return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    default:
      return nil
    }
  }
}

enum CodeEditorSelection {
  static func range(from value: RufletValue?, text: String) -> NSRange {
    guard let map = value?.mapValue,
      let base = map["base_offset"]?.intValue,
      let extent = map["extent_offset"]?.intValue
    else { return NSRange(location: 0, length: 0) }
    let length = text.utf16.count
    let lower = min(max(min(base, extent), 0), length)
    let upper = min(max(max(base, extent), 0), length)
    return NSRange(location: lower, length: upper - lower)
  }

  static func value(_ range: NSRange, text: String) -> RufletValue {
    let length = text.utf16.count
    let location = min(max(range.location, 0), length)
    let end = min(max(NSMaxRange(range), location), length)
    return .map([
      "base_offset": .int(Int64(location)),
      "extent_offset": .int(Int64(end)),
      "affinity": .string("downstream"),
      "directional": .bool(false),
    ])
  }

  static func event(_ nativeRange: NSRange, text: String) -> RufletValue {
    let selection = value(nativeRange, text: text)
    let normalized = self.range(from: selection, text: text)
    return .map([
      "selected_text": .string((text as NSString).substring(with: normalized)),
      "selection": selection,
    ])
  }
}
