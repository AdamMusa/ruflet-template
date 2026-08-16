import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum RufletCodeEditorError: Error, Equatable, Sendable {
  case unknownMethod(String)
}

@MainActor
final class RufletCodeEditorModel: ObservableObject {
  let control: RufletControl
  let editor: FletCodeController
  private var invokeToken: UUID?
  private var lastReportedValue: String
  private var lastReportedSelection: RufletCodeSelection

  init(control: RufletControl) {
    self.control = control
    let text = control.string("value") ?? ""
    editor = FletCodeController(text: text, language: control.string("language") ?? "")
    lastReportedValue = text
    lastReportedSelection = editor.selection
    applyControlConfiguration()
  }

  func attach() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { throw RufletCodeEditorError.unknownMethod(name) }
      switch name {
      case "focus": self.editor.focusRequest += 1
      case "fold_comment_at_line_zero": self.editor.foldCommentAtLineZero()
      case "fold_imports": self.editor.foldImports()
      case "fold_at":
        if let line = arguments.map?["line_number"]?.integer { self.editor.foldAt(line) }
      default: throw RufletCodeEditorError.unknownMethod(name)
      }
      return .null
    }
  }

  func detach() {
    if let invokeToken {
      control.removeInvokeMethodListener(invokeToken)
      self.invokeToken = nil
    }
  }

  func applyControlConfiguration() {
    let language = control.string("language") ?? ""
    if editor.language != language { editor.language = language }
    editor.autocompletionEnabled = control.boolean("autocomplete", default: false)
    editor.customWords = control.value("autocomplete_words")?.array?.compactMap(\.text) ?? []
    if let value = control.string("value"), value != editor.fullText, value != lastReportedValue {
      editor.setFullText(value)
      lastReportedValue = value
    }
    if let map = control.value("selection")?.map {
      let base = map["base_offset"]?.integer ?? 0
      let extent = map["extent_offset"]?.integer ?? base
      let length = (editor.visibleText as NSString).length
      let selection = RufletCodeSelection(
        baseOffset: min(max(base, 0), length),
        extentOffset: min(max(extent, 0), length))
      if selection != lastReportedSelection { editor.selection = selection }
    }
  }

  func userChanged(valueChanged: Bool, selectionChanged: Bool) {
    var updates: [String: RufletValue] = [:]
    if valueChanged {
      lastReportedValue = editor.fullText
      updates["value"] = .string(editor.fullText)
    }
    if selectionChanged {
      lastReportedSelection = editor.selection
      updates["selection"] = selectionValue(editor.selection)
    }
    if !updates.isEmpty { control.updateProperties(updates) }
    if valueChanged, control.hasEventHandler("change") {
      control.triggerEvent("change", data: .string(editor.fullText))
    }
    if selectionChanged {
      let range = editor.selection.range
      let visible = editor.visibleText as NSString
      let selected = NSMaxRange(range) <= visible.length ? visible.substring(with: range) : ""
      control.triggerEvent("selection_change", data: .map([
        "selected_text": .string(selected),
        "selection": selectionValue(editor.selection),
      ]))
    }
  }

  private func selectionValue(_ selection: RufletCodeSelection) -> RufletValue {
    .map([
      "base_offset": .int(Int64(selection.baseOffset)),
      "extent_offset": .int(Int64(selection.extentOffset)),
      "affinity": .string("downstream"),
      "directional": .bool(false),
    ])
  }
}

#if os(iOS)
private final class RufletIOSCodeEditorView: UIView {
  let gutter = UITextView()
  let editor = UITextView()
  private var gutterWidth: NSLayoutConstraint!

  override init(frame: CGRect) {
    super.init(frame: frame)
    gutter.translatesAutoresizingMaskIntoConstraints = false
    editor.translatesAutoresizingMaskIntoConstraints = false
    addSubview(gutter)
    addSubview(editor)
    gutterWidth = gutter.widthAnchor.constraint(equalToConstant: 80)
    NSLayoutConstraint.activate([
      gutter.leadingAnchor.constraint(equalTo: leadingAnchor),
      gutter.topAnchor.constraint(equalTo: topAnchor),
      gutter.bottomAnchor.constraint(equalTo: bottomAnchor),
      gutterWidth,
      editor.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
      editor.trailingAnchor.constraint(equalTo: trailingAnchor),
      editor.topAnchor.constraint(equalTo: topAnchor),
      editor.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    gutter.isEditable = false
    gutter.isSelectable = false
    gutter.isScrollEnabled = true
    gutter.showsVerticalScrollIndicator = false
    gutter.showsHorizontalScrollIndicator = false
    gutter.textAlignment = .right
    editor.alwaysBounceHorizontal = true
    editor.alwaysBounceVertical = true
    editor.showsHorizontalScrollIndicator = true
    editor.textContainer.widthTracksTextView = false
    editor.textContainer.size = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude)
    editor.smartQuotesType = .no
    editor.smartDashesType = .no
    editor.autocorrectionType = .no
    editor.autocapitalizationType = .none
    editor.spellCheckingType = .no
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

  func apply(style: RufletCodeEditorStyle) {
    gutterWidth.constant = style.gutter.showLineNumbers ? style.gutter.width : 0
    gutter.textColor = style.gutter.foreground
    gutter.backgroundColor = style.gutter.background
    gutter.font = style.font
    gutter.textContainerInset = UIEdgeInsets(top: 16, left: 8, bottom: 16, right: style.gutter.margin)
    gutter.textContainer.lineFragmentPadding = 0
    editor.backgroundColor = style.background
    editor.font = style.font
    editor.textColor = style.foreground
    editor.textContainerInset = UIEdgeInsets(
      top: 16,
      left: 8,
      bottom: 16,
      right: 0)
  }
}

private struct RufletPlatformCodeEditor: UIViewRepresentable {
  @ObservedObject var model: RufletCodeEditorModel
  let style: RufletCodeEditorStyle

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> RufletIOSCodeEditorView {
    let view = RufletIOSCodeEditorView()
    view.editor.delegate = context.coordinator
    context.coordinator.host = view
    context.coordinator.refresh(view, style: style)
    return view
  }

  func updateUIView(_ view: RufletIOSCodeEditorView, context: Context) {
    context.coordinator.refresh(view, style: style)
  }

  @MainActor
  final class Coordinator: NSObject, UITextViewDelegate {
    let model: RufletCodeEditorModel
    weak var host: RufletIOSCodeEditorView?
    private var updating = false
    private var lastFocusRequest = -1

    init(model: RufletCodeEditorModel) { self.model = model }

    func refresh(_ host: RufletIOSCodeEditorView, style: RufletCodeEditorStyle) {
      updating = true
      host.apply(style: style)
      if host.editor.text != model.editor.visibleText {
        host.editor.text = model.editor.visibleText
      }
      let range = model.editor.selection.range
      if NSMaxRange(range) <= (host.editor.text as NSString).length, host.editor.selectedRange != range {
        host.editor.selectedRange = range
      }
      host.editor.isEditable = !model.control.boolean("read_only", default: false) && !model.control.disabled
      host.editor.isSelectable = !model.control.disabled
      updateGutter(host, style: style)
      RufletCodeHighlighter(style: style, language: model.editor.language).apply(to: host.editor.textStorage)
      updateCompletions(host.editor)
      if model.editor.focusRequest != lastFocusRequest || (lastFocusRequest < 0 && model.control.boolean("autofocus", default: false)) {
        lastFocusRequest = model.editor.focusRequest
        DispatchQueue.main.async { host.editor.becomeFirstResponder() }
      }
      updating = false
    }

    func textViewDidBeginEditing(_ textView: UITextView) { model.control.triggerEvent("focus") }
    func textViewDidEndEditing(_ textView: UITextView) { model.control.triggerEvent("blur") }

    func textView(
      _ textView: UITextView,
      shouldChangeTextIn range: NSRange,
      replacementText text: String
    ) -> Bool {
      guard model.editor.hasFolds else { return true }
      let changed = model.editor.applyVisibleEdit(range: range, replacement: text)
      if changed {
        model.userChanged(valueChanged: true, selectionChanged: true)
        if let host { refresh(host, style: RufletCodeEditorStyle(control: model.control)) }
      }
      return false
    }

    func textViewDidChange(_ textView: UITextView) {
      guard !updating, !model.editor.hasFolds else { return }
      let oldValue = model.editor.fullText
      let oldSelection = model.editor.selection
      let nextSelection = RufletCodeSelection(
        baseOffset: textView.selectedRange.location,
        extentOffset: NSMaxRange(textView.selectedRange))
      model.editor.acceptUnfoldedText(textView.text, selection: nextSelection)
      model.userChanged(valueChanged: oldValue != textView.text, selectionChanged: oldSelection != nextSelection)
      if let host { refresh(host, style: RufletCodeEditorStyle(control: model.control)) }
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      guard !updating else { return }
      let next = RufletCodeSelection(
        baseOffset: textView.selectedRange.location,
        extentOffset: NSMaxRange(textView.selectedRange))
      guard next != model.editor.selection else { return }
      model.editor.selection = next
      model.userChanged(valueChanged: false, selectionChanged: true)
      updateCompletions(textView)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      guard scrollView === host?.editor else { return }
      host?.gutter.contentOffset.y = scrollView.contentOffset.y
    }

    private func updateGutter(_ host: RufletIOSCodeEditorView, style: RufletCodeEditorStyle) {
      host.gutter.attributedText = NSAttributedString(
        string: gutterText(style: style),
        attributes: style.gutterAttributes)
      host.gutter.contentOffset.y = host.editor.contentOffset.y
    }

    private func gutterText(style: RufletCodeEditorStyle) -> String {
      let foldable = model.editor.foldableLineNumbers()
      return model.editor.lineNumbers().map { number in
        let prefix = style.gutter.showFoldingHandles
          ? (foldable.contains(number) ? "▾ " : "  ") : ""
        return prefix + String(number)
      }.joined(separator: "\n")
    }

    private func updateCompletions(_ textView: UITextView) {
      let suggestions = model.editor.suggestions(at: textView.selectedRange.location)
      textView.inputAssistantItem.trailingBarButtonGroups = suggestions.isEmpty ? [] : [UIBarButtonItemGroup(
        barButtonItems: suggestions.prefix(5).map { word in
          UIBarButtonItem(title: word, primaryAction: UIAction { [weak self, weak textView] _ in
            self?.insertCompletion(word, into: textView)
          })
        },
        representativeItem: nil)]
    }

    private func insertCompletion(_ word: String, into textView: UITextView?) {
      guard let textView else { return }
      let text = textView.text as NSString
      var start = textView.selectedRange.location
      let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
      while start > 0, UnicodeScalar(text.character(at: start - 1)).map(allowed.contains) == true { start -= 1 }
      let range = NSRange(location: start, length: textView.selectedRange.location - start)
      if model.editor.hasFolds {
        _ = self.textView(textView, shouldChangeTextIn: range, replacementText: word)
        return
      }
      textView.textStorage.replaceCharacters(in: range, with: word)
      textView.selectedRange = NSRange(location: start + (word as NSString).length, length: 0)
      textViewDidChange(textView)
    }
  }
}
#elseif os(macOS)
private final class RufletMacCodeEditorView: NSView {
  let gutterScroll = NSScrollView()
  let editorScroll = NSScrollView()
  let gutter = NSTextView()
  let editor = NSTextView()
  private var gutterWidth: NSLayoutConstraint!
  var scrollObserver: NSObjectProtocol?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    gutterScroll.translatesAutoresizingMaskIntoConstraints = false
    editorScroll.translatesAutoresizingMaskIntoConstraints = false
    addSubview(gutterScroll)
    addSubview(editorScroll)
    gutterWidth = gutterScroll.widthAnchor.constraint(equalToConstant: 80)
    NSLayoutConstraint.activate([
      gutterScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
      gutterScroll.topAnchor.constraint(equalTo: topAnchor),
      gutterScroll.bottomAnchor.constraint(equalTo: bottomAnchor),
      gutterWidth,
      editorScroll.leadingAnchor.constraint(equalTo: gutterScroll.trailingAnchor),
      editorScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
      editorScroll.topAnchor.constraint(equalTo: topAnchor),
      editorScroll.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    gutterScroll.documentView = gutter
    editorScroll.documentView = editor
    gutterScroll.hasVerticalScroller = false
    gutterScroll.hasHorizontalScroller = false
    editorScroll.hasVerticalScroller = true
    editorScroll.hasHorizontalScroller = true
    editorScroll.autohidesScrollers = true
    editor.minSize = .zero
    editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    editor.isVerticallyResizable = true
    editor.isHorizontallyResizable = true
    editor.autoresizingMask = [.width]
    editor.textContainer?.containerSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude)
    editor.textContainer?.widthTracksTextView = false
    gutter.isEditable = false
    gutter.isSelectable = false
    gutter.alignment = .right
    gutter.isVerticallyResizable = true
    editorScroll.contentView.postsBoundsChangedNotifications = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

  deinit {
    if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
  }

  func apply(style: RufletCodeEditorStyle) {
    gutterWidth.constant = style.gutter.showLineNumbers ? style.gutter.width : 0
    gutter.textColor = style.gutter.foreground
    gutter.backgroundColor = style.gutter.background
    gutter.font = style.font
    editor.backgroundColor = style.background
    editor.font = style.font
    editor.textColor = style.foreground
    editor.textContainerInset = NSSize(width: 8, height: 16)
    editorScroll.contentInsets = NSEdgeInsets(
      top: 0, left: 0, bottom: 16, right: 0)
    gutter.textContainerInset = NSSize(width: style.gutter.margin, height: 16)
  }
}

private struct RufletPlatformCodeEditor: NSViewRepresentable {
  @ObservedObject var model: RufletCodeEditorModel
  let style: RufletCodeEditorStyle

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeNSView(context: Context) -> RufletMacCodeEditorView {
    let view = RufletMacCodeEditorView()
    view.editor.delegate = context.coordinator
    context.coordinator.host = view
    view.scrollObserver = NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification,
      object: view.editorScroll.contentView,
      queue: .main
    ) { [weak coordinator = context.coordinator] _ in
      Task { @MainActor in coordinator?.synchronizeGutterScroll() }
    }
    context.coordinator.refresh(view, style: style)
    return view
  }

  func updateNSView(_ view: RufletMacCodeEditorView, context: Context) {
    context.coordinator.refresh(view, style: style)
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    let model: RufletCodeEditorModel
    weak var host: RufletMacCodeEditorView?
    private var updating = false
    private var lastFocusRequest = -1

    init(model: RufletCodeEditorModel) { self.model = model }

    func refresh(_ host: RufletMacCodeEditorView, style: RufletCodeEditorStyle) {
      updating = true
      host.apply(style: style)
      if host.editor.string != model.editor.visibleText { host.editor.string = model.editor.visibleText }
      let range = model.editor.selection.range
      if NSMaxRange(range) <= (host.editor.string as NSString).length, host.editor.selectedRange() != range {
        host.editor.setSelectedRange(range)
      }
      host.editor.isEditable = !model.control.boolean("read_only", default: false) && !model.control.disabled
      host.editor.isSelectable = !model.control.disabled
      host.gutter.textStorage?.setAttributedString(NSAttributedString(
        string: gutterText(style: style),
        attributes: style.gutterAttributes))
      if let storage = host.editor.textStorage {
        RufletCodeHighlighter(style: style, language: model.editor.language).apply(to: storage)
      }
      if model.editor.focusRequest != lastFocusRequest || (lastFocusRequest < 0 && model.control.boolean("autofocus", default: false)) {
        lastFocusRequest = model.editor.focusRequest
        DispatchQueue.main.async { host.window?.makeFirstResponder(host.editor) }
      }
      updating = false
    }

    func textDidBeginEditing(_ notification: Notification) { model.control.triggerEvent("focus") }
    func textDidEndEditing(_ notification: Notification) { model.control.triggerEvent("blur") }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
      guard model.editor.hasFolds else { return true }
      let changed = model.editor.applyVisibleEdit(range: affectedCharRange, replacement: replacementString ?? "")
      if changed {
        model.userChanged(valueChanged: true, selectionChanged: true)
        if let host { refresh(host, style: RufletCodeEditorStyle(control: model.control)) }
      }
      return false
    }

    func textDidChange(_ notification: Notification) {
      guard !updating, !model.editor.hasFolds, let textView = notification.object as? NSTextView else { return }
      let oldValue = model.editor.fullText
      let oldSelection = model.editor.selection
      let range = textView.selectedRange()
      let next = RufletCodeSelection(baseOffset: range.location, extentOffset: NSMaxRange(range))
      model.editor.acceptUnfoldedText(textView.string, selection: next)
      model.userChanged(valueChanged: oldValue != textView.string, selectionChanged: oldSelection != next)
      if let host { refresh(host, style: RufletCodeEditorStyle(control: model.control)) }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard !updating, let textView = notification.object as? NSTextView else { return }
      let range = textView.selectedRange()
      let next = RufletCodeSelection(baseOffset: range.location, extentOffset: NSMaxRange(range))
      guard next != model.editor.selection else { return }
      model.editor.selection = next
      model.userChanged(valueChanged: false, selectionChanged: true)
    }

    func textView(
      _ textView: NSTextView,
      completions words: [String],
      forPartialWordRange charRange: NSRange,
      indexOfSelectedItem index: UnsafeMutablePointer<Int>?
    ) -> [String] {
      model.editor.suggestions(at: NSMaxRange(charRange))
    }

    func synchronizeGutterScroll() {
      guard let host else { return }
      let origin = host.editorScroll.contentView.bounds.origin
      host.gutterScroll.contentView.scroll(to: NSPoint(x: 0, y: origin.y))
      host.gutterScroll.reflectScrolledClipView(host.gutterScroll.contentView)
    }

    private func gutterText(style: RufletCodeEditorStyle) -> String {
      let foldable = model.editor.foldableLineNumbers()
      return model.editor.lineNumbers().map { number in
        let prefix = style.gutter.showFoldingHandles
          ? (foldable.contains(number) ? "▾ " : "  ") : ""
        return prefix + String(number)
      }.joined(separator: "\n")
    }
  }
}
#endif

struct CodeEditorControl: View {
  @ObservedObject var control: RufletControl
  @Environment(\.rufletPageTheme) private var pageTheme
  @StateObject private var model: RufletCodeEditorModel

  init(control: RufletControl) {
    self.control = control
    _model = StateObject(wrappedValue: RufletCodeEditorModel(control: control))
  }

  var body: some View {
    LayoutControl(control: control) {
      RufletPlatformCodeEditor(
        model: model,
        style: RufletCodeEditorStyle(
          control: control,
          themeTextStyle: pageTheme?.textTheme?["title_medium"]))
        .clipped()
        .onAppear {
          model.attach()
          model.applyControlConfiguration()
        }
        .onDisappear { model.detach() }
        .onChange(of: configurationIdentity) { _ in model.applyControlConfiguration() }
    }
  }

  private var configurationIdentity: String {
    ["value", "selection", "language", "autocomplete", "autocomplete_words", "read_only"]
      .map { String(describing: control.value($0)) }
      .joined(separator: "\u{1f}")
  }
}
