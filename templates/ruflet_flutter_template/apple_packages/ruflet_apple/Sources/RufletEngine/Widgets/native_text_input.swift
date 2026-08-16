import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RufletTextSelection: Equatable {
  let baseOffset: Int
  let extentOffset: Int

  var range: NSRange {
    NSRange(location: min(baseOffset, extentOffset), length: abs(extentOffset - baseOffset))
  }

  var value: RufletValue {
    [
      "base_offset": .int(Int64(baseOffset)),
      "extent_offset": .int(Int64(extentOffset)),
      "affinity": .string("downstream"),
      "directional": .bool(false),
    ]
  }
}

struct RufletNativeTextInputConfiguration {
  let value: String
  let selection: RufletTextSelection?
  let multiline: Bool
  let minLines: Int
  let maxLines: Int?
  let fitParentSize: Bool
  let readOnly: Bool
  let password: Bool
  let enabled: Bool
  let autofocus: Bool
  let showCursor: Bool?
  let canRequestFocus: Bool
  let enableInteractiveSelection: Bool?
  let keyboardType: String
  let capitalization: RufletTextCapitalization
  let autocorrect: Bool
  let enableSuggestions: Bool
  let smartDashes: Bool
  let smartQuotes: Bool
  let maxLength: Int?
  let inputFilter: RufletInputFilter?
  let textAlignment: TextAlignment
  let fontSize: Double?
  let fontFamily: String?
  let fontWeight: Font.Weight?
  let italic: Bool
  let textColor: Color?
  let cursorColor: Color?
  var cursorHeight: CGFloat? = nil
  var cursorWidth: CGFloat = 2
  var cursorRadius: CGFloat? = nil
  var animateCursorOpacity = false
  let selectionColor: Color?
  let placeholder: String?
  let placeholderColor: Color?
  var scrollPadding = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
  var textVerticalAlignment = RufletTextFieldVerticalAlignment.center
  var strutStyle: RufletTextFieldStrutStyle? = nil
  var enableStylusHandwriting = true
  var clearButtonSemanticsLabel: String? = nil
  let obscuringCharacter: Character
  let clearButtonMode: RufletOverlayVisibilityMode
  let autofillHints: [String]
  let shiftEnter: Bool
  let ignoreUpDownKeys: Bool
  let keyboardBrightness: String?
  let alwaysCallOnTap: Bool
  let reportsTapOutside: Bool
  let focusRequest: Int
  let blurRequest: Int
}

struct RufletNativeTextInputCallbacks {
  let onChange: (String) -> Void
  let onSubmit: (String) -> Void
  let onFocusChange: (Bool) -> Void
  let onSelectionChange: (RufletTextSelection) -> Void
  let onTap: () -> Void
  let onTapOutside: () -> Void
}

/// Platform-neutral policy shared by the native input bridges. Flet only gives
/// the native field an outside-tap callback when `on_tap_outside` is enabled;
/// a disabled field must therefore install no window-level observer at all.
struct RufletOutsideTapMonitoringContract {
  static func shouldAttach(reportsTapOutside: Bool, hasWindow: Bool) -> Bool {
    reportsTapOutside && hasWindow
  }

  static func shouldReceiveTouch(reportsTapOutside: Bool, isInsideInput: Bool) -> Bool {
    reportsTapOutside && !isInsideInput
  }
}

#if os(iOS)
struct RufletNativeTextInput: UIViewRepresentable {
  let configuration: RufletNativeTextInputConfiguration
  let callbacks: RufletNativeTextInputCallbacks

  func makeUIView(context: Context) -> RufletTextInputUIView {
    RufletTextInputUIView()
  }

  func updateUIView(_ view: RufletTextInputUIView, context: Context) {
    view.update(configuration: configuration, callbacks: callbacks)
  }
}

private final class RufletConfigurableTextField: UITextField {
  var rufletCursorHeight: CGFloat?
  var rufletCursorWidth: CGFloat = 2
  var rufletCursorRadius: CGFloat?

  override func caretRect(for position: UITextPosition) -> CGRect {
    var rect = super.caretRect(for: position)
    rect.size.width = max(rufletCursorWidth, 0)
    if let height = rufletCursorHeight {
      rect.origin.y += (rect.height - height) / 2
      rect.size.height = max(height, 0)
    }
    return rect
  }
}

private final class RufletSubmitTextView: UITextView {
  var submitUnshiftedReturn: (() -> Void)?
  var ignoreUpDownKeys = false
  var rufletCursorHeight: CGFloat?
  var rufletCursorWidth: CGFloat = 2
  var rufletCursorRadius: CGFloat?
  fileprivate var insertingShiftReturn = false

  override func caretRect(for position: UITextPosition) -> CGRect {
    var rect = super.caretRect(for: position)
    rect.size.width = max(rufletCursorWidth, 0)
    if let height = rufletCursorHeight {
      rect.origin.y += (rect.height - height) / 2
      rect.size.height = max(height, 0)
    }
    return rect
  }

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    guard let key = presses.first?.key else {
      super.pressesBegan(presses, with: event)
      return
    }
    if ignoreUpDownKeys,
       key.keyCode == .keyboardUpArrow || key.keyCode == .keyboardDownArrow {
      return
    }
    if key.keyCode == .keyboardReturnOrEnter {
      if key.modifierFlags.contains(.shift) {
        insertingShiftReturn = true
        defer { insertingShiftReturn = false }
        super.pressesBegan(presses, with: event)
      } else if let submitUnshiftedReturn {
        submitUnshiftedReturn()
      } else {
        super.pressesBegan(presses, with: event)
      }
      return
    }
    super.pressesBegan(presses, with: event)
  }
}

final class RufletTextInputUIView: UIView, UITextFieldDelegate, UITextViewDelegate,
  UIGestureRecognizerDelegate, UIScribbleInteractionDelegate
{
  private let textField = RufletConfigurableTextField()
  private let textView = RufletSubmitTextView()
  private var activeView: UIView?
  private var configuration: RufletNativeTextInputConfiguration?
  private var callbacks: RufletNativeTextInputCallbacks?
  private var lastFocusRequest = 0
  private var lastBlurRequest = 0
  private var applying = false
  private weak var monitoredWindow: UIWindow?
  private var outsideTapRecognizer: UITapGestureRecognizer?
  private lazy var textFieldTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(inputTapped(_:)))
  private lazy var textViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(inputTapped(_:)))
  private lazy var scribbleInteraction = UIScribbleInteraction(delegate: self)

  override init(frame: CGRect) {
    super.init(frame: frame)
    textField.delegate = self
    textField.borderStyle = .none
    textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    textField.addTarget(self, action: #selector(textFieldTapped), for: .editingDidBegin)
    textFieldTapRecognizer.cancelsTouchesInView = false
    textFieldTapRecognizer.delegate = self
    textField.addGestureRecognizer(textFieldTapRecognizer)
    textView.delegate = self
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textViewTapRecognizer.cancelsTouchesInView = false
    textViewTapRecognizer.delegate = self
    textView.addGestureRecognizer(textViewTapRecognizer)
    addInteraction(scribbleInteraction)
  }

  required init?(coder: NSCoder) { nil }

  deinit { removeOutsideTapRecognizer() }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    synchronizeOutsideTapRecognizer()
  }

  override var intrinsicContentSize: CGSize {
    guard let configuration else { return CGSize(width: UIView.noIntrinsicMetric, height: 34) }
    if configuration.fitParentSize { return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
    let lines = max(configuration.minLines, 1)
    let lineHeight = configuration.strutStyle?.lineHeight ?? configuration.uiFont.lineHeight
    return CGSize(
      width: UIView.noIntrinsicMetric,
      height: ceil(CGFloat(lines) * lineHeight) + 4)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let activeView, let configuration else { return }
    let intrinsic = activeView.intrinsicContentSize.height
    let naturalHeight = intrinsic > 0 ? min(intrinsic, bounds.height) : bounds.height
    let height = configuration.multiline ? bounds.height : naturalHeight
    let y: CGFloat
    switch configuration.textVerticalAlignment {
    case .top: y = 0
    case .center: y = (bounds.height - height) / 2
    case .bottom: y = bounds.height - height
    }
    activeView.frame = CGRect(x: 0, y: y, width: bounds.width, height: height)
  }

  func update(
    configuration: RufletNativeTextInputConfiguration,
    callbacks: RufletNativeTextInputCallbacks
  ) {
    self.configuration = configuration
    self.callbacks = callbacks
    synchronizeOutsideTapRecognizer()
    let nextView: UIView = configuration.multiline ? textView : textField
    if activeView !== nextView {
      activeView?.removeFromSuperview()
      activeView = nextView
      addSubview(nextView)
      setNeedsLayout()
    }

    applying = true
    let text = configuration.value
    if textField.text != text { textField.text = text }
    if textView.text != text { textView.text = text }
    textField.isEnabled = configuration.enabled
    textView.isEditable = configuration.enabled && !configuration.readOnly
    textField.isUserInteractionEnabled = configuration.enabled
    textField.isSecureTextEntry = configuration.password
    textField.clearsOnBeginEditing = false
    textField.clearButtonMode = configuration.clearButtonMode.uiKit
    textField.placeholder = configuration.placeholder
    textField.attributedPlaceholder = configuration.placeholder.map {
      NSAttributedString(
        string: $0,
        attributes: [.foregroundColor: configuration.placeholderColor.map(UIColor.init) ?? UIColor.placeholderText])
    }
    textField.textAlignment = configuration.textAlignment.nsTextAlignment
    textView.textAlignment = configuration.textAlignment.nsTextAlignment
    textField.textColor = configuration.textColor.map(UIColor.init)
    textView.textColor = configuration.textColor.map(UIColor.init)
    textField.tintColor = configuration.showCursor == false
      ? .clear : configuration.cursorColor.map(UIColor.init)
    textView.tintColor = configuration.showCursor == false
      ? .clear : configuration.cursorColor.map(UIColor.init)
    textField.rufletCursorHeight = configuration.cursorHeight
    textField.rufletCursorWidth = configuration.cursorWidth
    textField.rufletCursorRadius = configuration.cursorRadius
    textView.rufletCursorHeight = configuration.cursorHeight
    textView.rufletCursorWidth = configuration.cursorWidth
    textView.rufletCursorRadius = configuration.cursorRadius
    textField.font = configuration.uiFont
    textView.font = configuration.uiFont
    textField.keyboardType = configuration.keyboardType.uiKeyboardType
    textView.keyboardType = configuration.keyboardType.uiKeyboardType
    textField.autocapitalizationType = configuration.capitalization.uiTextAutocapitalizationType
    textView.autocapitalizationType = configuration.capitalization.uiTextAutocapitalizationType
    textField.autocorrectionType = configuration.autocorrect ? .yes : .no
    textView.autocorrectionType = configuration.autocorrect ? .yes : .no
    textField.spellCheckingType = configuration.enableSuggestions ? .yes : .no
    textView.spellCheckingType = configuration.enableSuggestions ? .yes : .no
    textField.smartDashesType = configuration.smartDashes ? .yes : .no
    textView.smartDashesType = configuration.smartDashes ? .yes : .no
    textField.smartQuotesType = configuration.smartQuotes ? .yes : .no
    textView.smartQuotesType = configuration.smartQuotes ? .yes : .no
    textField.textContentType = configuration.autofillHints.first?.uiTextContentType
    textView.textContentType = configuration.autofillHints.first?.uiTextContentType
    textField.keyboardAppearance = configuration.keyboardBrightness.uiKeyboardAppearance
    textView.keyboardAppearance = configuration.keyboardBrightness.uiKeyboardAppearance
    textView.scrollIndicatorInsets = configuration.scrollPadding.uiEdgeInsets
    textView.isSelectable = configuration.enableInteractiveSelection ?? true
    textField.isUserInteractionEnabled = configuration.enabled
      && (configuration.canRequestFocus || textField.isFirstResponder)
    textView.isUserInteractionEnabled = configuration.enabled
      && (configuration.canRequestFocus || textView.isFirstResponder)
    textView.ignoreUpDownKeys = configuration.ignoreUpDownKeys
    textView.submitUnshiftedReturn = configuration.shiftEnter
      ? { [weak self] in self?.callbacks?.onSubmit(self?.textView.text ?? "") }
      : nil
    applyStrutStyle(configuration.strutStyle)
    updateClearButtonSemantics(configuration.clearButtonSemanticsLabel)
    applySelection(configuration.selection)
    applying = false

    if configuration.autofocus && lastFocusRequest == 0 && !nextView.isFirstResponder {
      DispatchQueue.main.async { nextView.becomeFirstResponder() }
    }
    if configuration.focusRequest != lastFocusRequest {
      lastFocusRequest = configuration.focusRequest
      DispatchQueue.main.async { if configuration.canRequestFocus { nextView.becomeFirstResponder() } }
    }
    if configuration.blurRequest != lastBlurRequest {
      lastBlurRequest = configuration.blurRequest
      DispatchQueue.main.async { nextView.resignFirstResponder() }
    }
    invalidateIntrinsicContentSize()
    setNeedsLayout()
  }

  func scribbleInteraction(
    _ interaction: UIScribbleInteraction,
    shouldBeginAt location: CGPoint
  ) -> Bool {
    configuration?.enableStylusHandwriting ?? true
  }

  private func updateClearButtonSemantics(_ label: String?) {
    guard let label else { return }
    for button in textField.subviews.compactMap({ $0 as? UIButton }) {
      button.accessibilityLabel = label
    }
  }

  private func applyStrutStyle(_ style: RufletTextFieldStrutStyle?) {
    guard let height = style?.lineHeight else {
      textView.typingAttributes[.paragraphStyle] = nil
      return
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.minimumLineHeight = height
    if style?.forceHeight == true { paragraph.maximumLineHeight = height }
    textView.typingAttributes[.paragraphStyle] = paragraph
  }

  @objc private func textFieldChanged() { changed(textField.text ?? "") }
  @objc private func textFieldTapped() { callbacks?.onTap() }
  @objc private func inputTapped(_ recognizer: UITapGestureRecognizer) {
    guard configuration?.alwaysCallOnTap == true,
          recognizer.state == .ended,
          activeView?.isFirstResponder == true
    else { return }
    callbacks?.onTap()
  }
  @objc private func windowTapped(_ recognizer: UITapGestureRecognizer) {
    guard configuration?.reportsTapOutside == true, recognizer.state == .ended else { return }
    let point = recognizer.location(in: self)
    if !bounds.contains(point) { callbacks?.onTapOutside() }
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldReceive touch: UITouch
  ) -> Bool {
    guard gestureRecognizer === outsideTapRecognizer else { return true }
    let isInsideInput = touch.view.map { $0 === self || $0.isDescendant(of: self) } ?? false
    return RufletOutsideTapMonitoringContract.shouldReceiveTouch(
      reportsTapOutside: configuration?.reportsTapOutside == true,
      isInsideInput: isInsideInput)
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    gestureRecognizer === outsideTapRecognizer || otherGestureRecognizer === outsideTapRecognizer
  }

  private func synchronizeOutsideTapRecognizer() {
    let shouldAttach = RufletOutsideTapMonitoringContract.shouldAttach(
      reportsTapOutside: configuration?.reportsTapOutside == true,
      hasWindow: window != nil)
    let targetWindow = shouldAttach ? window : nil
    if let targetWindow,
       monitoredWindow === targetWindow,
       outsideTapRecognizer != nil {
      return
    }
    removeOutsideTapRecognizer()
    guard let targetWindow else { return }
    let recognizer = UITapGestureRecognizer(target: self, action: #selector(windowTapped(_:)))
    recognizer.cancelsTouchesInView = false
    recognizer.delaysTouchesBegan = false
    recognizer.delaysTouchesEnded = false
    recognizer.delegate = self
    targetWindow.addGestureRecognizer(recognizer)
    outsideTapRecognizer = recognizer
    monitoredWindow = targetWindow
  }

  private func removeOutsideTapRecognizer() {
    if let outsideTapRecognizer {
      monitoredWindow?.removeGestureRecognizer(outsideTapRecognizer)
    }
    outsideTapRecognizer = nil
    monitoredWindow = nil
  }

  func textViewDidChange(_ textView: UITextView) { changed(textView.text) }
  func textViewDidBeginEditing(_ textView: UITextView) {
    callbacks?.onTap()
    callbacks?.onFocusChange(true)
  }
  func textViewDidEndEditing(_ textView: UITextView) { callbacks?.onFocusChange(false) }
  func textViewDidChangeSelection(_ textView: UITextView) {
    selectionChanged(textView.selectedRange)
  }
  func textFieldDidBeginEditing(_ textField: UITextField) { callbacks?.onFocusChange(true) }
  func textFieldDidEndEditing(_ textField: UITextField) { callbacks?.onFocusChange(false) }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    callbacks?.onSubmit(textField.text ?? "")
    return false
  }
  func textFieldDidChangeSelection(_ textField: UITextField) {
    guard let range = textField.selectedTextRange else { return }
    selectionChanged(NSRange(
      location: textField.offset(from: textField.beginningOfDocument, to: range.start),
      length: textField.offset(from: range.start, to: range.end)))
  }

  func textField(
    _ textField: UITextField,
    shouldChangeCharactersIn range: NSRange,
    replacementString string: String
  ) -> Bool {
    shouldApply(
      to: textField,
      current: textField.text ?? "",
      selection: textFieldSelection(textField),
      composing: textRange(textField.markedTextRange, in: textField),
      range: range,
      replacement: string)
  }

  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    shouldApply(
      to: textField,
      current: textField.text ?? "",
      selection: textFieldSelection(textField),
      composing: textRange(textField.markedTextRange, in: textField),
      range: NSRange(location: 0, length: (textField.text ?? "").utf16.count),
      replacement: "")
  }

  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if text == "\n", configuration?.shiftEnter == true {
      if (textView as? RufletSubmitTextView)?.insertingShiftReturn == true {
        return shouldApply(
          to: textView,
          current: textView.text,
          selection: textView.selectedRange,
          composing: textRange(textView.markedTextRange, in: textView),
          range: range,
          replacement: text)
      }
      callbacks?.onSubmit(textView.text)
      return false
    }
    return shouldApply(
      to: textView,
      current: textView.text,
      selection: textView.selectedRange,
      composing: textRange(textView.markedTextRange, in: textView),
      range: range,
      replacement: text)
  }

  private func shouldApply(
    to input: UITextInput,
    current: String,
    selection: NSRange,
    composing: NSRange?,
    range: NSRange,
    replacement: String
  ) -> Bool {
    guard let configuration, !configuration.readOnly,
      let transaction = formatRufletTextEdit(
        current: RufletTextEditSnapshot(
          text: current,
          selection: selection,
          composing: composing),
        replacementRange: range,
        replacement: replacement,
        capitalization: configuration.capitalization,
        maxLength: configuration.maxLength,
        inputFilter: configuration.inputFilter)
    else { return false }
    guard transaction.requiresManualMutation else { return true }
    apply(transaction.formattedValue, to: input)
    return false
  }

  private func changed(_ value: String) {
    guard !applying else { return }
    callbacks?.onChange(value)
  }

  private func apply(_ value: RufletTextEditSnapshot, to input: UITextInput) {
    applying = true
    defer { applying = false }
    if let field = input as? UITextField { field.text = value.text }
    if let view = input as? UITextView { view.text = value.text }
    if let composing = value.composing,
      let range = textRange(composing, in: input),
      let marked = Range(composing, in: value.text).map({ String(value.text[$0]) })
    {
      input.selectedTextRange = range
      let relative = NSRange(
        location: min(max(value.selection.location - composing.location, 0), composing.length),
        length: min(value.selection.length, composing.length))
      input.setMarkedText(marked, selectedRange: relative)
    } else if let range = textRange(value.selection, in: input) {
      input.selectedTextRange = range
    }
    callbacks?.onChange(value.text)
    callbacks?.onSelectionChange(RufletTextSelection(
      baseOffset: value.selection.location,
      extentOffset: NSMaxRange(value.selection)))
  }

  private func textFieldSelection(_ textField: UITextField) -> NSRange {
    textRange(textField.selectedTextRange, in: textField) ?? NSRange(
      location: (textField.text ?? "").utf16.count,
      length: 0)
  }

  private func textRange(_ range: UITextRange?, in input: UITextInput) -> NSRange? {
    guard let range else { return nil }
    return NSRange(
      location: input.offset(from: input.beginningOfDocument, to: range.start),
      length: input.offset(from: range.start, to: range.end))
  }

  private func textRange(_ range: NSRange, in input: UITextInput) -> UITextRange? {
    guard let start = input.position(from: input.beginningOfDocument, offset: range.location),
      let end = input.position(from: start, offset: range.length)
    else { return nil }
    return input.textRange(from: start, to: end)
  }

  private func applySelection(_ selection: RufletTextSelection?) {
    guard let selection else { return }
    let length = configuration?.value.utf16.count ?? 0
    let range = NSRange(
      location: min(max(selection.range.location, 0), length),
      length: min(max(selection.range.length, 0), max(length - selection.range.location, 0)))
    textView.selectedRange = range
    if let start = textField.position(from: textField.beginningOfDocument, offset: range.location),
       let end = textField.position(from: start, offset: range.length) {
      textField.selectedTextRange = textField.textRange(from: start, to: end)
    }
  }

  private func selectionChanged(_ range: NSRange) {
    guard !applying else { return }
    callbacks?.onSelectionChange(RufletTextSelection(
      baseOffset: range.location,
      extentOffset: range.location + range.length))
  }
}

private extension String {
  var uiKeyboardType: UIKeyboardType {
    switch lowercased() {
    case "datetime": .numbersAndPunctuation
    case "email": .emailAddress
    case "name": .namePhonePad
    case "none": .default
    case "number": .decimalPad
    case "phone": .phonePad
    case "streetaddress": .default
    case "url": .URL
    case "visiblepassword": .asciiCapable
    case "websearch": .webSearch
    case "twitter": .twitter
    default: .default
    }
  }

  var uiTextContentType: UITextContentType? {
    switch lowercased() {
    case "email": .emailAddress
    case "name": .name
    case "username", "newusername": .username
    case "password": .password
    case "newpassword": .newPassword
    case "onetimecode": .oneTimeCode
    case "telephonenumber": .telephoneNumber
    case "url": .URL
    case "postalcode": .postalCode
    case "streetaddressline1": .streetAddressLine1
    case "streetaddressline2": .streetAddressLine2
    default: nil
    }
  }
}

private extension Optional where Wrapped == String {
  var uiKeyboardAppearance: UIKeyboardAppearance {
    switch self?.lowercased() {
    case "dark": .dark
    case "light": .light
    default: .default
    }
  }
}

private extension RufletOverlayVisibilityMode {
  var uiKit: UITextField.ViewMode {
    switch self {
    case .never: .never
    case .always: .always
    case .editing: .whileEditing
    case .notEditing: .unlessEditing
    }
  }
}

private extension RufletTextCapitalization {
  var uiTextAutocapitalizationType: UITextAutocapitalizationType {
    switch self {
    case .words: .words
    case .sentences: .sentences
    case .characters: .allCharacters
    case .none: .none
    }
  }
}

private extension TextAlignment {
  var nsTextAlignment: NSTextAlignment {
    switch self {
    case .leading: .natural
    case .center: .center
    case .trailing: .right
    }
  }
}

private extension RufletNativeTextInputConfiguration {
  var uiFont: UIFont {
    let size = CGFloat(fontSize ?? 17)
    let base = fontFamily.flatMap { UIFont(name: $0, size: size) }
      ?? UIFont.systemFont(ofSize: size, weight: fontWeight.uiFontWeight)
    guard italic, let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) else { return base }
    return UIFont(descriptor: descriptor, size: size)
  }
}

private extension Optional where Wrapped == Font.Weight {
  var uiFontWeight: UIFont.Weight {
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

private extension EdgeInsets {
  var uiEdgeInsets: UIEdgeInsets {
    UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
  }
}
#elseif os(macOS)
struct RufletNativeTextInput: NSViewRepresentable {
  let configuration: RufletNativeTextInputConfiguration
  let callbacks: RufletNativeTextInputCallbacks

  func makeNSView(context: Context) -> RufletTextInputNSView { RufletTextInputNSView() }
  func updateNSView(_ view: RufletTextInputNSView, context: Context) {
    view.update(configuration: configuration, callbacks: callbacks)
  }
}

private final class RufletTextInputNSTextView: NSTextView {
  var rufletCursorHeight: CGFloat?
  var rufletCursorWidth: CGFloat = 2
  var rufletCursorRadius: CGFloat?
  var rufletAnimateCursorOpacity = false

  override func drawInsertionPoint(
    in rect: NSRect,
    color: NSColor,
    turnedOn flag: Bool
  ) {
    var cursor = rect
    cursor.size.width = max(rufletCursorWidth, 0)
    if let height = rufletCursorHeight {
      cursor.origin.y += (cursor.height - height) / 2
      cursor.size.height = max(height, 0)
    }
    guard flag || !rufletAnimateCursorOpacity else {
      super.drawInsertionPoint(in: cursor, color: color, turnedOn: false)
      return
    }
    color.setFill()
    NSBezierPath(
      roundedRect: cursor,
      xRadius: rufletCursorRadius ?? 0,
      yRadius: rufletCursorRadius ?? 0).fill()
  }
}

final class RufletTextInputNSView: NSView, NSTextFieldDelegate, NSTextViewDelegate {
  private let textField = NSTextField()
  private let secureField = NSSecureTextField()
  private let textView = RufletTextInputNSTextView()
  private let scrollView = NSScrollView()
  private var activeView: NSView?
  private var activeField: NSTextField { configuration?.password == true ? secureField : textField }
  private var configuration: RufletNativeTextInputConfiguration?
  private var callbacks: RufletNativeTextInputCallbacks?
  private var lastFocusRequest = 0
  private var lastBlurRequest = 0
  private var applying = false
  private var outsideEventMonitor: Any?
  private lazy var textFieldTapRecognizer = NSClickGestureRecognizer(target: self, action: #selector(inputTapped(_:)))
  private lazy var secureFieldTapRecognizer = NSClickGestureRecognizer(target: self, action: #selector(inputTapped(_:)))
  private lazy var textViewTapRecognizer = NSClickGestureRecognizer(target: self, action: #selector(inputTapped(_:)))

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    for field in [textField, secureField] {
      field.delegate = self
      field.isBordered = false
      field.drawsBackground = false
      field.focusRingType = .none
    }
    textField.addGestureRecognizer(textFieldTapRecognizer)
    secureField.addGestureRecognizer(secureFieldTapRecognizer)
    textView.delegate = self
    textView.drawsBackground = false
    textView.isRichText = false
    textView.textContainerInset = .zero
    textView.addGestureRecognizer(textViewTapRecognizer)
    scrollView.documentView = textView
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.borderType = .noBorder
  }

  required init?(coder: NSCoder) { nil }

  deinit { removeOutsideEventMonitor() }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    synchronizeOutsideEventMonitor()
  }

  override var intrinsicContentSize: NSSize {
    guard let configuration else { return NSSize(width: NSView.noIntrinsicMetric, height: 24) }
    if configuration.fitParentSize { return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }
    return NSSize(width: NSView.noIntrinsicMetric, height: CGFloat(max(configuration.minLines, 1)) * 20 + 4)
  }

  override func layout() {
    super.layout()
    guard let activeView, let configuration else { return }
    let naturalHeight = activeView.intrinsicContentSize.height
    let height = configuration.multiline || naturalHeight <= 0
      ? bounds.height : min(naturalHeight, bounds.height)
    let y: CGFloat
    switch configuration.textVerticalAlignment {
    case .top: y = bounds.height - height
    case .center: y = (bounds.height - height) / 2
    case .bottom: y = 0
    }
    activeView.frame = NSRect(x: 0, y: y, width: bounds.width, height: height)
  }

  func update(configuration: RufletNativeTextInputConfiguration, callbacks: RufletNativeTextInputCallbacks) {
    self.configuration = configuration
    self.callbacks = callbacks
    synchronizeOutsideEventMonitor()
    let nextView: NSView = configuration.multiline ? scrollView : activeField
    if activeView !== nextView {
      activeView?.removeFromSuperview()
      activeView = nextView
      addSubview(nextView)
      needsLayout = true
    }
    applying = true
    if activeField.stringValue != configuration.value { activeField.stringValue = configuration.value }
    if textView.string != configuration.value { textView.string = configuration.value }
    activeField.isEnabled = configuration.enabled
    activeField.isEditable = !configuration.readOnly
    activeField.isSelectable = configuration.enableInteractiveSelection ?? true
    activeField.placeholderString = configuration.placeholder
    activeField.alignment = configuration.textAlignment.nsTextAlignment
    textView.alignment = configuration.textAlignment.nsTextAlignment
    activeField.textColor = configuration.textColor.map(NSColor.init)
    textView.textColor = configuration.textColor.map(NSColor.init)
    textView.insertionPointColor = configuration.showCursor == false
      ? .clear : configuration.cursorColor.map(NSColor.init) ?? .controlAccentColor
    textView.rufletCursorHeight = configuration.cursorHeight
    textView.rufletCursorWidth = configuration.cursorWidth
    textView.rufletCursorRadius = configuration.cursorRadius
    textView.rufletAnimateCursorOpacity = configuration.animateCursorOpacity
    textView.isEditable = configuration.enabled && !configuration.readOnly
    textView.isSelectable = configuration.enableInteractiveSelection ?? true
    activeField.font = configuration.nsFont
    textView.font = configuration.nsFont
    scrollView.contentInsets = configuration.scrollPadding.nsEdgeInsets
    applyStrutStyle(configuration.strutStyle)
    if let selectionColor = configuration.selectionColor.map(NSColor.init) {
      textView.selectedTextAttributes = [.backgroundColor: selectionColor]
      if let editor = window?.fieldEditor(false, for: activeField) as? NSTextView {
        editor.selectedTextAttributes = [.backgroundColor: selectionColor]
      }
    }
    applySelection(configuration.selection)
    applying = false
    if configuration.autofocus && lastFocusRequest == 0 {
      DispatchQueue.main.async { self.window?.makeFirstResponder(nextView) }
    }
    if configuration.focusRequest != lastFocusRequest {
      lastFocusRequest = configuration.focusRequest
      DispatchQueue.main.async { if configuration.canRequestFocus { self.window?.makeFirstResponder(nextView) } }
    }
    if configuration.blurRequest != lastBlurRequest {
      lastBlurRequest = configuration.blurRequest
      DispatchQueue.main.async { self.window?.makeFirstResponder(nil) }
    }
    invalidateIntrinsicContentSize()
    needsLayout = true
  }

  private func synchronizeOutsideEventMonitor() {
    let shouldAttach = RufletOutsideTapMonitoringContract.shouldAttach(
      reportsTapOutside: configuration?.reportsTapOutside == true,
      hasWindow: window != nil)
    guard shouldAttach else {
      removeOutsideEventMonitor()
      return
    }
    guard outsideEventMonitor == nil else { return }
    outsideEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
      guard let self,
            self.configuration?.reportsTapOutside == true,
            event.window === self.window,
            !self.bounds.contains(self.convert(event.locationInWindow, from: nil))
      else { return event }
      self.callbacks?.onTapOutside()
      return event
    }
  }

  private func removeOutsideEventMonitor() {
    guard let outsideEventMonitor else { return }
    NSEvent.removeMonitor(outsideEventMonitor)
    self.outsideEventMonitor = nil
  }

  private func applyStrutStyle(_ style: RufletTextFieldStrutStyle?) {
    guard let height = style?.lineHeight else {
      textView.defaultParagraphStyle = nil
      return
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.minimumLineHeight = height
    if style?.forceHeight == true { paragraph.maximumLineHeight = height }
    textView.defaultParagraphStyle = paragraph
    textView.typingAttributes[.paragraphStyle] = paragraph
  }

  func controlTextDidBeginEditing(_ obj: Notification) {
    callbacks?.onTap()
    callbacks?.onFocusChange(true)
  }
  func controlTextDidEndEditing(_ obj: Notification) { callbacks?.onFocusChange(false) }
  func controlTextDidChange(_ obj: Notification) { changed(activeField.stringValue) }
  @objc private func inputTapped(_ recognizer: NSClickGestureRecognizer) {
    guard configuration?.alwaysCallOnTap == true,
          recognizer.state == .ended,
          window?.firstResponder === activeField.currentEditor() || window?.firstResponder === textView
    else { return }
    callbacks?.onTap()
  }
  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      callbacks?.onSubmit(activeField.stringValue)
      return true
    }
    if configuration?.ignoreUpDownKeys == true,
       (commandSelector == #selector(NSResponder.moveUp(_:))
        || commandSelector == #selector(NSResponder.moveDown(_:))) {
      return true
    }
    return false
  }
  func textDidBeginEditing(_ notification: Notification) {
    callbacks?.onTap()
    callbacks?.onFocusChange(true)
  }
  func textDidEndEditing(_ notification: Notification) { callbacks?.onFocusChange(false) }
  func textDidChange(_ notification: Notification) { changed(textView.string) }
  func textViewDidChangeSelection(_ notification: Notification) {
    selectionChanged(textView.selectedRange())
  }
  func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(NSResponder.insertNewline(_:)), configuration?.shiftEnter == true {
      if NSEvent.modifierFlags.contains(.shift) { return false }
      callbacks?.onSubmit(textView.string)
      return true
    }
    if configuration?.ignoreUpDownKeys == true,
       (commandSelector == #selector(NSResponder.moveUp(_:))
        || commandSelector == #selector(NSResponder.moveDown(_:))) {
      return true
    }
    return false
  }
  func textView(
    _ textView: NSTextView,
    shouldChangeTextIn affectedCharRange: NSRange,
    replacementString: String?
  ) -> Bool {
    shouldApply(
      to: textView,
      current: textView.string,
      range: affectedCharRange,
      replacement: replacementString ?? "")
  }
  func control(
    _ control: NSControl,
    textView: NSTextView,
    shouldChangeCharactersIn affectedCharRange: NSRange,
    replacementString: String?
  ) -> Bool {
    shouldApply(
      to: textView,
      current: textView.string,
      range: affectedCharRange,
      replacement: replacementString ?? "")
  }

  private func shouldApply(
    to editor: NSTextView,
    current: String,
    range: NSRange,
    replacement: String
  ) -> Bool {
    guard let configuration, !configuration.readOnly,
      let transaction = formatRufletTextEdit(
        current: RufletTextEditSnapshot(
          text: current,
          selection: editor.selectedRange(),
          composing: editor.markedRange().location == NSNotFound ? nil : editor.markedRange()),
        replacementRange: range,
        replacement: replacement,
        capitalization: configuration.capitalization,
        maxLength: configuration.maxLength,
        inputFilter: configuration.inputFilter)
    else { return false }
    guard transaction.requiresManualMutation else { return true }
    apply(transaction.formattedValue, to: editor)
    return false
  }

  private func changed(_ value: String) {
    guard !applying else { return }
    callbacks?.onChange(value)
    if let editor = window?.fieldEditor(false, for: activeField) as? NSTextView {
      selectionChanged(editor.selectedRange())
    }
  }

  private func apply(_ value: RufletTextEditSnapshot, to editor: NSTextView) {
    applying = true
    defer { applying = false }
    if editor !== textView { activeField.stringValue = value.text }
    editor.string = value.text
    if let composing = value.composing,
      let range = Range(composing, in: value.text)
    {
      editor.setSelectedRange(composing)
      let relative = NSRange(
        location: min(max(value.selection.location - composing.location, 0), composing.length),
        length: min(value.selection.length, composing.length))
      editor.setMarkedText(
        String(value.text[range]),
        selectedRange: relative,
        replacementRange: composing)
    } else {
      editor.setSelectedRange(value.selection)
    }
    callbacks?.onChange(value.text)
    callbacks?.onSelectionChange(RufletTextSelection(
      baseOffset: value.selection.location,
      extentOffset: NSMaxRange(value.selection)))
  }

  private func applySelection(_ selection: RufletTextSelection?) {
    guard let selection else { return }
    let length = configuration?.value.utf16.count ?? 0
    let range = NSRange(
      location: min(max(selection.range.location, 0), length),
      length: min(max(selection.range.length, 0), max(length - selection.range.location, 0)))
    textView.setSelectedRange(range)
    if let editor = window?.fieldEditor(false, for: activeField) as? NSTextView {
      editor.setSelectedRange(range)
    }
  }

  private func selectionChanged(_ range: NSRange) {
    guard !applying else { return }
    callbacks?.onSelectionChange(RufletTextSelection(
      baseOffset: range.location,
      extentOffset: range.location + range.length))
  }
}

private extension TextAlignment {
  var nsTextAlignment: NSTextAlignment {
    switch self {
    case .leading: .natural
    case .center: .center
    case .trailing: .right
    }
  }
}

private extension RufletNativeTextInputConfiguration {
  var nsFont: NSFont {
    let size = CGFloat(fontSize ?? 14)
    let base = fontFamily.flatMap { NSFont(name: $0, size: size) }
      ?? NSFont.systemFont(ofSize: size, weight: fontWeight.nsFontWeight)
    guard italic else { return base }
    return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
  }
}

private extension Optional where Wrapped == Font.Weight {
  var nsFontWeight: NSFont.Weight {
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

private extension EdgeInsets {
  var nsEdgeInsets: NSEdgeInsets {
    NSEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
  }
}
#endif

enum RufletOverlayVisibilityMode: String, CaseIterable, RufletStringEnum {
  case never, always, editing, notEditing
}
