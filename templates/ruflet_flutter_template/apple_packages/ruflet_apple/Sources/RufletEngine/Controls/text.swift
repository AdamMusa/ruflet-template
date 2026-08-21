import RufletProtocol
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@MainActor
public struct TextControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletPageTheme) private var pageTheme
  @Environment(\.rufletInheritedTextStyle) private var inheritedTextStyle
  @Environment(\.rufletSelectionAreaReporter) private var selectionAreaReporter
  @Environment(\.rufletCrossAxisStretchAxis) private var crossAxisStretchAxis

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      renderedText
    }
  }

  @ViewBuilder
  private var renderedText: some View {
    if control.boolean("selectable", default: false) || selectionAreaReporter != nil {
      RufletNativeSelectableText(
        value: plainText,
        selectable: control.boolean("enable_interactive_selection", default: true),
        style: resolvedNativeStyle,
        fallbackDesign: fontDesign,
        textAlignment: textAlignment,
        maxLines: control.integer("max_lines"),
        cursorColor: parseColor(control.string("selection_cursor_color")),
        cursorWidth: CGFloat(control.number("selection_cursor_width", default: 2) ?? 2),
        cursorHeight: control.number("selection_cursor_height").map { CGFloat($0) },
        showCursor: control.boolean("show_selection_cursor", default: false),
        semanticsLabel: control.string("semantics_label"),
        onSelection: selectionChanged,
        onTap: tapped
      )
      .modifier(textBoxAlignment)
    } else {
      text
        .modifier(RufletTextStyleModifier(style: resolvedStyle))
        .modifier(
          RufletTextFallbackFontModifier(
            design: fontDesign,
            enabled: control.value("font_family_fallback")?.array?.isEmpty == false,
            style: resolvedStyle)
        )
        .multilineTextAlignment(textAlignment)
        .lineLimit(control.integer("max_lines"))
        .fixedSize(horizontal: control.boolean("no_wrap", default: false), vertical: false)
        .truncationMode(truncationMode)
        .accessibilityLabel(
          control.string("semantics_label") ?? control.string("value", default: "")!
        )
        .modifier(
          RufletTextTapModifier(
            enabled: interaction.handlesTap,
            action: tapped)
        )
        .modifier(textBoxAlignment)
    }
  }

  private var textBoxAlignment: RufletTextBoxAlignmentModifier {
    RufletTextBoxAlignmentModifier(
      fillsWidth: rufletTextFillsHorizontalBox(
        control: control,
        crossAxisStretchAxis: crossAxisStretchAxis),
      fillsHeight: crossAxisStretchAxis == .horizontal,
      horizontalAlignment: textAlignment.frameAlignment)
  }

  private var text: Text {
    control.children("spans").reduce(Text(control.string("value", default: "")!)) { partial, span in
      span.notifyParent = true
      return partial + inlineText(span)
    }
  }

  private var plainText: String {
    control.string("value", default: "")!
      + control.children("spans").map(plainText).joined()
  }

  private func plainText(_ span: RufletControl) -> String {
    span.string("text", default: "")! + span.children("spans").map(plainText).joined()
  }

  private func tapped() {
    guard interaction.handlesTap else { return }
    control.triggerEvent("tap")
  }

  private var interaction: RufletTextInteractionContract {
    RufletTextInteractionContract(control: control)
  }

  private func selectionChanged(_ selection: RufletTextSelection) {
    selectionAreaReporter?(plainText, selection)
    guard control.hasEventHandler("selection_change") else { return }
    control.triggerEvent(
      "selection_change",
      data: rufletTextSelectionEventData(
        text: control.string("value", default: "")!, selection: selection))
  }

  private func inlineText(_ span: RufletControl) -> Text {
    var result = Text(span.string("text", default: "")!)
    let style = parseTextStyle(span.dynamicValue("style"))
    if let size = style?.size { result = result.font(.system(size: size)) }
    if let weight = style?.weight { result = result.fontWeight(weight) }
    if style?.italic == true { result = result.italic() }
    if let color = style?.color { result = result.foregroundColor(color) }
    for child in span.children("spans") {
      result = result + inlineText(child)
    }
    return result
  }

  private var resolvedStyle: RufletTextStyle? {
    let style = parseTextStyle(control.dynamicValue("style"))
    let themeStyle = control.string("theme_style")
      .flatMap { pageTheme?.textTheme?[$0.lowercased()] }
    let inherited = mergeTextStyles(
      mergeTextStyles(inheritedTextStyle, themeStyle), style)
    return RufletTextStyle(
      size: control.number("size") ?? inherited?.size,
      weight: parseFontWeight(control.string("weight")) ?? inherited?.weight,
      italic: control.boolean("italic", default: inherited?.italic ?? false),
      fontFamily: control.string("font_family") ?? inherited?.fontFamily,
      height: inherited?.height,
      decoration: inherited?.decoration ?? 0,
      decorationColor: inherited?.decorationColor,
      decorationThickness: inherited?.decorationThickness,
      color: parseColor(control.string("color")) ?? inherited?.color,
      backgroundColor: parseColor(control.string("bgcolor")) ?? inherited?.backgroundColor,
      letterSpacing: inherited?.letterSpacing,
      wordSpacing: inherited?.wordSpacing,
      overflow: parseEnum(RufletTextOverflow.self, control.string("overflow"))
        ?? inherited?.overflow
    )
  }

  private var fontDesign: Font.Design {
    guard let first = control.value("font_family_fallback")?.array?.compactMap(\.text).first else {
      return .default
    }
    let family = first.lowercased()
    if family.contains("mono") { return .monospaced }
    if family.contains("serif") { return .serif }
    if family.contains("round") { return .rounded }
    return .default
  }

  private var resolvedNativeStyle: RufletTextStyle? {
    guard resolvedStyle != nil || pageTheme?.appleBodyTextStyle != nil else { return nil }
    let pageStyle = pageTheme?.appleBodyTextStyle
    return RufletTextStyle(
      size: resolvedStyle?.size ?? pageStyle?.size,
      weight: resolvedStyle?.weight ?? pageStyle?.weight,
      italic: resolvedStyle?.italic == true || pageStyle?.italic == true,
      fontFamily: resolvedStyle?.fontFamily ?? pageStyle?.fontFamily ?? pageTheme?.fontFamily,
      height: resolvedStyle?.height ?? pageStyle?.height,
      decoration: resolvedStyle?.decoration ?? pageStyle?.decoration ?? 0,
      decorationColor: resolvedStyle?.decorationColor ?? pageStyle?.decorationColor,
      decorationThickness: resolvedStyle?.decorationThickness ?? pageStyle?.decorationThickness,
      color: resolvedStyle?.color ?? pageStyle?.color ?? pageTheme?.appleContentColor,
      backgroundColor: resolvedStyle?.backgroundColor ?? pageStyle?.backgroundColor,
      letterSpacing: resolvedStyle?.letterSpacing ?? pageStyle?.letterSpacing,
      wordSpacing: resolvedStyle?.wordSpacing ?? pageStyle?.wordSpacing,
      overflow: resolvedStyle?.overflow ?? pageStyle?.overflow)
  }

  private var truncationMode: Text.TruncationMode {
    switch parseEnum(RufletTextOverflow.self, control.string("overflow")) ?? resolvedStyle?.overflow
    {
    case .clip: return .head
    case .fade: return .middle
    case .ellipsis, .visible, nil: return .tail
    }
  }

  private var textAlignment: TextAlignment {
    parseEnum(RufletTextAlign.self, control.string("text_align"), .start)!.alignment
  }
}

@MainActor
struct RufletTextInteractionContract {
  let handlesTap: Bool

  init(control: RufletControl) {
    handlesTap = !control.disabled && control.hasEventHandler("tap")
  }
}

private struct RufletTextTapModifier: ViewModifier {
  let enabled: Bool
  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.onTapGesture(perform: action)
    } else {
      // A no-op child recognizer still participates in SwiftUI gesture
      // arbitration. Text is frequently nested inside ListTile, Button and
      // clickable Container, so installing one here used to swallow the
      // parent's first tap even though Ruby did not subscribe to `on_tap`.
      content
    }
  }
}

func rufletTextSelectionEventData(
  text: String, selection: RufletTextSelection, cause: String = "unknown"
) -> RufletValue {
  [
    "selected_text": .string(text),
    "cause": .string(cause),
    "selection": selection.value,
  ]
}

extension TextAlignment {
  fileprivate var frameAlignment: Alignment {
    switch self {
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    }
  }
}

@MainActor
func rufletTextFillsHorizontalBox(
  control: RufletControl,
  crossAxisStretchAxis: Axis?
) -> Bool {
  crossAxisStretchAxis == .vertical
    || (!control.skipsProperty("width") && control.number("width") != nil)
    || rufletExpansionContract(for: control)?.axis == .horizontal
}

private struct RufletTextBoxAlignmentModifier: ViewModifier {
  let fillsWidth: Bool
  let fillsHeight: Bool
  let horizontalAlignment: Alignment

  func body(content: Content) -> some View {
    content.frame(
      maxWidth: fillsWidth ? .infinity : nil,
      maxHeight: fillsHeight ? .infinity : nil,
      alignment: fillsHeight ? verticalStretchAlignment : horizontalAlignment)
  }

  private var verticalStretchAlignment: Alignment {
    switch horizontalAlignment {
    case .center: .top
    case .trailing: .topTrailing
    default: .topLeading
    }
  }
}

public func mergeTextStyles(_ base: RufletTextStyle?, _ override: RufletTextStyle?)
  -> RufletTextStyle?
{
  guard base != nil || override != nil else { return nil }
  return RufletTextStyle(
    size: override?.size ?? base?.size,
    weight: override?.weight ?? base?.weight,
    italic: override?.italic ?? base?.italic ?? false,
    fontFamily: override?.fontFamily ?? base?.fontFamily,
    height: override?.height ?? base?.height,
    decoration: override?.decoration ?? base?.decoration ?? 0,
    decorationColor: override?.decorationColor ?? base?.decorationColor,
    decorationThickness: override?.decorationThickness ?? base?.decorationThickness,
    color: override?.color ?? base?.color,
    backgroundColor: override?.backgroundColor ?? base?.backgroundColor,
    letterSpacing: override?.letterSpacing ?? base?.letterSpacing,
    wordSpacing: override?.wordSpacing ?? base?.wordSpacing,
    overflow: override?.overflow ?? base?.overflow)
}

private struct RufletTextFallbackFontModifier: ViewModifier {
  let design: Font.Design
  let enabled: Bool
  let style: RufletTextStyle?

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled, style?.fontFamily == nil {
      content.font(
        .system(
          size: style?.size ?? 14,
          weight: style?.weight ?? .regular,
          design: design))
    } else {
      content
    }
  }
}

#if os(iOS)
  private struct RufletNativeSelectableText: UIViewRepresentable {
    let value: String
    let selectable: Bool
    let style: RufletTextStyle?
    let fallbackDesign: Font.Design
    let textAlignment: TextAlignment
    let maxLines: Int?
    let cursorColor: Color?
    let cursorWidth: CGFloat
    let cursorHeight: CGFloat?
    let showCursor: Bool
    let semanticsLabel: String?
    let onSelection: (RufletTextSelection) -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> RufletSelectableTextView {
      let view = RufletSelectableTextView()
      view.delegate = context.coordinator
      view.backgroundColor = .clear
      view.isEditable = false
      view.isScrollEnabled = false
      view.textContainerInset = .zero
      view.textContainer.lineFragmentPadding = 0
      view.adjustsFontForContentSizeCategory = true
      view.addGestureRecognizer(
        UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap)))
      return view
    }
    func updateUIView(_ view: RufletSelectableTextView, context: Context) {
      context.coordinator.parent = self
      context.coordinator.isUpdating = true
      defer { context.coordinator.isUpdating = false }
      if view.text != value { view.text = value }
      view.isSelectable = selectable
      view.font = style.rufletUIFont(fallbackDesign: fallbackDesign)
      view.textColor = style?.color.map(UIColor.init) ?? .label
      view.backgroundColor = style?.backgroundColor.map(UIColor.init) ?? .clear
      view.textAlignment = textAlignment.rufletNSTextAlignment
      view.textContainer.maximumNumberOfLines = maxLines ?? 0
      view.textContainer.lineBreakMode = style?.overflow.rufletLineBreakMode ?? .byWordWrapping
      view.tintColor = cursorColor.map(UIColor.init) ?? .tintColor
      view.rufletCursorWidth = cursorWidth
      view.rufletCursorHeight = cursorHeight
      view.rufletShowsCursor = showCursor
      view.accessibilityLabel = semanticsLabel ?? value
      view.invalidateIntrinsicContentSize()
    }
    final class Coordinator: NSObject, UITextViewDelegate {
      var parent: RufletNativeSelectableText
      var isUpdating = false
      init(_ parent: RufletNativeSelectableText) { self.parent = parent }
      func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isUpdating else { return }
        parent.onSelection(
          RufletTextSelection(
            baseOffset: textView.selectedRange.location,
            extentOffset: textView.selectedRange.location + textView.selectedRange.length))
      }
      @objc func tap() { parent.onTap() }
    }
  }

  private final class RufletSelectableTextView: UITextView {
    var rufletCursorWidth: CGFloat = 2
    var rufletCursorHeight: CGFloat?
    var rufletShowsCursor = false
    override var intrinsicContentSize: CGSize {
      CGSize(
        width: UIView.noIntrinsicMetric,
        height: sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height)
    }
    override func caretRect(for position: UITextPosition) -> CGRect {
      guard rufletShowsCursor else { return .zero }
      var rect = super.caretRect(for: position)
      rect.size.width = rufletCursorWidth
      if let height = rufletCursorHeight {
        rect.origin.y += (rect.height - height) / 2
        rect.size.height = height
      }
      return rect
    }
  }

  extension Optional where Wrapped == RufletTextStyle {
    fileprivate func rufletUIFont(fallbackDesign: Font.Design) -> UIFont {
      let size = CGFloat(self?.size ?? 14)
      let weight = self?.weight.rufletUIFontWeight ?? .regular
      var font =
        self?.fontFamily.flatMap { UIFont(name: $0, size: size) }
        ?? UIFont.systemFont(ofSize: size, weight: weight)
      if self?.fontFamily == nil,
        let design = fallbackDesign.rufletUIFontDesign,
        let descriptor = font.fontDescriptor.withDesign(design)
      {
        font = UIFont(descriptor: descriptor, size: size)
      }
      if self?.italic == true,
        let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic)
      {
        font = UIFont(descriptor: descriptor, size: size)
      }
      return font
    }
  }

  extension Optional where Wrapped == Font.Weight {
    fileprivate var rufletUIFontWeight: UIFont.Weight {
      guard let value = self else { return .regular }
      if value == .black { return .black }
      if value == .heavy { return .heavy }
      if value == .bold { return .bold }
      if value == .semibold { return .semibold }
      if value == .medium { return .medium }
      if value == .light { return .light }
      if value == .ultraLight { return .ultraLight }
      if value == .thin { return .thin }
      return .regular
    }
  }

  extension Font.Design {
    fileprivate var rufletUIFontDesign: UIFontDescriptor.SystemDesign? {
      switch self {
      case .default: nil
      case .monospaced: .monospaced
      case .rounded: .rounded
      case .serif: .serif
      @unknown default: nil
      }
    }
  }
#elseif os(macOS)
  private struct RufletNativeSelectableText: NSViewRepresentable {
    let value: String
    let selectable: Bool
    let style: RufletTextStyle?
    let fallbackDesign: Font.Design
    let textAlignment: TextAlignment
    let maxLines: Int?
    let cursorColor: Color?
    let cursorWidth: CGFloat
    let cursorHeight: CGFloat?
    let showCursor: Bool
    let semanticsLabel: String?
    let onSelection: (RufletTextSelection) -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> RufletSelectableTextView {
      let view = RufletSelectableTextView()
      view.delegate = context.coordinator
      view.drawsBackground = false
      view.isEditable = false
      view.isRichText = false
      view.textContainerInset = .zero
      view.textContainer?.lineFragmentPadding = 0
      view.onTap = onTap
      return view
    }
    func updateNSView(_ view: RufletSelectableTextView, context: Context) {
      context.coordinator.parent = self
      context.coordinator.isUpdating = true
      defer { context.coordinator.isUpdating = false }
      if view.string != value { view.string = value }
      view.isSelectable = selectable
      view.font = style.rufletNSFont(fallbackDesign: fallbackDesign)
      view.textColor = style?.color.map(NSColor.init) ?? .labelColor
      view.backgroundColor = style?.backgroundColor.map(NSColor.init) ?? .clear
      view.alignment = textAlignment.rufletNSTextAlignment
      view.textContainer?.maximumNumberOfLines = maxLines ?? 0
      view.textContainer?.lineBreakMode = style?.overflow.rufletLineBreakMode ?? .byWordWrapping
      view.insertionPointColor = cursorColor.map(NSColor.init) ?? .controlAccentColor
      view.rufletCursorWidth = cursorWidth
      view.rufletCursorHeight = cursorHeight
      view.rufletShowsCursor = showCursor
      view.onTap = onTap
      view.setAccessibilityLabel(semanticsLabel ?? value)
      view.invalidateIntrinsicContentSize()
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
      var parent: RufletNativeSelectableText
      var isUpdating = false
      init(_ parent: RufletNativeSelectableText) { self.parent = parent }
      func textViewDidChangeSelection(_ notification: Notification) {
        guard !isUpdating else { return }
        guard let view = notification.object as? NSTextView else { return }
        let range = view.selectedRange()
        parent.onSelection(
          RufletTextSelection(
            baseOffset: range.location, extentOffset: range.location + range.length))
      }
    }
  }

  private final class RufletSelectableTextView: NSTextView {
    var onTap: (() -> Void)?
    var rufletCursorWidth: CGFloat = 2
    var rufletCursorHeight: CGFloat?
    var rufletShowsCursor = false
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
      onTap?()
      super.mouseDown(with: event)
    }
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
      guard rufletShowsCursor else { return }
      var cursor = rect
      cursor.size.width = rufletCursorWidth
      if let height = rufletCursorHeight {
        cursor.origin.y += (cursor.height - height) / 2
        cursor.size.height = height
      }
      super.drawInsertionPoint(in: cursor, color: color, turnedOn: flag)
    }
  }

  extension Optional where Wrapped == RufletTextStyle {
    fileprivate func rufletNSFont(fallbackDesign: Font.Design) -> NSFont {
      let size = CGFloat(self?.size ?? 14)
      let weight = self?.weight.rufletNSFontWeight ?? .regular
      var font =
        self?.fontFamily.flatMap { NSFont(name: $0, size: size) }
        ?? (fallbackDesign == .monospaced
          ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
          : NSFont.systemFont(ofSize: size, weight: weight))
      if self?.italic == true {
        font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
      }
      return font
    }
  }

  extension Optional where Wrapped == Font.Weight {
    fileprivate var rufletNSFontWeight: NSFont.Weight {
      guard let value = self else { return .regular }
      if value == .black { return .black }
      if value == .heavy { return .heavy }
      if value == .bold { return .bold }
      if value == .semibold { return .semibold }
      if value == .medium { return .medium }
      if value == .light { return .light }
      if value == .ultraLight { return .ultraLight }
      if value == .thin { return .thin }
      return .regular
    }
  }
#endif

extension TextAlignment {
  fileprivate var rufletNSTextAlignment: NSTextAlignment {
    switch self {
    case .leading: .natural
    case .center: .center
    case .trailing: .right
    }
  }
}

extension Optional where Wrapped == RufletTextOverflow {
  fileprivate var rufletLineBreakMode: NSLineBreakMode {
    switch self {
    case .clip: .byClipping
    case .fade: .byTruncatingMiddle
    case .ellipsis: .byTruncatingTail
    case .visible, nil: .byWordWrapping
    }
  }
}
