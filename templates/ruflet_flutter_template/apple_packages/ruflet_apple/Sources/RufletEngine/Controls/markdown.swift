import Foundation
import Markdown
import RufletProtocol
import SwiftMath
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// Apple-native, file-for-file port of pinned Flet `MarkdownControl`.
@MainActor
public struct MarkdownControl: View {
  @ObservedObject private var control: RufletControl

  public init(control: RufletControl) {
    precondition(control.type == "Markdown")
    self.control = control
  }

  public var body: some View {
    let extensionSet =
      control.markdownExtensionSet(
        "extension_set", default: RufletMarkdownExtensionSet.none)
      ?? RufletMarkdownExtensionSet.none
    let blocks = RufletMarkdownParser(
      source: control.string("value", default: "") ?? "",
      extensionSet: extensionSet
    ).blocks
    let style = control.markdownStyleSheet("md_style_sheet")
    let codeStyle =
      control.markdownStyleSheet("code_style_sheet")
      ?? RufletMarkdownStyleSheet(
        values: ["code": ["font_family": "monospace"]], blockSpacing: 8,
        listIndent: 24, paragraphPadding: EdgeInsets())
    let renderer = RufletMarkdownRenderer(
      control: control,
      blocks: blocks,
      extensionSet: extensionSet,
      styleSheet: style,
      codeStyleSheet: codeStyle,
      codeTheme: RufletMarkdownTheme.styles(control.markdownCodeTheme("code_theme")),
      selectable: control.boolean("selectable", default: false),
      softLineBreak: control.boolean("soft_line_break", default: false),
      autoFollowLinks: control.boolean("auto_follow_links", default: false),
      autoFollowTarget: control.string("auto_follow_links_target"),
      latexStyle: parseTextStyle(control.dynamicValue("latex_style")),
      latexScale: control.number("latex_scale_factor") ?? 1
    )
    return LayoutControl(control: control) {
      renderer
        .frame(
          maxWidth: control.boolean("fit_content", default: true) ? nil : .infinity,
          alignment: .leading
        )
        .fixedSize(horizontal: false, vertical: control.boolean("shrink_wrap", default: true))
    }
  }
}

// MARK: - Exact semantic tree

struct RufletMarkdownParser {
  let blocks: [RufletMarkdownBlock]

  init(source: String, extensionSet: RufletMarkdownExtensionSet) {
    let document = Document(parsing: Self.normalizeLatexBlocks(source))
    blocks = document.children.compactMap { Self.block($0, extensionSet: extensionSet) }
  }

  private static func block(
    _ markup: any Markup, extensionSet: RufletMarkdownExtensionSet
  ) -> RufletMarkdownBlock? {
    switch markup {
    case let value as Heading:
      return .heading(value.level, inlines(value.children, extensionSet: extensionSet))
    case let value as Paragraph:
      return .paragraph(inlines(value.children, extensionSet: extensionSet))
    case let value as CodeBlock where value.language == "ruflet-latex":
      return .latex(value.code.trimmingCharacters(in: .whitespacesAndNewlines))
    case let value as CodeBlock:
      return .code(value.language ?? "", value.code.trimmingSuffix("\n"))
    case let value as BlockQuote:
      return .quote(value.children.compactMap { block($0, extensionSet: extensionSet) })
    case let value as UnorderedList:
      return .list(false, 1, value.children.compactMap { listItem($0, extensionSet: extensionSet) })
    case let value as OrderedList:
      return .list(
        true, Int(value.startIndex),
        value.children.compactMap { listItem($0, extensionSet: extensionSet) })
    case let value as Markdown.Table:
      if !extensionSet.includesGitHubExtensions {
        return .raw(Self.plain(value, separator: " | "))
      }
      let head = value.head.children.map { inlines($0.children, extensionSet: extensionSet) }
      let rows = value.body.children.map { row in
        row.children.map { inlines($0.children, extensionSet: extensionSet) }
      }
      return .table(head, rows)
    case is ThematicBreak: return .divider
    case let value as HTMLBlock: return .raw(value.rawHTML)
    default:
      let nested = markup.children.compactMap { block($0, extensionSet: extensionSet) }
      return nested.isEmpty ? nil : .group(nested)
    }
  }

  private static func listItem(
    _ markup: any Markup, extensionSet: RufletMarkdownExtensionSet
  ) -> RufletMarkdownListItem? {
    guard let item = markup as? ListItem else { return nil }
    let checked: Bool?
    if !extensionSet.includesGitHubExtensions {
      checked = nil
    } else {
      switch item.checkbox {
      case .checked: checked = true
      case .unchecked: checked = false
      case nil: checked = nil
      }
    }
    return RufletMarkdownListItem(
      checked: checked,
      blocks: item.children.compactMap { block($0, extensionSet: extensionSet) })
  }

  private static func inlines(
    _ children: MarkupChildren,
    traits: RufletMarkdownTraits = [],
    link: RufletMarkdownLink? = nil,
    extensionSet: RufletMarkdownExtensionSet
  ) -> [RufletMarkdownInline] {
    children.flatMap { child -> [RufletMarkdownInline] in
      switch child {
      case let value as Markdown.Text:
        return splitLatex(value.string).map {
          switch $0 {
          case .text(let text): return .text(text, traits, link)
          case .latex(let formula): return .latex(formula, traits)
          }
        }
      case let value as InlineCode: return [.text(value.code, traits.union(.code), link)]
      case let value as Strong:
        return inlines(
          value.children, traits: traits.union(.strong), link: link, extensionSet: extensionSet)
      case let value as Emphasis:
        return inlines(
          value.children, traits: traits.union(.emphasis), link: link, extensionSet: extensionSet)
      case let value as Strikethrough:
        let contents = inlines(
          value.children, traits: traits.union(.strike), link: link, extensionSet: extensionSet)
        return !extensionSet.includesGitHubExtensions
          ? [.text("~~", traits, link)] + contents + [.text("~~", traits, link)] : contents
      case let value as Markdown.Link:
        let destination = value.destination ?? ""
        return inlines(
          value.children, traits: traits,
          link: RufletMarkdownLink(destination: destination, title: value.title ?? ""),
          extensionSet: extensionSet)
      case let value as Markdown.Image:
        return [.image(value.source ?? "", plain(value), value.title ?? "")]
      case is LineBreak: return [.break(true)]
      case is SoftBreak: return [.break(false)]
      case let value as InlineHTML: return [.text(value.rawHTML, traits, link)]
      default:
        return inlines(child.children, traits: traits, link: link, extensionSet: extensionSet)
      }
    }
  }

  private enum LatexPiece {
    case text(String)
    case latex(String)
  }

  private static func splitLatex(_ value: String) -> [LatexPiece] {
    var result: [LatexPiece] = []
    var text = ""
    var formula = ""
    var inside = false
    var escaped = false
    for character in value {
      if escaped {
        if inside { formula.append(character) } else { text.append(character) }
        escaped = false
      } else if character == "\\" {
        escaped = true
        if inside { formula.append(character) } else { text.append(character) }
      } else if character == "$" {
        if inside {
          result.append(.latex(formula))
          formula = ""
        } else if !text.isEmpty {
          result.append(.text(text))
          text = ""
        }
        inside.toggle()
      } else {
        if inside { formula.append(character) } else { text.append(character) }
      }
    }
    if inside { text += "$" + formula }
    if !text.isEmpty { result.append(.text(text)) }
    return result
  }

  static func normalizeLatexBlocks(_ source: String) -> String {
    var output: [String] = []
    var formula: [String]? = nil
    for line in source.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if formula == nil, trimmed.hasPrefix("$$") {
        let remainder = String(trimmed.dropFirst(2))
        if remainder.hasSuffix("$$") {
          output += ["```ruflet-latex", String(remainder.dropLast(2)), "```"]
        } else {
          formula = remainder.isEmpty ? [] : [remainder]
        }
      } else if formula != nil, trimmed.hasSuffix("$$") {
        formula?.append(String(trimmed.dropLast(2)))
        output += ["```ruflet-latex", formula!.joined(separator: "\n"), "```"]
        formula = nil
      } else if formula != nil {
        formula?.append(line)
      } else {
        output.append(line)
      }
    }
    if let formula { output += ["$$", formula.joined(separator: "\n")] }
    return output.joined(separator: "\n")
  }

  private static func plain(_ markup: any Markup, separator: String = "") -> String {
    if let text = markup as? Markdown.Text { return text.string }
    if let code = markup as? InlineCode { return code.code }
    return markup.children.map { plain($0, separator: separator) }.joined(separator: separator)
  }
}

indirect enum RufletMarkdownBlock: Equatable {
  case heading(Int, [RufletMarkdownInline])
  case paragraph([RufletMarkdownInline])
  case code(String, String)
  case latex(String)
  case quote([RufletMarkdownBlock])
  case list(Bool, Int, [RufletMarkdownListItem])
  case table([[RufletMarkdownInline]], [[[RufletMarkdownInline]]])
  case divider
  case raw(String)
  case group([RufletMarkdownBlock])
}

struct RufletMarkdownListItem: Equatable {
  let checked: Bool?
  let blocks: [RufletMarkdownBlock]
}

enum RufletMarkdownInline: Equatable {
  case text(String, RufletMarkdownTraits, RufletMarkdownLink?)
  case latex(String, RufletMarkdownTraits)
  case image(String, String, String)
  case `break`(Bool)
}

struct RufletMarkdownLink: Equatable {
  let destination: String
  let title: String
}

struct RufletMarkdownTraits: OptionSet, Equatable, Sendable {
  let rawValue: Int
  static let strong = Self(rawValue: 1 << 0)
  static let emphasis = Self(rawValue: 1 << 1)
  static let strike = Self(rawValue: 1 << 2)
  static let code = Self(rawValue: 1 << 3)
}

// MARK: - Native Apple rendering

@MainActor
struct RufletMarkdownRenderer: View {
  @ObservedObject var control: RufletControl
  let blocks: [RufletMarkdownBlock]
  let extensionSet: RufletMarkdownExtensionSet
  let styleSheet: RufletMarkdownStyleSheet?
  let codeStyleSheet: RufletMarkdownStyleSheet
  let codeTheme: [String: RufletTextStyle]
  let selectable: Bool
  let softLineBreak: Bool
  let autoFollowLinks: Bool
  let autoFollowTarget: String?
  let latexStyle: RufletTextStyle?
  let latexScale: Double

  var body: some View {
    VStack(alignment: .leading, spacing: styleSheet?.blockSpacing ?? 8) {
      ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in AnyView(blockView(block)) }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func blockView(_ block: RufletMarkdownBlock) -> AnyView {
    switch block {
    case .heading(let level, let inlines):
      return AnyView(rich(inlines, key: "h\(level)", defaultSize: max(16, 34 - Double(level) * 3)))
    case .paragraph(let inlines):
      return AnyView(
        inlineContent(inlines, key: "p", defaultSize: 16)
          .padding(styleSheet?.paragraphPadding ?? EdgeInsets()))
    case .code(let language, let source):
      return AnyView(
        HighlightView(
          source, language: language, theme: codeTheme,
          padding: codeStyleSheet.padding(
            "codeblock_padding", EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)),
          decoration: RufletHighlightDecoration(
            borderRadius: rufletDictionary(codeStyleSheet.values["codeblock_decoration"])
              .flatMap { parseBorderRadius($0["border_radius"]) }),
          textStyle: codeStyleSheet.textStyle("code"), selectable: selectable))
    case .latex(let formula):
      return AnyView(
        RufletMathView(formula: formula, display: true, style: latexStyle, scale: latexScale))
    case .quote(let nested):
      return AnyView(
        HStack(alignment: .top, spacing: 10) {
          Rectangle().fill(Color.secondary.opacity(0.5)).frame(width: 3)
          nestedBlocks(nested)
        }
        .padding(styleSheet?.padding("blockquote_padding") ?? EdgeInsets()))
    case .list(let ordered, let start, let items):
      return AnyView(
        VStack(alignment: .leading, spacing: 6) {
          ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
            HStack(alignment: .top, spacing: 8) {
              if let checked = item.checked {
                SwiftUI.Image(systemName: checked ? "checkmark.square.fill" : "square")
                  .accessibilityLabel(checked ? "Checked" : "Unchecked")
              } else {
                SwiftUI.Text(ordered ? "\(start + offset)." : "•")
              }
              nestedBlocks(item.blocks)
            }
          }
        }
        .padding(.leading, styleSheet.map { CGFloat($0.listIndent) } ?? 24))
    case .table(let head, let rows):
      return AnyView(
        VStack(spacing: 0) {
          tableRow(head, bold: true)
          ForEach(Array(rows.enumerated()), id: \.offset) { _, row in tableRow(row, bold: false) }
        }
        .overlay(Rectangle().stroke(Color.secondary.opacity(0.35), lineWidth: 1)))
    case .divider: return AnyView(Divider())
    case .raw(let text): return AnyView(rich([.text(text, [], nil)], key: "p", defaultSize: 16))
    case .group(let nested): return AnyView(nestedBlocks(nested))
    }
  }

  private func tableRow(_ cells: [[RufletMarkdownInline]], bold: Bool) -> some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(Array(cells.enumerated()), id: \.offset) { _, inlines in
        rich(
          bold ? inlines.map { $0.adding(.strong) } : inlines,
          key: bold ? "th" : "td", defaultSize: 14
        )
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
      }
    }
  }

  private func nestedBlocks(_ values: [RufletMarkdownBlock]) -> some View {
    VStack(alignment: .leading, spacing: styleSheet?.blockSpacing ?? 8) {
      ForEach(Array(values.enumerated()), id: \.offset) { _, item in AnyView(blockView(item)) }
    }
  }

  @ViewBuilder
  private func inlineContent(_ inlines: [RufletMarkdownInline], key: String, defaultSize: Double)
    -> some View
  {
    let groups = RufletMarkdownInlineGroup.split(inlines)
    VStack(alignment: .leading, spacing: 4) {
      ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
        switch group {
        case .text(let values): rich(values, key: key, defaultSize: defaultSize)
        case .image(let source, let alt, _):
          if let image = parseImageSource(source, backend: control.backend) {
            RufletImageSourceView(
              source: image, contentMode: .fit, onError: nil,
              errorContent: control.child("image_error_content").map {
                AnyView(ControlWidget(control: $0))
              }
            )
            .accessibilityLabel(alt)
          }
        }
      }
    }
  }

  private func rich(_ inlines: [RufletMarkdownInline], key: String, defaultSize: Double)
    -> some View
  {
    RufletMarkdownNativeText(
      attributed: RufletMarkdownAttributedString.build(
        inlines, style: styleSheet?.textStyle(key), defaultSize: defaultSize,
        softLineBreak: softLineBreak, latexStyle: latexStyle, latexScale: latexScale),
      selectable: selectable,
      onSelection: { text, range in
        control.triggerEvent(
          "selection_change", data: Self.selectionPayload(text: text, range: range))
      },
      onTapText: { control.triggerEvent("tap_text") },
      onTapLink: { destination in
        if autoFollowLinks {
          Task { await openURL(RufletURL(destination, autoFollowTarget)) }
        }
        control.triggerEvent("tap_link", data: .string(destination))
      })
  }

  static func selectionPayload(text: String, range: NSRange) -> RufletValue {
    let selection = (text as NSString).substring(
      with: NSIntersectionRange(range, NSRange(location: 0, length: (text as NSString).length)))
    return .map([
      "text": .string(selection), "cause": .string("unknown"),
      "selection": .map([
        "start": .int(Int64(range.location)), "end": .int(Int64(range.location + range.length)),
        "selection": .string(selection), "base_offset": .int(Int64(range.location)),
        "extent_offset": .int(Int64(range.location + range.length)),
        "affinity": .string("downstream"),
        "directional": .bool(false), "collapsed": .bool(range.length == 0),
        "valid": .bool(range.location != NSNotFound),
        "normalized": .bool(true),
      ]),
    ])
  }
}

extension RufletMarkdownInline {
  fileprivate func adding(_ trait: RufletMarkdownTraits) -> Self {
    switch self {
    case .text(let value, let traits, let link): return .text(value, traits.union(trait), link)
    case .latex(let value, let traits): return .latex(value, traits.union(trait))
    default: return self
    }
  }
}

private enum RufletMarkdownInlineGroup {
  case text([RufletMarkdownInline])
  case image(String, String, String)

  static func split(_ inlines: [RufletMarkdownInline]) -> [Self] {
    var groups: [Self] = []
    var text: [RufletMarkdownInline] = []
    for item in inlines {
      if case .image(let source, let alt, let title) = item {
        if !text.isEmpty {
          groups.append(.text(text))
          text = []
        }
        groups.append(.image(source, alt, title))
      } else {
        text.append(item)
      }
    }
    if !text.isEmpty { groups.append(.text(text)) }
    return groups
  }
}

private enum RufletMarkdownAttributedString {
  static func build(
    _ inlines: [RufletMarkdownInline], style: RufletTextStyle?, defaultSize: Double,
    softLineBreak: Bool, latexStyle: RufletTextStyle?, latexScale: Double
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for item in inlines {
      switch item {
      case .text(let value, let traits, let link):
        let rangeStart = result.length
        result.append(
          NSAttributedString(string: value, attributes: attributes(style, traits, defaultSize)))
        if let link, !link.destination.isEmpty {
          result.addAttribute(
            .link, value: link.destination,
            range: NSRange(location: rangeStart, length: result.length - rangeStart))
        }
      case .latex(let formula, _):
        if let attachment = mathAttachment(
          formula, style: latexStyle ?? style, size: defaultSize, scale: latexScale,
          display: false)
        {
          result.append(NSAttributedString(attachment: attachment))
        } else {
          result.append(
            NSAttributedString(string: formula, attributes: attributes(style, [], defaultSize)))
        }
      case .break(let hard):
        result.append(NSAttributedString(string: hard || softLineBreak ? "\n" : " "))
      case .image: break
      }
    }
    return result
  }

  private static func attributes(
    _ style: RufletTextStyle?, _ traits: RufletMarkdownTraits, _ defaultSize: Double
  ) -> [NSAttributedString.Key: Any] {
    let size = CGFloat(style?.size ?? defaultSize)
    #if os(iOS)
      var font =
        style?.fontFamily.flatMap { UIFont(name: $0, size: size) }
        ?? UIFont.systemFont(ofSize: size)
      var symbolic = font.fontDescriptor.symbolicTraits
      if traits.contains(.strong) { symbolic.insert(.traitBold) }
      if traits.contains(.emphasis) || style?.italic == true { symbolic.insert(.traitItalic) }
      if traits.contains(.code) {
        font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
      } else if let descriptor = font.fontDescriptor.withSymbolicTraits(symbolic) {
        font = UIFont(descriptor: descriptor, size: size)
      }
      var attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: UIColor(style?.color ?? .primary),
      ]
      if let background = style?.backgroundColor {
        attributes[.backgroundColor] = UIColor(background)
      }
    #elseif os(macOS)
      var font =
        style?.fontFamily.flatMap { NSFont(name: $0, size: size) }
        ?? NSFont.systemFont(ofSize: size)
      if traits.contains(.code) {
        font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
      } else {
        if traits.contains(.strong) {
          font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if traits.contains(.emphasis) || style?.italic == true {
          font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
      }
      var attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor(style?.color ?? .primary),
      ]
      if let background = style?.backgroundColor {
        attributes[.backgroundColor] = NSColor(background)
      }
    #endif
    if traits.contains(.strike) || (style?.decoration ?? 0) & 0x4 != 0 {
      attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }
    if (style?.decoration ?? 0) & 0x1 != 0 {
      attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
    }
    if let spacing = style?.letterSpacing { attributes[.kern] = spacing }
    return attributes
  }

  static func mathAttachment(
    _ formula: String, style: RufletTextStyle?, size: Double, scale: Double,
    display: Bool
  ) -> NSTextAttachment? {
    #if os(iOS)
      let color = style?.color.map { UIColor($0) } ?? UIColor.label
    #elseif os(macOS)
      let color = style?.color.map { NSColor($0) } ?? NSColor.textColor
    #endif
    var renderer = MathImage(
      latex: formula, fontSize: CGFloat((style?.size ?? size) * scale),
      textColor: color, labelMode: display ? .display : .text, textAlignment: .left)
    let (_, image, layout) = renderer.asImage()
    guard let image else { return nil }
    let attachment = NSTextAttachment()
    attachment.image = image
    attachment.bounds = CGRect(
      x: 0, y: -(layout?.descent ?? 0), width: image.size.width, height: image.size.height)
    return attachment
  }
}

private enum RufletMarkdownTheme {
  static func styles(_ value: RufletMarkdownCodeTheme?) -> [String: RufletTextStyle] {
    if case .styles(let styles) = value { return styles }
    let dark: Bool
    if case .named(let name) = value {
      dark = ["dark", "monokai", "dracula", "nord", "obsidian", "atom-one-dark", "github-dark"]
        .contains { name.contains($0) }
    } else {
      dark = false
    }
    func style(
      _ color: String, background: String? = nil, weight: String? = nil, italic: Bool = false
    ) -> RufletTextStyle {
      parseTextStyle([
        "color": color, "bgcolor": background as Any, "weight": weight as Any, "italic": italic,
      ])!
    }
    return [
      "root": style(dark ? "#F8F8F2" : "#24292E", background: dark ? "#282A36" : "#F6F8FA"),
      "keyword": style(dark ? "#FF79C6" : "#D73A49", weight: "bold"),
      "string": style(dark ? "#F1FA8C" : "#032F62"),
      "number": style(dark ? "#BD93F9" : "#005CC5"),
      "comment": style(dark ? "#6272A4" : "#6A737D", italic: true),
      "built_in": style(dark ? "#8BE9FD" : "#6F42C1"),
      "title": style(dark ? "#50FA7B" : "#6F42C1"),
    ]
  }
}

private struct RufletMathView: View {
  let formula: String
  let display: Bool
  let style: RufletTextStyle?
  let scale: Double

  var body: some View {
    if let attachment = RufletMarkdownAttributedString.mathAttachment(
      formula, style: style, size: 16, scale: scale, display: display),
      let image = attachment.image
    {
      #if os(iOS)
        SwiftUI.Image(uiImage: image).accessibilityLabel(formula)
      #elseif os(macOS)
        SwiftUI.Image(nsImage: image).accessibilityLabel(formula)
      #endif
    } else {
      SwiftUI.Text(formula)
    }
  }
}

// MARK: - Native selectable/link text

#if os(iOS)
  private struct RufletMarkdownNativeText: UIViewRepresentable {
    let attributed: NSAttributedString
    let selectable: Bool
    let onSelection: (String, NSRange) -> Void
    let onTapText: () -> Void
    let onTapLink: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> RufletMarkdownTextView {
      let view = RufletMarkdownTextView()
      view.delegate = context.coordinator
      view.backgroundColor = .clear
      view.isEditable = false
      view.isScrollEnabled = false
      view.textContainerInset = .zero
      view.textContainer.lineFragmentPadding = 0
      view.adjustsFontForContentSizeCategory = true
      view.addGestureRecognizer(
        UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))))
      return view
    }
    func updateUIView(_ view: RufletMarkdownTextView, context: Context) {
      context.coordinator.parent = self
      if !view.attributedText.isEqual(to: attributed) { view.attributedText = attributed }
      view.isSelectable = selectable || attributed.containsLinks
      view.invalidateIntrinsicContentSize()
    }
    final class Coordinator: NSObject, UITextViewDelegate {
      var parent: RufletMarkdownNativeText
      init(_ parent: RufletMarkdownNativeText) { self.parent = parent }
      func textViewDidChangeSelection(_ textView: UITextView) {
        guard parent.selectable else { return }
        parent.onSelection(textView.text, textView.selectedRange)
      }
      func textView(
        _ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange,
        interaction: UITextItemInteraction
      ) -> Bool {
        parent.onTapLink(url.absoluteString)
        return false
      }
      @objc func tap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view as? UITextView else { return }
        let point = recognizer.location(in: view)
        let index = view.layoutManager.characterIndex(
          for: CGPoint(
            x: point.x - view.textContainerInset.left, y: point.y - view.textContainerInset.top),
          in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        guard
          index >= view.attributedText.length
            || view.attributedText.attribute(.link, at: index, effectiveRange: nil) == nil
        else { return }
        parent.onTapText()
      }
    }
  }

  private final class RufletMarkdownTextView: UITextView {
    override var intrinsicContentSize: CGSize {
      CGSize(
        width: UIView.noIntrinsicMetric,
        height: sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height)
    }
    override func layoutSubviews() {
      super.layoutSubviews()
      invalidateIntrinsicContentSize()
    }
  }
#elseif os(macOS)
  private struct RufletMarkdownNativeText: NSViewRepresentable {
    let attributed: NSAttributedString
    let selectable: Bool
    let onSelection: (String, NSRange) -> Void
    let onTapText: () -> Void
    let onTapLink: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> RufletMarkdownTextView {
      let view = RufletMarkdownTextView()
      view.delegate = context.coordinator
      view.drawsBackground = false
      view.isEditable = false
      view.isRichText = true
      view.textContainerInset = .zero
      view.textContainer?.lineFragmentPadding = 0
      view.onTapText = onTapText
      return view
    }
    func updateNSView(_ view: RufletMarkdownTextView, context: Context) {
      context.coordinator.parent = self
      if !view.attributedString().isEqual(to: attributed) {
        view.textStorage?.setAttributedString(attributed)
      }
      view.isSelectable = selectable || attributed.containsLinks
      view.onTapText = onTapText
      view.invalidateIntrinsicContentSize()
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
      var parent: RufletMarkdownNativeText
      init(_ parent: RufletMarkdownNativeText) { self.parent = parent }
      func textViewDidChangeSelection(_ notification: Notification) {
        guard parent.selectable, let view = notification.object as? NSTextView else { return }
        parent.onSelection(view.string, view.selectedRange())
      }
      func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        parent.onTapLink((link as? URL)?.absoluteString ?? String(describing: link))
        return true
      }
    }
  }

  private final class RufletMarkdownTextView: NSTextView {
    var onTapText: (() -> Void)?
    override var intrinsicContentSize: NSSize {
      guard let container = textContainer, let manager = layoutManager else {
        return super.intrinsicContentSize
      }
      container.containerSize = NSSize(
        width: max(bounds.width, 1), height: .greatestFiniteMagnitude)
      manager.ensureLayout(for: container)
      return NSSize(
        width: NSView.noIntrinsicMetric, height: manager.usedRect(for: container).height)
    }
    override func mouseDown(with event: NSEvent) {
      let point = convert(event.locationInWindow, from: nil)
      if let container = textContainer, let manager = layoutManager {
        let index = manager.characterIndex(
          for: point, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
        if index >= string.utf16.count
          || attributedString().attribute(.link, at: index, effectiveRange: nil) == nil
        {
          onTapText?()
        }
      }
      super.mouseDown(with: event)
    }
  }
#endif

extension NSAttributedString {
  fileprivate var containsLinks: Bool {
    var found = false
    enumerateAttribute(.link, in: NSRange(location: 0, length: length)) { value, _, stop in
      if value != nil {
        found = true
        stop.pointee = true
      }
    }
    return found
  }
}

extension String {
  fileprivate func trimmingSuffix(_ suffix: String) -> String {
    hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
  }
}
