import Foundation
import SwiftUI

#if canImport(UIKit)
  import UIKit

  /// Native highlighted text storage for Ruflet's `CodeEditor` on iOS.
  struct HighlightedCodeTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    @Binding var selection: NSRange
    let editable: Bool
    let dark: Bool
    let fontSize: CGFloat

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
      view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
      view.textContainer.lineFragmentPadding = 0
      update(view, coordinator: context.coordinator)
      return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
      context.coordinator.parent = self
      update(view, coordinator: context.coordinator)
      if focused, !view.isFirstResponder, editable { view.becomeFirstResponder() }
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
      view.backgroundColor = RubySyntaxHighlighter.uiBackground(dark: dark)
      if view.text != text || coordinator.lastDark != dark || coordinator.lastFontSize != fontSize {
        coordinator.applyHighlight(to: view, text: text, dark: dark, fontSize: fontSize)
      }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
      var parent: HighlightedCodeTextView
      var applying = false
      var lastDark: Bool?
      var lastFontSize: CGFloat?

      init(_ parent: HighlightedCodeTextView) { self.parent = parent }

      func textViewDidChange(_ textView: UITextView) {
        guard !applying else { return }
        parent.text = textView.text
        applyHighlight(to: textView, text: textView.text, dark: parent.dark, fontSize: parent.fontSize)
      }

      func textViewDidBeginEditing(_ textView: UITextView) { parent.focused = true }
      func textViewDidEndEditing(_ textView: UITextView) { parent.focused = false }
      func textViewDidChangeSelection(_ textView: UITextView) {
        guard !applying else { return }
        parent.selection = textView.selectedRange
      }

      func applyHighlight(to view: UITextView, text: String, dark: Bool, fontSize: CGFloat) {
        applying = true
        let selection = view.selectedRange
        view.attributedText = RubySyntaxHighlighter.attributed(text, dark: dark, fontSize: fontSize)
        let textLength = text.utf16.count
        let location = min(selection.location, textLength)
        view.selectedRange = NSRange(location: location, length: min(selection.length, textLength - location))
        view.typingAttributes = RubySyntaxHighlighter.baseAttributes(dark: dark, fontSize: fontSize)
        lastDark = dark
        lastFontSize = fontSize
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
    let editable: Bool
    let dark: Bool
    let fontSize: CGFloat

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
      view.textContainerInset = NSSize(width: 12, height: 12)
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
      if focused, editable, view.window?.firstResponder !== view { view.window?.makeFirstResponder(view) }
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
      view.backgroundColor = RubySyntaxHighlighter.nsBackground(dark: dark)
      if view.string != text || coordinator.lastDark != dark || coordinator.lastFontSize != fontSize {
        coordinator.applyHighlight(to: view, text: text, dark: dark, fontSize: fontSize)
      }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
      var parent: HighlightedCodeTextView
      var applying = false
      var lastDark: Bool?
      var lastFontSize: CGFloat?

      init(_ parent: HighlightedCodeTextView) { self.parent = parent }

      func textDidChange(_ notification: Notification) {
        guard !applying, let view = notification.object as? NSTextView else { return }
        parent.text = view.string
        applyHighlight(to: view, text: view.string, dark: parent.dark, fontSize: parent.fontSize)
      }

      func textDidBeginEditing(_ notification: Notification) { parent.focused = true }
      func textDidEndEditing(_ notification: Notification) { parent.focused = false }
      func textViewDidChangeSelection(_ notification: Notification) {
        guard !applying, let view = notification.object as? NSTextView else { return }
        parent.selection = view.selectedRange()
      }

      func applyHighlight(to view: NSTextView, text: String, dark: Bool, fontSize: CGFloat) {
        applying = true
        let selections = view.selectedRanges
        view.textStorage?.setAttributedString(RubySyntaxHighlighter.attributed(text, dark: dark, fontSize: fontSize))
        let textLength = text.utf16.count
        view.selectedRanges = selections.map { value in
          let range = value.rangeValue
          let location = min(range.location, textLength)
          return NSValue(range: NSRange(location: location, length: min(range.length, textLength - location)))
        }
        view.typingAttributes = RubySyntaxHighlighter.baseAttributes(dark: dark, fontSize: fontSize)
        lastDark = dark
        lastFontSize = fontSize
        applying = false
      }
    }
  }
#endif

enum RubySyntaxHighlighter {
  static func attributed(_ source: String, dark: Bool, fontSize: CGFloat) -> NSAttributedString {
    let output = NSMutableAttributedString(string: source, attributes: baseAttributes(dark: dark, fontSize: fontSize))
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

    paint(#"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#, color: syntaxColor(.string, dark: dark), protects: true)
    paint(#"#[^\n]*"#, color: syntaxColor(.comment, dark: dark), protects: true)
    paint(#"\b(?:class|module|def|end|do|if|else|elsif|unless|while|until|case|when|then|begin|rescue|ensure|yield|return|require|include|extend|attr_reader|attr_writer|attr_accessor|true|false|nil|self)\b"#, color: syntaxColor(.keyword, dark: dark))
    paint(#"(?<!\w):[a-zA-Z_]\w*[!?=]?"#, color: syntaxColor(.symbol, dark: dark))
    paint(#"\b[A-Z][A-Za-z0-9_]*\b"#, color: syntaxColor(.constant, dark: dark))
    paint(#"\b\d+(?:\.\d+)?\b"#, color: syntaxColor(.number, dark: dark))
    return output
  }

  static func baseAttributes(dark: Bool, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
    #if canImport(UIKit)
      return [.font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
              .foregroundColor: uiColor(.plain, dark: dark)]
    #elseif canImport(AppKit)
      return [.font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
              .foregroundColor: nsColor(.plain, dark: dark)]
    #else
      return [:]
    #endif
  }

  enum Token { case plain, comment, string, keyword, symbol, constant, number }

  private static func syntaxColor(_ token: Token, dark: Bool) -> Any {
    #if canImport(UIKit)
      return uiColor(token, dark: dark)
    #elseif canImport(AppKit)
      return nsColor(token, dark: dark)
    #else
      return 0
    #endif
  }

  #if canImport(UIKit)
    static func uiBackground(dark: Bool) -> UIColor {
      dark ? UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1) : .white
    }

    private static func uiColor(_ token: Token, dark: Bool) -> UIColor {
      let rgb = components(token, dark: dark)
      return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
  #endif

  #if canImport(AppKit)
    static func nsBackground(dark: Bool) -> NSColor {
      dark ? NSColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1) : .textBackgroundColor
    }

    private static func nsColor(_ token: Token, dark: Bool) -> NSColor {
      let rgb = components(token, dark: dark)
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
}

private func clamped(_ range: NSRange, length: Int) -> NSRange {
  let location = min(max(range.location, 0), length)
  return NSRange(location: location, length: min(max(range.length, 0), length - location))
}
