import Foundation
import SwiftUI

#if canImport(UIKit)
  import UIKit

  /// Native highlighted text storage for Ruflet's `CodeEditor` on iOS.
  struct HighlightedCodeTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    @Binding var selection: NSRange
    let configuration: CodeEditorConfiguration
    let editable: Bool
    let focusable: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
      let view = UITextView()
      view.delegate = context.coordinator
      view.autocorrectionType = .no
      view.autocapitalizationType = .none
      view.smartDashesType = .no
      view.smartQuotesType = .no
      view.smartInsertDeleteType = .no
      view.alwaysBounceVertical = true
      view.alwaysBounceHorizontal = true
      view.textContainerInset = UIEdgeInsets(
        top: configuration.editorInsets.top,
        left: configuration.editorInsets.leading,
        bottom: configuration.editorInsets.bottom,
        right: configuration.editorInsets.trailing)
      view.textContainer.lineFragmentPadding = 0
      update(view, coordinator: context.coordinator)
      return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
      context.coordinator.parent = self
      update(view, coordinator: context.coordinator)
      if focused, !view.isFirstResponder, focusable { view.becomeFirstResponder() }
      if !focused, view.isFirstResponder { view.resignFirstResponder() }
      let resolvedSelection = clamped(selection, length: text.utf16.count)
      if !context.coordinator.applying, view.selectedRange != resolvedSelection {
        context.coordinator.applying = true
        view.selectedRange = resolvedSelection
        context.coordinator.applying = false
      }
    }

    private func update(_ view: UITextView, coordinator: Coordinator) {
      view.isEditable = editable
      view.isSelectable = true
      view.isUserInteractionEnabled = !configuration.disabled
      view.backgroundColor = CodeSyntaxHighlighter.uiBackground(configuration)
      if view.text != text || coordinator.lastConfiguration != configuration {
        coordinator.applyHighlight(to: view, text: text, configuration: configuration)
      }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
      var parent: HighlightedCodeTextView
      var applying = false
      var lastConfiguration: CodeEditorConfiguration?

      init(_ parent: HighlightedCodeTextView) { self.parent = parent }

      func textViewDidChange(_ textView: UITextView) {
        guard !applying else { return }
        parent.text = textView.text
        applyHighlight(to: textView, text: textView.text, configuration: parent.configuration)
      }

      func textViewDidBeginEditing(_ textView: UITextView) { parent.focused = true }
      func textViewDidEndEditing(_ textView: UITextView) { parent.focused = false }
      func textViewDidChangeSelection(_ textView: UITextView) {
        guard !applying else { return }
        parent.selection = textView.selectedRange
      }

      func applyHighlight(to view: UITextView, text: String, configuration: CodeEditorConfiguration) {
        applying = true
        let selection = view.selectedRange
        view.attributedText = CodeSyntaxHighlighter.attributed(text, configuration: configuration)
        let textLength = text.utf16.count
        let location = min(selection.location, textLength)
        view.selectedRange = NSRange(location: location, length: min(selection.length, textLength - location))
        view.typingAttributes = CodeSyntaxHighlighter.baseAttributes(configuration)
        lastConfiguration = configuration
        applying = false
      }
    }
  }
#elseif canImport(AppKit)
  import AppKit

  struct HighlightedCodeTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    @Binding var selection: NSRange
    let configuration: CodeEditorConfiguration
    let editable: Bool
    let focusable: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
      let scroll = NSScrollView()
      scroll.hasVerticalScroller = true
      scroll.hasHorizontalScroller = true
      scroll.autohidesScrollers = true
      scroll.borderType = .noBorder
      let view = NSTextView()
      view.delegate = context.coordinator
      view.isRichText = false
      view.isAutomaticQuoteSubstitutionEnabled = false
      view.isAutomaticDashSubstitutionEnabled = false
      view.isAutomaticTextReplacementEnabled = false
      view.textContainerInset = NSSize(
        width: configuration.editorInsets.leading,
        height: configuration.editorInsets.top)
      view.isHorizontallyResizable = true
      view.isVerticallyResizable = true
      view.textContainer?.widthTracksTextView = false
      view.textContainer?.containerSize = NSSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude)
      scroll.documentView = view
      update(view, coordinator: context.coordinator)
      return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
      guard let view = scroll.documentView as? NSTextView else { return }
      context.coordinator.parent = self
      update(view, coordinator: context.coordinator)
      if focused, focusable, view.window?.firstResponder !== view { view.window?.makeFirstResponder(view) }
      if !focused, view.window?.firstResponder === view { view.window?.makeFirstResponder(nil) }
      let resolvedSelection = clamped(selection, length: text.utf16.count)
      if !context.coordinator.applying,
        view.selectedRange() != resolvedSelection
      {
        context.coordinator.applying = true
        view.setSelectedRange(resolvedSelection)
        context.coordinator.applying = false
      }
    }

    private func update(_ view: NSTextView, coordinator: Coordinator) {
      view.isEditable = editable
      view.isSelectable = true
      view.isSelectable = !configuration.disabled
      view.backgroundColor = CodeSyntaxHighlighter.nsBackground(configuration)
      if view.string != text || coordinator.lastConfiguration != configuration {
        coordinator.applyHighlight(to: view, text: text, configuration: configuration)
      }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
      var parent: HighlightedCodeTextView
      var applying = false
      var lastConfiguration: CodeEditorConfiguration?

      init(_ parent: HighlightedCodeTextView) { self.parent = parent }

      func textDidChange(_ notification: Notification) {
        guard !applying, let view = notification.object as? NSTextView else { return }
        parent.text = view.string
        applyHighlight(to: view, text: view.string, configuration: parent.configuration)
      }

      func textDidBeginEditing(_ notification: Notification) { parent.focused = true }
      func textDidEndEditing(_ notification: Notification) { parent.focused = false }
      func textViewDidChangeSelection(_ notification: Notification) {
        guard !applying, let view = notification.object as? NSTextView else { return }
        parent.selection = view.selectedRange()
      }

      func applyHighlight(to view: NSTextView, text: String, configuration: CodeEditorConfiguration) {
        applying = true
        let selections = view.selectedRanges
        view.textStorage?.setAttributedString(CodeSyntaxHighlighter.attributed(text, configuration: configuration))
        let textLength = text.utf16.count
        view.selectedRanges = selections.map { value in
          let range = value.rangeValue
          let location = min(range.location, textLength)
          return NSValue(range: NSRange(location: location, length: min(range.length, textLength - location)))
        }
        view.typingAttributes = CodeSyntaxHighlighter.baseAttributes(configuration)
        lastConfiguration = configuration
        applying = false
      }
    }
  }
#endif

enum CodeSyntaxHighlighter {
  static func attributed(_ source: String, configuration: CodeEditorConfiguration) -> NSAttributedString {
    let output = NSMutableAttributedString(string: source, attributes: baseAttributes(configuration))
    let full = NSRange(source.startIndex..<source.endIndex, in: source)
    var protected: [NSRange] = []

    func paint(_ pattern: String, color: Any, protects: Bool = false) {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
      for match in regex.matches(in: source, range: full).reversed() {
        guard !protected.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { continue }
        #if canImport(UIKit)
          output.addAttribute(.foregroundColor, value: color as! UIColor, range: match.range)
        #elseif canImport(AppKit)
          output.addAttribute(.foregroundColor, value: color as! NSColor, range: match.range)
        #endif
        if protects { protected.append(match.range) }
      }
    }

    let syntax = CodeLanguageSyntax.resolve(configuration.language)
    paint(syntax.stringPattern, color: syntaxColor(.string, configuration), protects: true)
    for comment in syntax.commentPatterns {
      paint(comment, color: syntaxColor(.comment, configuration), protects: true)
    }
    if !syntax.keywords.isEmpty {
      let words = syntax.keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
      paint("\\b(?:\(words))\\b", color: syntaxColor(.keyword, configuration))
    }
    paint(#"\b[A-Z][A-Za-z0-9_]*\b"#, color: syntaxColor(.constant, configuration))
    paint(#"\b\d+(?:\.\d+)?\b"#, color: syntaxColor(.number, configuration))
    return output
  }

  static func baseAttributes(_ configuration: CodeEditorConfiguration) -> [NSAttributedString.Key: Any] {
    #if canImport(UIKit)
      let font = configuration.fontFamily.flatMap { UIFont(name: $0, size: configuration.fontSize) }
        ?? UIFont.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
      let explicit = configuration.textStyle["color"]?.stringValue
        .flatMap(MaterialPalette.color).map(UIColor.init)
      return [.font: font, .foregroundColor: explicit ?? uiColor(.plain, configuration)]
    #elseif canImport(AppKit)
      let font = configuration.fontFamily.flatMap { NSFont(name: $0, size: configuration.fontSize) }
        ?? NSFont.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
      let explicit = configuration.textStyle["color"]?.stringValue
        .flatMap(MaterialPalette.color).map(NSColor.init)
      return [.font: font, .foregroundColor: explicit ?? nsColor(.plain, configuration)]
    #else
      return [:]
    #endif
  }

  enum Token { case plain, comment, string, keyword, symbol, constant, number }

  private static func syntaxColor(_ token: Token, _ configuration: CodeEditorConfiguration) -> Any {
    #if canImport(UIKit)
      return uiColor(token, configuration)
    #elseif canImport(AppKit)
      return nsColor(token, configuration)
    #else
      return 0
    #endif
  }

  #if canImport(UIKit)
    static func uiBackground(_ configuration: CodeEditorConfiguration) -> UIColor {
      configuration.dark ? UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1) : .white
    }

    private static func uiColor(_ token: Token, _ configuration: CodeEditorConfiguration) -> UIColor {
      if let name = customColorToken(token, configuration), let color = MaterialPalette.color(name) {
        return UIColor(color)
      }
      let rgb = components(token, dark: configuration.dark)
      return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
  #endif

  #if canImport(AppKit)
    static func nsBackground(_ configuration: CodeEditorConfiguration) -> NSColor {
      configuration.dark ? NSColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1) : .textBackgroundColor
    }

    private static func nsColor(_ token: Token, _ configuration: CodeEditorConfiguration) -> NSColor {
      if let name = customColorToken(token, configuration), let color = MaterialPalette.color(name) {
        return NSColor(color)
      }
      let rgb = components(token, dark: configuration.dark)
      return NSColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
  #endif

  private static func components(_ token: Token, dark: Bool) -> (CGFloat, CGFloat, CGFloat) {
    if dark {
      switch token {
      case .plain: return (0.67, 0.70, 0.75)
      case .comment: return (0.36, 0.39, 0.44)
      case .string: return (0.60, 0.76, 0.47)
      case .keyword: return (0.78, 0.47, 0.87)
      case .symbol: return (0.34, 0.71, 0.76)
      case .constant: return (0.38, 0.69, 0.94)
      case .number: return (0.82, 0.60, 0.40)
      }
    }
    switch token {
    case .plain: return (0.20, 0.22, 0.25)
    case .comment: return (0.50, 0.53, 0.57)
    case .string: return (0.25, 0.55, 0.20)
    case .keyword: return (0.64, 0.19, 0.64)
    case .symbol: return (0.08, 0.49, 0.58)
    case .constant: return (0.10, 0.36, 0.73)
    case .number: return (0.72, 0.35, 0.12)
    }
  }

  private static func customColorToken(
    _ token: Token, _ configuration: CodeEditorConfiguration
  ) -> String? {
    let key: String
    switch token {
    case .plain: key = "root"
    case .comment: key = "comment"
    case .string: key = "string"
    case .keyword: key = "keyword"
    case .symbol: key = "symbol"
    case .constant: key = "class"
    case .number: key = "number"
    }
    return configuration.themeStyles[key]?.mapValue?["color"]?.stringValue
      ?? configuration.themeStyles[key]?.stringValue
  }
}

struct CodeLanguageSyntax: Equatable {
  let keywords: [String]
  let commentPatterns: [String]
  let stringPattern: String

  static func resolve(_ language: String) -> CodeLanguageSyntax {
    let slashComments = [#"//[^\n]*"#, #"/\*[\s\S]*?\*/"#]
    let hashComments = [#"#[^\n]*"#]
    switch language.lowercased() {
    case "ruby", "rb", "erb":
      return CodeLanguageSyntax(
        keywords: ["class", "module", "def", "end", "do", "if", "else", "elsif", "unless", "while", "until", "case", "when", "then", "begin", "rescue", "ensure", "yield", "return", "require", "include", "extend", "true", "false", "nil", "self"],
        commentPatterns: hashComments,
        stringPattern: #"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#)
    case "python", "py":
      return CodeLanguageSyntax(
        keywords: ["and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else", "except", "False", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "None", "not", "or", "pass", "raise", "return", "True", "try", "while", "with", "yield"],
        commentPatterns: hashComments,
        stringPattern: #"(?s:\"\"\".*?\"\"\"|'''.*?'''|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')"#)
    case "swift":
      return CodeLanguageSyntax(
        keywords: ["actor", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue", "default", "defer", "do", "else", "enum", "extension", "fallthrough", "false", "for", "func", "guard", "if", "import", "in", "init", "let", "nil", "protocol", "repeat", "return", "self", "static", "struct", "subscript", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while"],
        commentPatterns: slashComments,
        stringPattern: #"\"(?:\\.|[^\"\\])*\""#)
    case "javascript", "typescript", "js", "ts", "dart", "java", "kotlin", "c", "cpp", "cs", "go":
      return CodeLanguageSyntax(
        keywords: ["abstract", "async", "await", "break", "case", "catch", "class", "const", "continue", "default", "do", "else", "enum", "export", "extends", "false", "final", "finally", "for", "function", "if", "import", "in", "interface", "let", "new", "nil", "null", "package", "private", "protected", "public", "return", "static", "struct", "super", "switch", "this", "throw", "true", "try", "var", "void", "while"],
        commentPatterns: slashComments,
        stringPattern: #"`(?:\\.|[^`\\])*`|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#)
    case "html", "xml":
      return CodeLanguageSyntax(keywords: [], commentPatterns: [#"<!--[\s\S]*?-->"#], stringPattern: #"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#)
    case "yaml", "yml", "bash", "shell":
      return CodeLanguageSyntax(keywords: ["true", "false", "null"], commentPatterns: hashComments, stringPattern: #"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#)
    default:
      return CodeLanguageSyntax(keywords: [], commentPatterns: slashComments + hashComments, stringPattern: #"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#)
    }
  }
}

private func clamped(_ range: NSRange, length: Int) -> NSRange {
  let location = min(max(range.location, 0), length)
  return NSRange(location: location, length: min(max(range.length, 0), length - location))
}
