import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
typealias RufletCodePlatformColor = UIColor
typealias RufletCodePlatformFont = UIFont
#elseif os(macOS)
import AppKit
typealias RufletCodePlatformColor = NSColor
typealias RufletCodePlatformFont = NSFont
#endif

struct RufletGutterStyle {
  let width: Double
  let margin: Double
  let showErrors: Bool
  let showFoldingHandles: Bool
  let showLineNumbers: Bool
  let foreground: RufletCodePlatformColor
  let background: RufletCodePlatformColor
}

struct RufletCodeTokenStyle {
  let color: RufletCodePlatformColor
  let bold: Bool
  let italic: Bool
}

struct RufletCodeInsets {
  let top: Double
  let left: Double
  let bottom: Double
  let right: Double
}

struct RufletCodeEditorStyle {
  let font: RufletCodePlatformFont
  let lineHeight: Double
  let foreground: RufletCodePlatformColor
  let background: RufletCodePlatformColor
  let gutter: RufletGutterStyle
  let padding: RufletCodeInsets
  let tokens: [String: RufletCodeTokenStyle]

  @MainActor
  init(control: RufletControl, themeTextStyle: RufletTextStyle? = nil) {
    let text = control.value("text_style")?.map ?? [:]
    let explicitTextStyle = parseTextStyle(control.dynamicValue("text_style"))
    let size = explicitTextStyle?.size ?? themeTextStyle?.size ?? 16
    lineHeight = size * (explicitTextStyle?.height ?? themeTextStyle?.height ?? 1.5)
    let fontName = text["font_family"]?.text
    let weight = text["weight"]?.text?.lowercased() ?? "normal"
    let themeName = control.value("code_theme")?.text
      ?? control.value("code_theme")?.map?["name"]?.text
      ?? "xcode"
    let root = Self.namedRootColors(themeName)
    #if os(iOS)
    if let fontName, let custom = UIFont(name: fontName, size: size) { font = custom }
    else { font = .monospacedSystemFont(ofSize: size, weight: weight == "bold" || weight == "w700" ? .bold : .regular) }
    foreground = UIColor(parseColor(text["color"]?.text) ?? Color(root.foreground))
    background = UIColor(parseColor(text["bgcolor"]?.text) ?? Color(root.background))
    #elseif os(macOS)
    if let fontName, let custom = NSFont(name: fontName, size: size) { font = custom }
    else { font = .monospacedSystemFont(ofSize: size, weight: weight == "bold" || weight == "w700" ? .bold : .regular) }
    foreground = parseColor(text["color"]?.text).map(NSColor.init) ?? root.foreground
    background = parseColor(text["bgcolor"]?.text).map(NSColor.init) ?? root.background
    #endif

    let gutterMap = control.value("gutter_style")?.map ?? [:]
    let gutterText = gutterMap["text_style"]?.map ?? [:]
    // `flutter_code_editor` paints one root background behind both the gutter
    // and the editing field. Its optional GutterStyle.background is not a
    // separate strip in the pinned renderer. Keep that behavior here so a
    // dark code theme cannot expose the page's light system background.
    #if os(iOS)
    let gutterForeground = parseColor(gutterText["color"]?.text).map(UIColor.init)
      ?? foreground.withAlphaComponent(0.5)
    let gutterBackground = background
    #elseif os(macOS)
    let gutterForeground = parseColor(gutterText["color"]?.text).map(NSColor.init)
      ?? foreground.withAlphaComponent(0.5)
    let gutterBackground = background
    #endif
    let marginValue = gutterMap["margin"]
    let margin = marginValue?.number
      ?? ((marginValue?.map?["left"]?.number ?? 10) + (marginValue?.map?["right"]?.number ?? 10)) / 2
    gutter = RufletGutterStyle(
      width: gutterMap["width"]?.number ?? 80,
      margin: margin,
      showErrors: gutterMap["show_errors"]?.bool ?? true,
      showFoldingHandles: gutterMap["show_folding_handles"]?.bool ?? true,
      showLineNumbers: gutterMap["show_line_numbers"]?.bool ?? true,
      foreground: gutterForeground,
      background: gutterBackground)

    let rawPadding = control.value("padding")
    if let amount = rawPadding?.number {
      padding = RufletCodeInsets(top: amount, left: amount, bottom: amount, right: amount)
    } else {
      let map = rawPadding?.map ?? [:]
      padding = RufletCodeInsets(
        top: map["top"]?.number ?? 0,
        left: map["left"]?.number ?? 0,
        bottom: map["bottom"]?.number ?? 0,
        right: map["right"]?.number ?? 0)
    }
    tokens = Self.parseTheme(control.value("code_theme"))
  }

  var paragraphStyle: NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    return style
  }

  var gutterAttributes: [NSAttributedString.Key: Any] {
    let paragraph = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
    paragraph.alignment = .right
    return [
      .font: font,
      .foregroundColor: gutter.foreground,
      .backgroundColor: gutter.background,
      .paragraphStyle: paragraph,
    ]
  }

  private static func parseTheme(_ value: RufletValue?) -> [String: RufletCodeTokenStyle] {
    let name = value?.text ?? value?.map?["name"]?.text ?? "xcode"
    var colors = namedTheme(name)
    if let map = value?.map {
      let source = map["styles"]?.map ?? map.filter { $0.key != "name" }
      for (token, rawStyle) in source {
        guard let style = rawStyle.map else { continue }
        let color = parseColor(style["color"]?.text)
        #if os(iOS)
        let platformColor = color.map(UIColor.init)
        #elseif os(macOS)
        let platformColor = color.map(NSColor.init)
        #endif
        if let platformColor {
          colors[token] = RufletCodeTokenStyle(
            color: platformColor,
            bold: ["bold", "w700", "w800", "w900"].contains(style["weight"]?.text?.lowercased() ?? ""),
            italic: style["italic"]?.bool ?? false)
        }
      }
    }
    return colors
  }

  private static func namedTheme(_ name: String) -> [String: RufletCodeTokenStyle] {
    if name.lowercased() == "atom-one-dark" {
      func atom(_ value: UInt32) -> RufletCodePlatformColor {
        let r = CGFloat((value >> 16) & 0xff) / 255
        let g = CGFloat((value >> 8) & 0xff) / 255
        let b = CGFloat(value & 0xff) / 255
        #if os(iOS)
        return UIColor(red: r, green: g, blue: b, alpha: 1)
        #elseif os(macOS)
        return NSColor(red: r, green: g, blue: b, alpha: 1)
        #endif
      }
      return [
        "keyword": .init(color: atom(0xC678DD), bold: false, italic: false),
        "string": .init(color: atom(0x98C379), bold: false, italic: false),
        "comment": .init(color: atom(0x5C6370), bold: false, italic: true),
        "number": .init(color: atom(0xD19A66), bold: false, italic: false),
        "type": .init(color: atom(0xD19A66), bold: false, italic: false),
        "function": .init(color: atom(0x61AEEE), bold: false, italic: false),
      ]
    }
    let dark = ["monokai", "dracula", "atom-one-dark", "vs2015", "obsidian"].contains(name.lowercased())
    func color(_ light: UInt32, _ darkValue: UInt32) -> RufletCodePlatformColor {
      let value = dark ? darkValue : light
      let r = CGFloat((value >> 16) & 0xff) / 255
      let g = CGFloat((value >> 8) & 0xff) / 255
      let b = CGFloat(value & 0xff) / 255
      #if os(iOS)
      return UIColor(red: r, green: g, blue: b, alpha: 1)
      #elseif os(macOS)
      return NSColor(red: r, green: g, blue: b, alpha: 1)
      #endif
    }
    return [
      "keyword": .init(color: color(0xA626A4, 0xFF79C6), bold: true, italic: false),
      "string": .init(color: color(0x50A14F, 0xF1FA8C), bold: false, italic: false),
      "comment": .init(color: color(0xA0A1A7, 0x6272A4), bold: false, italic: true),
      "number": .init(color: color(0x986801, 0xBD93F9), bold: false, italic: false),
      "type": .init(color: color(0xC18401, 0x8BE9FD), bold: false, italic: false),
      "function": .init(color: color(0x4078F2, 0x50FA7B), bold: false, italic: false),
    ]
  }

  private static func namedRootColors(
    _ name: String
  ) -> (foreground: RufletCodePlatformColor, background: RufletCodePlatformColor) {
    let values: (UInt32, UInt32) = name.lowercased() == "atom-one-dark"
      ? (0xABB2BF, 0x282C34) : (0xE0E0E0, 0x212121)
    func color(_ value: UInt32) -> RufletCodePlatformColor {
      let r = CGFloat((value >> 16) & 0xff) / 255
      let g = CGFloat((value >> 8) & 0xff) / 255
      let b = CGFloat(value & 0xff) / 255
      #if os(iOS)
      return UIColor(red: r, green: g, blue: b, alpha: 1)
      #elseif os(macOS)
      return NSColor(red: r, green: g, blue: b, alpha: 1)
      #endif
    }
    return (color(values.0), color(values.1))
  }
}

enum RufletCodeLanguage {
  private static let common = ["if", "else", "for", "while", "return", "break", "continue", "true", "false", "null"]
  private static let words: [String: [String]] = [
    "swift": ["actor", "associatedtype", "async", "await", "case", "catch", "class", "defer", "do", "enum", "extension", "func", "guard", "import", "in", "init", "let", "nonisolated", "protocol", "public", "private", "some", "static", "struct", "switch", "throws", "try", "var", "weak", "where"],
    "dart": ["abstract", "as", "assert", "async", "await", "class", "const", "covariant", "deferred", "dynamic", "enum", "export", "extends", "extension", "external", "factory", "final", "get", "implements", "import", "interface", "late", "library", "mixin", "operator", "part", "required", "set", "show", "sync", "typedef", "var", "with", "yield"],
    "python": ["and", "as", "assert", "async", "await", "class", "def", "del", "elif", "except", "finally", "from", "global", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "try", "with", "yield"],
    "javascript": ["async", "await", "class", "const", "delete", "export", "extends", "function", "import", "instanceof", "let", "new", "of", "super", "switch", "this", "throw", "typeof", "undefined", "var", "yield"],
    "typescript": ["abstract", "any", "as", "async", "await", "class", "const", "declare", "enum", "export", "extends", "function", "implements", "import", "interface", "keyof", "let", "namespace", "never", "new", "private", "protected", "public", "readonly", "string", "type", "typeof", "unknown", "var", "void"],
    "java": ["abstract", "boolean", "byte", "catch", "char", "class", "double", "enum", "extends", "final", "finally", "float", "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "package", "private", "protected", "public", "short", "static", "super", "synchronized", "this", "throw", "throws", "transient", "try", "void", "volatile"],
    "ruby": ["alias", "and", "begin", "class", "def", "defined?", "do", "elsif", "end", "ensure", "module", "next", "not", "or", "redo", "rescue", "retry", "self", "super", "then", "undef", "unless", "until", "when", "yield"],
    "c": ["auto", "char", "const", "double", "enum", "extern", "float", "int", "long", "register", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile"],
    "cpp": ["alignas", "auto", "bool", "class", "concept", "constexpr", "consteval", "constinit", "decltype", "delete", "explicit", "export", "friend", "namespace", "new", "noexcept", "nullptr", "operator", "private", "protected", "public", "requires", "template", "this", "thread_local", "typename", "using", "virtual"],
  ]

  static func keywords(for language: String) -> [String] {
    common + (words[language.lowercased()] ?? words[language.lowercased() == "js" ? "javascript" : language.lowercased()] ?? [])
  }
}

struct RufletCodeHighlighter {
  let style: RufletCodeEditorStyle
  let language: String

  func apply(to storage: NSTextStorage) {
    let fullRange = NSRange(location: 0, length: storage.length)
    storage.beginEditing()
    storage.setAttributes([
      .font: style.font,
      .foregroundColor: style.foreground,
      .backgroundColor: style.background,
      .paragraphStyle: style.paragraphStyle,
    ], range: fullRange)
    apply(pattern: #"\b\d+(?:\.\d+)?\b"#, token: "number", storage: storage)
    let keywords = RufletCodeLanguage.keywords(for: language).map(NSRegularExpression.escapedPattern).joined(separator: "|")
    if !keywords.isEmpty { apply(pattern: "\\b(?:\(keywords))\\b", token: "keyword", storage: storage) }
    apply(pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#, token: "type", storage: storage)
    apply(pattern: #"\b[A-Za-z_][A-Za-z0-9_]*(?=\s*\()"#, token: "function", storage: storage)
    apply(pattern: #"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#, token: "string", storage: storage)
    apply(pattern: #"//[^\n]*|/\*[\s\S]*?\*/|(?m)^\s*#[^\n]*"#, token: "comment", storage: storage)
    storage.endEditing()
  }

  private func apply(pattern: String, token: String, storage: NSTextStorage) {
    guard let tokenStyle = style.tokens[token],
          let regex = try? NSRegularExpression(pattern: pattern)
    else { return }
    let range = NSRange(location: 0, length: storage.length)
    for match in regex.matches(in: storage.string, range: range) {
      storage.addAttribute(.foregroundColor, value: tokenStyle.color, range: match.range)
      if tokenStyle.bold || tokenStyle.italic {
        #if os(iOS)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if tokenStyle.bold { traits.insert(.traitBold) }
        if tokenStyle.italic { traits.insert(.traitItalic) }
        if let descriptor = style.font.fontDescriptor.withSymbolicTraits(traits) {
          storage.addAttribute(.font, value: UIFont(descriptor: descriptor, size: style.font.pointSize), range: match.range)
        }
        #elseif os(macOS)
        var traits: NSFontTraitMask = []
        if tokenStyle.bold { traits.insert(.boldFontMask) }
        if tokenStyle.italic { traits.insert(.italicFontMask) }
        storage.addAttribute(.font, value: NSFontManager.shared.convert(style.font, toHaveTrait: traits), range: match.range)
        #endif
      }
    }
  }
}
