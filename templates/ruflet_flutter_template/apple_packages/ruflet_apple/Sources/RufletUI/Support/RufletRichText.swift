import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

/// The inline tree Flet creates in `parseTextSpans`, flattened into ranges.
/// Keeping ranges is what lets native rendering attach behavior to the exact
/// nested span that declared it.
struct RufletRichTextDocument {
  struct Run {
    let node: ControlNode
    let range: NSRange
    let depth: Int

    var opensURL: URL? {
      guard node.bool("disabled") != true, let raw = node.string("url") else { return nil }
      return URL(string: raw)
    }

    var isInteractive: Bool {
      node.bool("disabled") != true && (node.handlesEvent("click") || opensURL != nil)
    }

    var tracksPointer: Bool {
      node.bool("disabled") != true
        && (node.handlesEvent("enter") || node.handlesEvent("exit"))
    }
  }

  let string: String
  let runs: [Run]

  init(value: String, spanIDs: [Int], resolve: (Int) -> ControlNode?) {
    var text = value
    var resolvedRuns: [Run] = []

    func append(_ id: Int, depth: Int) {
      guard let span = resolve(id) else { return }
      let start = text.utf16.count
      text += span.string("text") ?? ""
      for child in span.controlIDs(forKey: "spans") { append(child, depth: depth + 1) }
      resolvedRuns.append(
        Run(
          node: span,
          range: NSRange(location: start, length: text.utf16.count - start),
          depth: depth))
    }

    for id in spanIDs { append(id, depth: 0) }
    string = text
    // Parent attributes first; nested spans then override inherited values.
    runs = resolvedRuns.sorted {
      if $0.depth == $1.depth { return $0.range.location < $1.range.location }
      return $0.depth < $1.depth
    }
  }

  func deepestRun(at utf16Offset: Int) -> Run? {
    runs.filter { NSLocationInRange(utf16Offset, $0.range) }
      .max { $0.depth < $1.depth }
  }

  /// Exact Flet 0.80.5 Text selection payload. Flet reports the root value in
  /// `selected_text`, even when the selected glyphs belong to child spans.
  static func textSelectionData(
    rootValue: String, range: NSRange, cause: String = "unknown"
  ) -> RufletValue {
    .map([
      "selected_text": .string(rootValue),
      "cause": .string(cause),
      "selection": .map([
        "base_offset": .int(Int64(range.location)),
        "extent_offset": .int(Int64(NSMaxRange(range))),
        "affinity": .string("downstream"),
        "directional": .bool(false),
      ]),
    ])
  }

  /// Exact flutter_markdown_plus selection payload used by Flet 0.80.5.
  static func markdownSelectionData(
    source: String, range: NSRange, cause: String = "unknown"
  ) -> RufletValue {
    let length = source.utf16.count
    let start = min(max(0, range.location), length)
    let count = min(max(0, range.length), length - start)
    let normalized = NSRange(location: start, length: count)
    let selected = (source as NSString).substring(with: normalized)
    return .map([
      "text": .string(selected),
      "cause": .string(cause),
      "selection": .map([
        "start": .int(Int64(start)),
        "end": .int(Int64(NSMaxRange(normalized))),
        "selection": .string(selected),
        "base_offset": .int(Int64(start)),
        "extent_offset": .int(Int64(NSMaxRange(normalized))),
        "affinity": .string("downstream"),
        "directional": .bool(false),
        "collapsed": .bool(count == 0),
        "valid": .bool(true),
        "normalized": .bool(true),
      ]),
    ])
  }
}

enum RufletSpanLink {
  private static let scheme = "ruflet-text-span"
  static func url(for id: Int) -> URL { URL(string: "\(scheme)://span/\(id)")! }
  static func id(from url: URL) -> Int? {
    guard url.scheme == scheme else { return nil }
    return Int(url.pathComponents.last ?? "")
  }
}

extension RufletRichTextDocument {
  func attributedString(rootStyle: RufletTextStyle) -> AttributedString {
    var result = AttributedString(string)
    apply(rootStyle, to: &result, nsRange: NSRange(location: 0, length: string.utf16.count))
    for run in runs {
      apply(RufletTextStyle(node: run.node), to: &result, nsRange: run.range)
      guard let range = attributedRange(run.range, in: result), run.isInteractive else { continue }
      result[range].link = RufletSpanLink.url(for: run.node.id)
    }
    return result
  }

  private func apply(_ style: RufletTextStyle, to value: inout AttributedString, nsRange: NSRange) {
    guard let range = attributedRange(nsRange, in: value) else { return }
    value[range].font = style.font
    if let color = style.color { value[range].foregroundColor = color }
    if let color = style.backgroundColor { value[range].backgroundColor = color }
    if let spacing = style.letterSpacing { value[range].kern = spacing }
    if style.decoration.contains(.underline) { value[range].underlineStyle = .single }
    if style.decoration.contains(.lineThrough) { value[range].strikethroughStyle = .single }
  }

  private func attributedRange(
    _ nsRange: NSRange, in value: AttributedString
  ) -> Range<AttributedString.Index>? {
    guard let stringRange = Range(nsRange, in: string),
      let lower = AttributedString.Index(stringRange.lowerBound, within: value),
      let upper = AttributedString.Index(stringRange.upperBound, within: value)
    else { return nil }
    return lower..<upper
  }
}

/// SwiftUI exposes selectable text but not selection callbacks. A native text
/// view is therefore used only when Flet's `selectable` flag is true.
struct RufletSelectableRichText: View {
  let node: ControlNode
  let document: RufletRichTextDocument
  let attributed: AttributedString
  let events: RufletEventSink
  let activate: (Int) -> Void
  let hover: (Int, Bool) -> Void

  var body: some View {
    #if canImport(UIKit)
      RufletUIKitRichText(
        node: node, document: document, attributed: attributed,
        events: events, activate: activate, hover: hover)
    #elseif canImport(AppKit)
      RufletAppKitRichText(
        node: node, document: document, attributed: attributed,
        events: events, activate: activate, hover: hover)
    #else
      Text(attributed).textSelection(.enabled)
    #endif
  }
}

#if canImport(UIKit)
  import UIKit

  private final class RufletIntrinsicTextView: UITextView {
    override var intrinsicContentSize: CGSize {
      sizeThatFits(
        CGSize(
          width: bounds.width > 0 ? bounds.width : 10_000,
          height: CGFloat.greatestFiniteMagnitude))
    }
    override func layoutSubviews() {
      super.layoutSubviews()
      invalidateIntrinsicContentSize()
    }
  }

  private struct RufletUIKitRichText: UIViewRepresentable {
    let node: ControlNode
    let document: RufletRichTextDocument
    let attributed: AttributedString
    let events: RufletEventSink
    let activate: (Int) -> Void
    let hover: (Int, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> UITextView {
      let view = RufletIntrinsicTextView()
      view.backgroundColor = .clear
      view.isEditable = false
      view.isScrollEnabled = false
      view.isSelectable = true
      view.textContainerInset = .zero
      view.textContainer.lineFragmentPadding = 0
      view.delegate = context.coordinator
      view.addGestureRecognizer(
        UIHoverGestureRecognizer(
          target: context.coordinator, action: #selector(Coordinator.didHover(_:))))
      return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
      context.coordinator.parent = self
      let rendered = NSAttributedString(attributed)
      if !view.attributedText.isEqual(to: rendered) { view.attributedText = rendered }
      view.isUserInteractionEnabled = node.bool("enable_interactive_selection") != false
    }

    final class Coordinator: NSObject, UITextViewDelegate {
      var parent: RufletUIKitRichText
      private var hoveredID: Int?
      init(parent: RufletUIKitRichText) { self.parent = parent }

      func textViewDidChangeSelection(_ textView: UITextView) {
        guard parent.node.bool("selectable") == true else { return }
        parent.events.fire(
          parent.node, "selection_change",
          data: RufletRichTextDocument.textSelectionData(
            rootValue: parent.node.string("value") ?? "",
            range: textView.selectedRange))
      }

      func textView(
        _ textView: UITextView, shouldInteractWith url: URL,
        in characterRange: NSRange, interaction: UITextItemInteraction
      ) -> Bool {
        guard let id = RufletSpanLink.id(from: url) else { return true }
        parent.activate(id)
        return false
      }

      @objc func didHover(_ recognizer: UIHoverGestureRecognizer) {
        guard let view = recognizer.view as? UITextView else { return }
        let point = recognizer.location(in: view)
        let adjusted = CGPoint(
          x: point.x - view.textContainerInset.left,
          y: point.y - view.textContainerInset.top)
        let index = view.layoutManager.characterIndex(
          for: adjusted, in: view.textContainer,
          fractionOfDistanceBetweenInsertionPoints: nil)
        let id = parent.document.deepestRun(at: index)?.node.id
        if hoveredID != id {
          if let hoveredID { parent.hover(hoveredID, false) }
          if let id { parent.hover(id, true) }
          hoveredID = id
        }
        if recognizer.state == .ended || recognizer.state == .cancelled {
          if let hoveredID { parent.hover(hoveredID, false) }
          hoveredID = nil
        }
      }
    }
  }
#endif

#if canImport(AppKit)
  import AppKit

  private final class RufletHoverTextView: NSTextView {
    var pointerMoved: ((Int?) -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      if let tracking { removeTrackingArea(tracking) }
      let area = NSTrackingArea(
        rect: bounds,
        options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
        owner: self)
      addTrackingArea(area)
      tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
      guard let layoutManager, let textContainer else {
        pointerMoved?(nil)
        return
      }
      let point = convert(event.locationInWindow, from: nil)
      let origin = textContainerOrigin
      let index = layoutManager.characterIndex(
        for: CGPoint(x: point.x - origin.x, y: point.y - origin.y),
        in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
      pointerMoved?(index < string.utf16.count ? index : nil)
    }

    override func mouseExited(with event: NSEvent) { pointerMoved?(nil) }
  }

  private struct RufletAppKitRichText: NSViewRepresentable {
    let node: ControlNode
    let document: RufletRichTextDocument
    let attributed: AttributedString
    let events: RufletEventSink
    let activate: (Int) -> Void
    let hover: (Int, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeNSView(context: Context) -> NSTextView {
      let view = RufletHoverTextView()
      view.drawsBackground = false
      view.isEditable = false
      view.isSelectable = true
      view.textContainerInset = .zero
      view.textContainer?.lineFragmentPadding = 0
      view.delegate = context.coordinator
      view.pointerMoved = context.coordinator.pointerMoved
      return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
      context.coordinator.parent = self
      (view as? RufletHoverTextView)?.pointerMoved = context.coordinator.pointerMoved
      let rendered = NSAttributedString(attributed)
      if !view.attributedString().isEqual(to: rendered) {
        view.textStorage?.setAttributedString(rendered)
      }
      view.isSelectable = node.bool("enable_interactive_selection") != false
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
      var parent: RufletAppKitRichText
      private var hoveredID: Int?
      init(parent: RufletAppKitRichText) { self.parent = parent }

      func pointerMoved(_ characterIndex: Int?) {
        let id = characterIndex.flatMap { parent.document.deepestRun(at: $0)?.node.id }
        guard hoveredID != id else { return }
        if let hoveredID { parent.hover(hoveredID, false) }
        if let id { parent.hover(id, true) }
        hoveredID = id
      }

      func textViewDidChangeSelection(_ notification: Notification) {
        guard parent.node.bool("selectable") == true else { return }
        guard let view = notification.object as? NSTextView else { return }
        parent.events.fire(
          parent.node, "selection_change",
          data: RufletRichTextDocument.textSelectionData(
            rootValue: parent.node.string("value") ?? "",
            range: view.selectedRange()))
      }

      func textView(
        _ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int
      ) -> Bool {
        let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:))
        guard let url, let id = RufletSpanLink.id(from: url) else { return false }
        parent.activate(id)
        return true
      }
    }
  }
#endif
