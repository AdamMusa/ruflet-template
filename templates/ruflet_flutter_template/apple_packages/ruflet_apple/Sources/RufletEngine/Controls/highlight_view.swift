import Foundation
import SwiftUI

/// The only decoration property consumed by pinned Flet `HighlightView`.
public struct RufletHighlightDecoration {
  public let borderRadius: RufletBorderRadius?

  public init(borderRadius: RufletBorderRadius? = nil) {
    self.borderRadius = borderRadius
  }
}

/// Apple-native, file-for-file port of pinned Flet `HighlightView`.
public struct HighlightView: View {
  public let source: String
  public let language: String?
  public let theme: [String: RufletTextStyle]
  public let padding: EdgeInsets?
  public let decoration: RufletHighlightDecoration?
  public let textStyle: RufletTextStyle?
  public let selectable: Bool

  public init(
    _ input: String,
    language: String? = nil,
    theme: [String: RufletTextStyle] = [:],
    padding: EdgeInsets? = nil,
    decoration: RufletHighlightDecoration? = nil,
    textStyle: RufletTextStyle? = nil,
    tabSize: Int = 8,
    selectable: Bool = false
  ) {
    let spaces = String(repeating: " ", count: max(tabSize, 0))
    source = input.replacingOccurrences(of: "\t", with: spaces)
    self.language = language
    self.theme = theme
    self.padding = padding
    self.decoration = decoration
    self.textStyle = textStyle
    self.selectable = selectable
  }

  public var body: some View {
    let root = theme[Self.rootKey]
    let text = Text(attributedSource(root: root))
    Group {
      if selectable {
        text.textSelection(.enabled)
      } else {
        text
      }
    }
    .padding(padding ?? EdgeInsets())
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(root?.backgroundColor ?? Color.secondary.opacity(0.12))
    .clipShape(RufletCornerShape(radius: decoration?.borderRadius ?? .zero))
  }

  static let rootKey = "root"

  var highlightedTokens: [RufletHighlightToken] {
    RufletHighlightParser(source: source, language: language).parse()
  }

  private func attributedSource(root: RufletTextStyle?) -> AttributedString {
    let base = RufletResolvedHighlightStyle(
      primary: root, secondary: textStyle,
      defaultColor: root?.color ?? .secondary, monospaceByDefault: true)
    var result = AttributedString()
    for token in highlightedTokens {
      var fragment = AttributedString(token.text)
      apply(base, to: &fragment)
      if let className = token.className, let tokenStyle = theme[className] {
        apply(
          RufletResolvedHighlightStyle(
            primary: base, secondary: tokenStyle,
            defaultColor: base.color, monospaceByDefault: true),
          to: &fragment)
      }
      result += fragment
    }
    return result
  }

  private func apply(
    _ style: RufletResolvedHighlightStyle,
    to value: inout AttributedString
  ) {
    value.font = style.font
    value.foregroundColor = style.color
    if let background = style.backgroundColor { value.backgroundColor = background }
    if style.decoration & 0x1 != 0 {
      value.underlineStyle = Text.LineStyle(pattern: .solid, color: style.decorationColor)
    }
    if style.decoration & 0x4 != 0 {
      value.strikethroughStyle = Text.LineStyle(pattern: .solid, color: style.decorationColor)
    }
    if let letterSpacing = style.letterSpacing { value.kern = letterSpacing }
  }
}

private struct RufletResolvedHighlightStyle {
  let size: Double
  let weight: Font.Weight?
  let italic: Bool
  let fontFamily: String?
  let decoration: Int
  let decorationColor: Color?
  let color: Color
  let backgroundColor: Color?
  let letterSpacing: Double?

  var font: Font {
    var font: Font
    if let fontFamily {
      font = .custom(fontFamily, size: size)
    } else {
      font = .system(size: size, design: .monospaced)
    }
    if let weight { font = font.weight(weight) }
    if italic { font = font.italic() }
    return font
  }

  init(
    primary: RufletTextStyle?,
    secondary: RufletTextStyle?,
    defaultColor: Color,
    monospaceByDefault: Bool
  ) {
    size = secondary?.size ?? primary?.size ?? 14
    weight = secondary?.weight ?? primary?.weight
    italic = secondary?.italic == true || (secondary == nil && primary?.italic == true)
    fontFamily = secondary?.fontFamily ?? primary?.fontFamily
    decoration = secondary.map(\.decoration) ?? primary?.decoration ?? 0
    decorationColor = secondary?.decorationColor ?? primary?.decorationColor
    color = secondary?.color ?? primary?.color ?? defaultColor
    backgroundColor = secondary?.backgroundColor ?? primary?.backgroundColor
    letterSpacing = secondary?.letterSpacing ?? primary?.letterSpacing
  }

  init(
    primary: RufletResolvedHighlightStyle,
    secondary: RufletTextStyle,
    defaultColor: Color,
    monospaceByDefault: Bool
  ) {
    size = secondary.size ?? primary.size
    weight = secondary.weight ?? primary.weight
    italic = secondary.italic || primary.italic
    fontFamily = secondary.fontFamily ?? primary.fontFamily
    decoration = secondary.decoration == 0 ? primary.decoration : secondary.decoration
    decorationColor = secondary.decorationColor ?? primary.decorationColor
    color = secondary.color ?? defaultColor
    backgroundColor = secondary.backgroundColor ?? primary.backgroundColor
    letterSpacing = secondary.letterSpacing ?? primary.letterSpacing
  }
}

struct RufletHighlightToken: Equatable, Sendable {
  let text: String
  let className: String?
}

struct RufletHighlightParser {
  let source: String
  let language: String?

  func parse() -> [RufletHighlightToken] {
    guard !source.isEmpty else { return [] }
    let profile = RufletHighlightLanguage.profile(for: language, source: source)
    var scanner = RufletHighlightScanner(source: source, profile: profile)
    return scanner.scan()
  }
}

private struct RufletHighlightLanguage {
  let keywords: Set<String>
  let literals: Set<String>
  let builtIns: Set<String>
  let lineComments: [String]
  let blockComments: [(String, String)]
  let quoteCharacters: Set<Character>
  let caseInsensitive: Bool
  let markup: Bool

  static func profile(for language: String?, source: String) -> RufletHighlightLanguage {
    let name = normalized(language?.isEmpty == false ? language! : detect(source))
    let commonLiterals: Set<String> = ["true", "false", "null", "nil", "none"]
    var keywords = commonKeywords
    var builtIns: Set<String> = []
    var lineComments = ["//"]
    var blockComments = [("/*", "*/")]
    var quotes: Set<Character> = ["\"", "'"]
    var caseInsensitive = false
    var markup = false

    switch name {
    case "swift":
      keywords.formUnion(words("actor associatedtype async await case catch class defer deinit do enum extension fallthrough fileprivate func guard import in init inout internal is let mutating nonisolated open operator private protocol public repeat rethrows self some static struct subscript switch throw throws try typealias var weak where while"))
      builtIns = words("Any Array Bool Character Dictionary Double Error Float Int Never Optional Result Set String UInt Void")
    case "dart":
      keywords.formUnion(words("abstract as assert async await class const covariant deferred dynamic enum export extends extension external factory final get implements import interface late library mixin operator part required set show static sync typedef var with yield"))
      builtIns = words("BigInt bool DateTime double Duration Future int Iterable List Map Never Null num Object Record Set Stream String Symbol Type void")
    case "python":
      keywords.formUnion(words("and as assert async await class def del elif except finally from global import in is lambda nonlocal not or pass raise try with yield"))
      builtIns = words("abs all any bool bytes callable dict enumerate filter float format frozenset int len list map max min object open print property range repr reversed round set sorted str sum super tuple type zip")
      lineComments = ["#"]
      blockComments = []
    case "ruby":
      keywords.formUnion(words("alias and begin class def defined do elsif end ensure module next not or redo rescue retry self super then undef unless until when yield"))
      builtIns = words("Array Class Enumerable Exception FalseClass Float Hash Integer IO Kernel Module NilClass Numeric Object Proc Range Regexp String Struct Symbol Time TrueClass")
      lineComments = ["#"]
      blockComments = [("=begin", "=end")]
    case "javascript", "typescript":
      keywords.formUnion(words("abstract any as async await break case catch class const continue debugger declare default delete do else enum export extends finally for from function get if implements import in instanceof interface keyof let namespace never new of package private protected public readonly return set static super switch this throw try type typeof undefined unknown var void while with yield"))
      builtIns = words("Array BigInt Boolean Date Error Function JSON Map Math Number Object Promise Proxy Reflect RegExp Set String Symbol WeakMap WeakSet console document globalThis window")
      quotes.insert("`")
    case "java", "c", "cpp", "objectivec", "objective-c":
      keywords.formUnion(words("alignas auto boolean break byte case catch char class const constexpr continue default delete do double else enum explicit export extern final finally float for friend goto if implements import inline instanceof int interface long namespace native new noexcept operator package private protected public register requires return short signed sizeof static struct super switch synchronized template this throw throws transient try typedef typename union unsigned using virtual void volatile while"))
      builtIns = words("bool int8_t int16_t int32_t int64_t size_t uint8_t uint16_t uint32_t uint64_t nullptr NULL std")
    case "json":
      keywords = []
      lineComments = []
      blockComments = []
    case "bash", "shell", "sh", "zsh":
      keywords.formUnion(words("case do done elif else esac fi for function if in select then time until while"))
      builtIns = words("alias bg bind break builtin cd command continue declare echo enable eval exec exit export false getopts hash help history jobs kill let local logout mapfile popd printf pushd pwd read readonly return set shift source suspend test times trap true type typeset ulimit umask unalias unset wait")
      lineComments = ["#"]
      blockComments = []
      quotes.insert("`")
    case "sql":
      keywords = words("add all alter and any as asc backup between by case check column constraint create database default delete desc distinct drop exec exists foreign from full group having in index inner insert into is join key left like limit not null or order outer primary procedure right rownum select set table top truncate union unique update values view where")
      builtIns = words("avg count max min sum")
      lineComments = ["--"]
      caseInsensitive = true
    case "html", "xml", "svg":
      keywords = []
      lineComments = []
      blockComments = [("<!--", "-->")]
      markup = true
    case "css", "scss", "less":
      keywords = words("and from important media not only or supports to")
      builtIns = words("calc clamp hsl hsla max min rgb rgba url var")
    case "yaml", "yml":
      keywords = []
      lineComments = ["#"]
      blockComments = []
    default:
      keywords = []
      builtIns = []
      lineComments = []
      blockComments = []
    }
    return RufletHighlightLanguage(
      keywords: keywords, literals: commonLiterals, builtIns: builtIns,
      lineComments: lineComments, blockComments: blockComments,
      quoteCharacters: quotes, caseInsensitive: caseInsensitive, markup: markup)
  }

  private static let commonKeywords = words(
    "break continue else for if return switch throw try while")

  private static func words(_ value: String) -> Set<String> {
    Set(value.split(separator: " ").map(String.init))
  }

  private static func normalized(_ value: String) -> String {
    switch value.lowercased() {
    case "js", "jsx": return "javascript"
    case "ts", "tsx": return "typescript"
    case "py": return "python"
    case "rb": return "ruby"
    case "objc": return "objectivec"
    case "c++": return "cpp"
    default: return value.lowercased()
    }
  }

  private static func detect(_ source: String) -> String {
    let lower = source.lowercased()
    if lower.contains("<html") || lower.contains("</") { return "html" }
    if lower.contains("import swiftui") || lower.contains("func ") { return "swift" }
    if lower.contains("import 'package:") || lower.contains("widget build(") { return "dart" }
    if lower.contains("def ") && lower.contains(":") { return "python" }
    if lower.contains("def ") && lower.contains("\nend") { return "ruby" }
    if lower.contains("select ") && lower.contains(" from ") { return "sql" }
    if source.trimmingCharacters(in: .whitespacesAndNewlines).first == "{" { return "json" }
    return "plaintext"
  }
}

private struct RufletHighlightScanner {
  let source: String
  let profile: RufletHighlightLanguage
  private var index: String.Index
  private var tokens: [RufletHighlightToken] = []

  init(source: String, profile: RufletHighlightLanguage) {
    self.source = source
    self.profile = profile
    index = source.startIndex
  }

  mutating func scan() -> [RufletHighlightToken] {
    while index < source.endIndex {
      if let token = scanBlockComment() ?? scanLineComment() ?? scanString()
        ?? scanMarkup() ?? scanNumber() ?? scanIdentifier()
      {
        append(token)
      } else {
        let start = index
        index = source.index(after: index)
        append(.init(text: String(source[start..<index]), className: nil))
      }
    }
    return tokens
  }

  private mutating func scanBlockComment() -> RufletHighlightToken? {
    for (open, close) in profile.blockComments where source[index...].hasPrefix(open) {
      let start = index
      index = source.index(index, offsetBy: open.count)
      if let end = source[index...].range(of: close)?.upperBound { index = end }
      else { index = source.endIndex }
      return .init(text: String(source[start..<index]), className: "comment")
    }
    return nil
  }

  private mutating func scanLineComment() -> RufletHighlightToken? {
    guard profile.lineComments.contains(where: { source[index...].hasPrefix($0) }) else {
      return nil
    }
    let start = index
    index = source[index...].firstIndex(of: "\n") ?? source.endIndex
    return .init(text: String(source[start..<index]), className: "comment")
  }

  private mutating func scanString() -> RufletHighlightToken? {
    let quote = source[index]
    guard profile.quoteCharacters.contains(quote) else { return nil }
    let start = index
    index = source.index(after: index)
    var escaped = false
    while index < source.endIndex {
      let character = source[index]
      index = source.index(after: index)
      if escaped { escaped = false; continue }
      if character == "\\" { escaped = true; continue }
      if character == quote { break }
    }
    return .init(text: String(source[start..<index]), className: "string")
  }

  private mutating func scanMarkup() -> RufletHighlightToken? {
    guard profile.markup, source[index] == "<" else { return nil }
    let start = index
    index = source[index...].firstIndex(of: ">")
      .map { source.index(after: $0) } ?? source.endIndex
    return .init(text: String(source[start..<index]), className: "tag")
  }

  private mutating func scanNumber() -> RufletHighlightToken? {
    guard source[index].isNumber else { return nil }
    let start = index
    while index < source.endIndex {
      let character = source[index]
      guard character.isNumber || ".xXabcdefABCDEF_".contains(character) else { break }
      index = source.index(after: index)
    }
    return .init(text: String(source[start..<index]), className: "number")
  }

  private mutating func scanIdentifier() -> RufletHighlightToken? {
    let first = source[index]
    guard first.isLetter || first == "_" || first == "$" else { return nil }
    let start = index
    while index < source.endIndex {
      let character = source[index]
      guard character.isLetter || character.isNumber || character == "_" || character == "$" else {
        break
      }
      index = source.index(after: index)
    }
    let text = String(source[start..<index])
    let identity = profile.caseInsensitive ? text.lowercased() : text
    let className: String?
    if profile.keywords.contains(identity) { className = "keyword" }
    else if profile.literals.contains(identity.lowercased()) { className = "literal" }
    else if profile.builtIns.contains(identity) { className = "built_in" }
    else if text.first?.isUppercase == true { className = "type" }
    else if nextNonWhitespaceCharacter() == "(" { className = "title" }
    else { className = nil }
    return .init(text: text, className: className)
  }

  private func nextNonWhitespaceCharacter() -> Character? {
    var cursor = index
    while cursor < source.endIndex {
      let character = source[cursor]
      if !character.isWhitespace { return character }
      cursor = source.index(after: cursor)
    }
    return nil
  }

  private mutating func append(_ token: RufletHighlightToken) {
    if token.className == nil, !tokens.isEmpty, tokens.last?.className == nil {
      let previous = tokens.removeLast()
      tokens.append(.init(text: previous.text + token.text, className: nil))
    } else {
      tokens.append(token)
    }
  }
}
