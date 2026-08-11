import RufletEngine
import RufletProtocol
import SwiftUI

/// The input configuration a Flet text field carries, read once from the node
/// so the UIKit and AppKit fields can each apply whatever their platform has.
///
/// Flet's spellings are the vendored ones: `keyboard_type` takes the keys
/// `parseTextInputType` accepts, `capitalization` the `TextCapitalization`
/// case names, and the two smart-substitution properties are enums whose only
/// meaningful value here is `disabled`.
struct RufletTextInputTraits {
  var keyboardType: String?
  var capitalization: String?
  var autocorrect = true
  var enableSuggestions = true
  var smartDashes = true
  var smartQuotes = true
  var readOnly = false
  var maxLength: Int?
  var textAlign: String?
  var showCursor = true
  var cursorColor: Color?
  var selectionColor: Color?
  var autofillHint: String?
  var enableInteractiveSelection = true
  var textColor: Color?
  var fontSize: CGFloat?
  var canRequestFocus = true
  var ignorePointers = false
  var keyboardBrightness: String?
  var inputFilter: InputFilter?
  /// Flutter's `cursorWidth` defaults to 2; the height follows the line when
  /// it is not given, and the radius squares off.
  var cursorWidth: CGFloat = 2
  var cursorHeight: CGFloat?
  var cursorRadius: CGFloat?
  var cursorErrorColor: Color?
  var animateCursorOpacity = true
  var obscuringCharacter = "•"
  var hasError = false
  var alwaysCallOnTap = false
  var stylusHandwriting = true
  var ignoresUpDownKeys = false
  /// Flutter's `StrutStyle` forces a minimum line box. Only the metrics that
  /// have a paragraph-style counterpart are carried.
  var strutHeight: CGFloat?
  var strutLeading: CGFloat?

  /// The caret colour Flutter resolves: the error colour wins while the field
  /// is in error, then `cursor_color`, then the platform tint.
  var resolvedCursorColor: Color? {
    if hasError, let cursorErrorColor { return cursorErrorColor }
    return cursorColor ?? selectionColor
  }

  /// True when Ruby asked for anything the system caret cannot do, in which
  /// case the field draws its own.
  var needsCustomCaret: Bool {
    cursorWidth != 2 || cursorHeight != nil || cursorRadius != nil || !animateCursorOpacity
  }

  /// Flet's `input_filter`, which is a `FilteringTextInputFormatter` built
  /// from a regular expression.
  ///
  /// Allowing keeps the runs that match and rewrites everything between them;
  /// denying does the opposite. Both substitute `replacement_string`, which is
  /// empty by default and so simply drops the rejected text.
  struct InputFilter {
    let expression: NSRegularExpression
    let allow: Bool
    let replacement: String

    init?(_ value: RufletValue?) {
      guard let map = value?.mapValue,
        let pattern = map["regex_string"]?.stringValue, !pattern.isEmpty
      else { return nil }
      var options: NSRegularExpression.Options = []
      if map["case_sensitive"]?.boolValue == false { options.insert(.caseInsensitive) }
      if map["multiline"]?.boolValue == true { options.insert(.anchorsMatchLines) }
      if map["dot_all"]?.boolValue == true { options.insert(.dotMatchesLineSeparators) }
      guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
        return nil
      }
      self.expression = expression
      allow = map["allow"]?.boolValue ?? true
      replacement = map["replacement_string"]?.stringValue ?? ""
    }

    func apply(to text: String) -> String {
      let full = NSRange(location: 0, length: (text as NSString).length)
      guard allow else {
        return expression.stringByReplacingMatches(
          in: text, range: full, withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
      }
      let source = text as NSString
      var kept = ""
      var cursor = 0
      for match in expression.matches(in: text, range: full) {
        if match.range.location > cursor { kept += replacement }
        kept += source.substring(with: match.range)
        cursor = NSMaxRange(match.range)
      }
      if cursor < source.length { kept += replacement }
      return kept
    }
  }

  init() {}

  init(node: ControlNode) {
    keyboardType = node.string("keyboard_type")?.lowercased()
    capitalization = node.string("capitalization")?.lowercased()
    autocorrect = node.bool("autocorrect") ?? true
    enableSuggestions = node.bool("enable_suggestions") ?? true
    smartDashes = node.string("smart_dashes_type")?.lowercased() != "disabled"
    smartQuotes = node.string("smart_quotes_type")?.lowercased() != "disabled"
    readOnly = node.bool("read_only") ?? false
    // Flet treats a non-positive max_length as "no limit", the way
    // TextField's maxLength does.
    maxLength = node.int("max_length").flatMap { $0 > 0 ? $0 : nil }
    textAlign = node.string("text_align")?.lowercased()
    showCursor = node.bool("show_cursor") ?? true
    cursorColor = MaterialPalette.color(node.string("cursor_color"))
    selectionColor = MaterialPalette.color(node.string("selection_color"))
    autofillHint = node.array("autofill_hints")?.first?.stringValue
      ?? node.string("autofill_hints")
    enableInteractiveSelection = node.bool("enable_interactive_selection") ?? true
    textColor = MaterialPalette.color(node.string("color"))
    fontSize = node.double("text_size").map { CGFloat($0) }
    canRequestFocus = node.bool("can_request_focus") ?? true
    ignorePointers = node.bool("ignore_pointers") ?? false
    keyboardBrightness = node.string("keyboard_brightness")?.lowercased()
    inputFilter = InputFilter(node.props["input_filter"])
    cursorWidth = CGFloat(node.double("cursor_width") ?? 2)
    cursorHeight = node.double("cursor_height").map { CGFloat($0) }
    cursorRadius = ControlProps.cornerRadius(node.props["cursor_radius"])
    cursorErrorColor = MaterialPalette.color(node.string("cursor_error_color"))
    animateCursorOpacity = node.bool("animate_cursor_opacity") ?? true
    obscuringCharacter = node.string("obscuring_character") ?? "•"
    hasError = node.controlID(forKey: "error") != nil
      || !(node.string("error") ?? node.string("error_text") ?? "").isEmpty
    alwaysCallOnTap = node.bool("always_call_on_tap") ?? false
    stylusHandwriting = node.bool("enable_stylus_handwriting") ?? true
    ignoresUpDownKeys = node.bool("ignore_up_down_keys") ?? false
    if let strut = node.map("strut_style") {
      strutHeight = strut["height"]?.doubleValue.map { CGFloat($0) }
      strutLeading = strut["leading"]?.doubleValue.map { CGFloat($0) }
    }
  }

  /// The filter and the length limit in the order Flutter applies its
  /// formatters: the input filter first, then the length limit.
  func formatted(_ text: String) -> String {
    limited(inputFilter?.apply(to: text) ?? text)
  }

  /// Truncates to `max_length` the way Flutter's `LengthLimitingTextInputFormatter`
  /// does — by UTF-16 unit, which is what both platforms count in.
  func limited(_ text: String) -> String {
    guard let maxLength, text.utf16.count > maxLength else { return text }
    var cut = text.utf16.index(text.utf16.startIndex, offsetBy: maxLength)
    // A limit that lands inside a surrogate pair has no character index, so
    // step back rather than splitting the pair.
    while cut > text.utf16.startIndex, String.Index(cut, within: text) == nil {
      cut = text.utf16.index(before: cut)
    }
    guard let boundary = String.Index(cut, within: text) else { return text }
    return String(text[..<boundary])
  }
}

enum RufletTextSelection {
  static func normalized(_ range: NSRange, in text: String) -> NSRange? {
    guard range.location != NSNotFound, range.location >= 0, range.location <= text.utf16.count else {
      return nil
    }
    return NSRange(
      location: range.location,
      length: min(max(0, range.length), text.utf16.count - range.location))
  }

  static func wireValue(_ range: NSRange) -> RufletValue {
    .map([
      "base_offset": .int(Int64(range.location)),
      "extent_offset": .int(Int64(NSMaxRange(range))),
      "affinity": .string("downstream"),
      "directional": .bool(false),
    ])
  }

  static func eventData(_ range: NSRange, in text: String) -> RufletValue? {
    guard let resolved = normalized(range, in: text) else { return nil }
    return .map([
      "selected_text": .string((text as NSString).substring(with: resolved)),
      "selection": wireValue(resolved),
    ])
  }

  /// The selection Ruby set on the control, clamped to the current value.
  static func explicit(on node: ControlNode) -> NSRange {
    guard let map = node.map("selection"),
      let base = map["base_offset"]?.intValue,
      let extent = map["extent_offset"]?.intValue
    else { return NSRange(location: 0, length: 0) }
    let start = max(0, min(base, extent))
    let end = min((node.string("value") ?? "").utf16.count, max(base, extent))
    return NSRange(location: start, length: max(0, end - start))
  }

  /// Writes the selection back onto the control before reporting it, so Ruby
  /// reads the same range whether or not it declared a handler.
  static func report(
    _ range: NSRange, on node: ControlNode, to events: RufletEventSink
  ) {
    let source = node.string("value") ?? ""
    guard let resolved = normalized(range, in: source),
      let data = eventData(resolved, in: source)
    else { return }
    let value = wireValue(resolved)
    events.setLocal(node.id, "selection", value)
    events.update(node.id, ["selection": value])
    events.fire(node, "selection_change", data: data)
  }
}

#if canImport(UIKit)
  import UIKit

  /// A field that owns its caret.
  ///
  /// `caretRect(for:)` is the public hook for the caret's geometry, and it is
  /// enough for `cursor_width` and `cursor_height`. A rounded or non-blinking
  /// caret is not reachable that way, so when Ruby asks for either the system
  /// caret is tinted away and an identically placed layer is drawn instead —
  /// which is what Flutter's EditableText does on every platform.
  final class RufletTextFieldView: UITextField {
    var traits = RufletTextInputTraits() {
      didSet { applyCaretConfiguration() }
    }

    private let caret = CALayer()
    private var drawsOwnCaret = false

    override func caretRect(for position: UITextPosition) -> CGRect {
      var rect = super.caretRect(for: position)
      rect.size.width = traits.cursorWidth
      if let height = traits.cursorHeight {
        // Flutter keeps the caret centred on the line box when it is shorter
        // than the line.
        rect.origin.y += (rect.size.height - height) / 2
        rect.size.height = height
      }
      return rect
    }

    private func applyCaretConfiguration() {
      drawsOwnCaret = traits.needsCustomCaret
        && (traits.cursorRadius != nil || !traits.animateCursorOpacity)
      guard drawsOwnCaret else {
        caret.removeFromSuperlayer()
        return
      }
      if caret.superlayer == nil { layer.addSublayer(caret) }
      caret.cornerRadius = traits.cursorRadius ?? 0
      caret.backgroundColor = UIColor(
        traits.resolvedCursorColor ?? Color.accentColor).cgColor
      if traits.animateCursorOpacity {
        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = 1
        blink.toValue = 0
        blink.duration = 0.5
        blink.autoreverses = true
        blink.repeatCount = .infinity
        caret.add(blink, forKey: "blink")
      } else {
        caret.removeAnimation(forKey: "blink")
        caret.opacity = 1
      }
      positionCaret()
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      positionCaret()
    }

    func positionCaret() {
      guard drawsOwnCaret else { return }
      guard isFirstResponder, let range = selectedTextRange, range.isEmpty else {
        caret.isHidden = true
        return
      }
      caret.isHidden = false
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      caret.frame = caretRect(for: range.start)
      CATransaction.commit()
    }

    /// Tinting the system caret away leaves the selection handles tinted, so
    /// the colour is only cleared while this field draws its own.
    override var tintColor: UIColor! {
      didSet {
        if drawsOwnCaret, tintColor != .clear { tintColor = .clear }
      }
    }
  }

  struct RufletNativeTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    @Binding var selection: NSRange
    let placeholder: String
    let secure: Bool
    var traits = RufletTextInputTraits()
    let onTap: () -> Void
    let onTapOutside: () -> Void
    let onSubmit: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// UIKit's secure entry always draws a bullet, so a field asking for a
    /// different `obscuring_character` masks the text itself and keeps the
    /// real value in the coordinator.
    private var masksManually: Bool { secure && traits.obscuringCharacter != "•" }

    private func displayed(_ text: String) -> String {
      masksManually
        ? String(repeating: traits.obscuringCharacter, count: text.count) : text
    }

    func makeUIView(context: Context) -> RufletTextFieldView {
      let view = RufletTextFieldView(frame: .zero)
      view.delegate = context.coordinator
      view.placeholder = placeholder
      view.isSecureTextEntry = secure && !masksManually
      view.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
      view.addTarget(context.coordinator, action: #selector(Coordinator.began(_:)), for: .editingDidBegin)
      view.addTarget(context.coordinator, action: #selector(Coordinator.ended(_:)), for: .editingDidEnd)
      view.traits = traits
      apply(traits, to: view)
      return view
    }

    func updateUIView(_ view: RufletTextFieldView, context: Context) {
      context.coordinator.parent = self
      context.coordinator.plainText = text
      let shown = displayed(text)
      if view.text != shown { view.text = shown }
      view.placeholder = placeholder
      view.isSecureTextEntry = secure && !masksManually
      view.traits = traits
      apply(traits, to: view)
      if focused, !view.isFirstResponder {
        DispatchQueue.main.async { view.becomeFirstResponder() }
      } else if !focused, view.isFirstResponder {
        context.coordinator.programmaticBlur = true
        view.resignFirstResponder()
      }
      context.coordinator.apply(selection, to: view)
    }

    private func apply(_ traits: RufletTextInputTraits, to view: UITextField) {
      view.isEnabled = !traits.readOnly
      view.isUserInteractionEnabled = !traits.ignorePointers && traits.canRequestFocus
      switch traits.keyboardBrightness {
      case "light": view.keyboardAppearance = .light
      case "dark": view.keyboardAppearance = .dark
      default: view.keyboardAppearance = .default
      }
      view.autocorrectionType = traits.autocorrect ? .yes : .no
      view.spellCheckingType = traits.enableSuggestions ? .yes : .no
      view.smartDashesType = traits.smartDashes ? .yes : .no
      view.smartQuotesType = traits.smartQuotes ? .yes : .no
      view.keyboardType = Self.keyboardType(traits.keyboardType)
      view.autocapitalizationType = Self.capitalization(traits.capitalization)
      view.textAlignment = Self.alignment(traits.textAlign)
      if let hint = traits.autofillHint {
        view.textContentType = Self.contentType(hint)
      }
      // UITextField paints the caret and the selection handles with its tint,
      // so the caret colour wins and a selection colour is the fallback.
      if let cursor = traits.resolvedCursorColor {
        view.tintColor = UIColor(cursor)
      }
      // There is no switch for hiding the caret, but a clear tint hides it
      // without disabling selection, which is what show_cursor means.
      if !traits.showCursor { view.tintColor = .clear }
      if let color = traits.textColor { view.textColor = UIColor(color) }
      if let size = traits.fontSize { view.font = .systemFont(ofSize: size) }
      // Scribble is on by default; `enable_stylus_handwriting: false` turns it
      // off, which UIKit expresses by refusing the interaction.
      if #available(iOS 14.0, *) {
        let existing = view.interactions.compactMap { $0 as? UIScribbleInteraction }
        if traits.stylusHandwriting {
          existing.forEach(view.removeInteraction)
        } else if existing.isEmpty {
          view.addInteraction(UIScribbleInteraction(delegate: ScribbleBlocker.shared))
        }
      }
      applyStrut(traits, to: view)
    }

    /// Flutter's strut sets a floor under the line box. `height` is a multiple
    /// of the font size and `leading` adds to it, which is what a paragraph
    /// style's minimum line height expresses.
    private func applyStrut(_ traits: RufletTextInputTraits, to view: UITextField) {
      guard traits.strutHeight != nil || traits.strutLeading != nil else { return }
      let size = traits.fontSize ?? view.font?.pointSize ?? UIFont.systemFontSize
      let paragraph = NSMutableParagraphStyle()
      paragraph.minimumLineHeight = (traits.strutHeight ?? 1) * size
        + (traits.strutLeading ?? 0) * size
      view.defaultTextAttributes[.paragraphStyle] = paragraph
    }

    /// A delegate that refuses every Scribble session, so the interaction can
    /// stand in for the switch UIKit does not expose.
    private final class ScribbleBlocker: NSObject, UIScribbleInteractionDelegate {
      static let shared = ScribbleBlocker()
      func scribbleInteraction(
        _ interaction: UIScribbleInteraction, shouldBeginAt location: CGPoint
      ) -> Bool { false }
    }

    private static func keyboardType(_ value: String?) -> UIKeyboardType {
      switch value {
      case "number": return .numberPad
      case "phone": return .phonePad
      case "email": return .emailAddress
      case "url": return .URL
      case "datetime": return .numbersAndPunctuation
      case "name", "streetaddress": return .namePhonePad
      case "visiblepassword": return .asciiCapable
      case "websearch": return .webSearch
      case "twitter": return .twitter
      default: return .default
      }
    }

    private static func capitalization(_ value: String?) -> UITextAutocapitalizationType {
      switch value {
      case "characters": return .allCharacters
      case "words": return .words
      case "sentences": return .sentences
      case "none": return .none
      default: return .sentences
      }
    }

    private static func alignment(_ value: String?) -> NSTextAlignment {
      switch value {
      case "center": return .center
      case "right", "end": return .right
      case "justify": return .justified
      default: return .left
      }
    }

    private static func contentType(_ hint: String) -> UITextContentType? {
      switch hint.lowercased() {
      case "email": return .emailAddress
      case "name": return .name
      case "givenname": return .givenName
      case "familyname": return .familyName
      case "telephonenumber": return .telephoneNumber
      case "password": return .password
      case "newpassword": return .newPassword
      case "onetimecode": return .oneTimeCode
      case "username": return .username
      case "url": return .URL
      case "postalcode": return .postalCode
      case "streetaddressline1": return .streetAddressLine1
      case "countryname": return .countryName
      default: return nil
      }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
      var parent: RufletNativeTextInput
      var programmaticBlur = false
      /// The unmasked value, which the field itself never holds while a
      /// custom `obscuring_character` is in force.
      var plainText = ""
      private var lastSelection = NSRange(location: NSNotFound, length: 0)

      init(parent: RufletNativeTextInput) { self.parent = parent }

      @objc func changed(_ sender: UITextField) {
        guard !parent.masksManually else { return }
        let limited = parent.traits.formatted(sender.text ?? "")
        if sender.text != limited { sender.text = limited }
        parent.text = limited
      }

      /// `max_length` rejects the insertion rather than truncating after it, so
      /// the caret does not jump the way it would if the field were rewritten.
      func textField(
        _ textField: UITextField, shouldChangeCharactersIn range: NSRange,
        replacementString string: String
      ) -> Bool {
        if parent.masksManually {
          return maskedEdit(textField, range: range, replacement: string)
        }
        guard let maximum = parent.traits.maxLength else { return true }
        let current = (textField.text ?? "") as NSString
        return current.replacingCharacters(in: range, with: string).utf16.count <= maximum
      }

      @objc func began(_ sender: UITextField) {
        parent.focused = true
        parent.onTap()
        reportSelection(sender)
      }

      /// `always_call_on_tap` reports a tap on a field that already has focus,
      /// which `editingDidBegin` alone would miss.
      func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if parent.traits.alwaysCallOnTap, textField.isFirstResponder { parent.onTap() }
        return true
      }

      @objc func ended(_ sender: UITextField) {
        parent.focused = false
        if programmaticBlur {
          programmaticBlur = false
        } else {
          parent.onTapOutside()
        }
      }

      func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        parent.onSubmit(textField.text ?? "")
        return true
      }

      /// The masked field shows one obscuring character per real character, so
      /// an edit range in the display maps straight onto the plain text. The
      /// change is applied here and refused, leaving the field showing the
      /// mask and this coordinator holding the value.
      private func maskedEdit(
        _ textField: UITextField, range: NSRange, replacement: String
      ) -> Bool {
        let updated = parent.traits.formatted(
          (plainText as NSString).replacingCharacters(in: range, with: replacement))
        plainText = updated
        textField.text = String(
          repeating: parent.traits.obscuringCharacter, count: updated.count)
        let caret = min(range.location + replacement.count, updated.count)
        if let position = textField.position(from: textField.beginningOfDocument, offset: caret) {
          textField.selectedTextRange = textField.textRange(from: position, to: position)
        }
        parent.text = updated
        return false
      }

      func textFieldDidChangeSelection(_ textField: UITextField) {
        reportSelection(textField)
        (textField as? RufletTextFieldView)?.positionCaret()
      }

      private func reportSelection(_ textField: UITextField) {
        guard let selected = textField.selectedTextRange else { return }
        let start = textField.offset(from: textField.beginningOfDocument, to: selected.start)
        let end = textField.offset(from: textField.beginningOfDocument, to: selected.end)
        let range = NSRange(location: min(start, end), length: abs(end - start))
        guard range != lastSelection else { return }
        lastSelection = range
        parent.selection = range
      }

      func apply(_ range: NSRange, to field: UITextField) {
        guard range.location != NSNotFound, range != lastSelection,
          let start = field.position(from: field.beginningOfDocument, offset: range.location),
          let end = field.position(from: start, offset: range.length)
        else { return }
        field.selectedTextRange = field.textRange(from: start, to: end)
        lastSelection = range
      }
    }
  }

#elseif canImport(AppKit)
  import AppKit

  /// AppKit draws the caret from the field editor, which is shared per window,
  /// so a field that wants its own geometry supplies one. `fieldEditor(for:)`
  /// on the cell is the documented hook for that.
  final class RufletFieldEditor: NSTextView {
    var traits = RufletTextInputTraits()

    /// `ignore_up_down_keys` keeps the arrows from moving the caret so the
    /// surrounding application can use them, which is what Flet's shortcut
    /// wrapper does on desktop.
    override func doCommand(by selector: Selector) {
      if traits.ignoresUpDownKeys,
        selector == #selector(NSResponder.moveUp(_:))
          || selector == #selector(NSResponder.moveDown(_:))
      {
        return
      }
      super.doCommand(by: selector)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
      // `animate_cursor_opacity: false` means a caret that does not blink, so
      // the off phase is drawn as well as the on phase.
      guard flag || !traits.animateCursorOpacity else {
        super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
        return
      }
      var caret = rect
      caret.size.width = traits.cursorWidth
      if let height = traits.cursorHeight {
        caret.origin.y += (caret.height - height) / 2
        caret.size.height = height
      }
      let radius = traits.cursorRadius ?? 0
      (traits.resolvedCursorColor.map { NSColor($0) } ?? color).setFill()
      NSBezierPath(roundedRect: caret, xRadius: radius, yRadius: radius).fill()
    }
  }

  final class RufletTextFieldCell: NSTextFieldCell {
    var traits = RufletTextInputTraits()
    private lazy var editor = RufletFieldEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
      guard traits.needsCustomCaret else { return nil }
      editor.traits = traits
      editor.isFieldEditor = true
      return editor
    }
  }

  /// A secure cell keeps the same caret behaviour, so both variants exist.
  final class RufletSecureTextFieldCell: NSSecureTextFieldCell {
    var traits = RufletTextInputTraits()
    private lazy var editor = RufletFieldEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
      guard traits.needsCustomCaret else { return nil }
      editor.traits = traits
      editor.isFieldEditor = true
      return editor
    }
  }

  struct RufletNativeTextInput: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    @Binding var selection: NSRange
    let placeholder: String
    let secure: Bool
    var traits = RufletTextInputTraits()
    let onTap: () -> Void
    let onTapOutside: () -> Void
    let onSubmit: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSTextField {
      let field: NSTextField = secure ? NSSecureTextField() : NSTextField()
      if secure {
        let cell = RufletSecureTextFieldCell(textCell: "")
        cell.traits = traits
        cell.isEditable = true
        cell.isSelectable = true
        field.cell = cell
      } else {
        let cell = RufletTextFieldCell(textCell: "")
        cell.traits = traits
        cell.isEditable = true
        cell.isSelectable = true
        field.cell = cell
      }
      field.delegate = context.coordinator
      field.isBordered = false
      field.drawsBackground = false
      field.placeholderString = placeholder
      apply(traits, to: field)
      return field
    }

    func updateNSView(_ view: NSTextField, context: Context) {
      context.coordinator.parent = self
      if view.stringValue != text { view.stringValue = text }
      view.placeholderString = placeholder
      apply(traits, to: view)
      if focused, view.window?.firstResponder !== view.currentEditor() {
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
      } else if !focused, view.currentEditor() != nil {
        context.coordinator.programmaticBlur = true
        view.window?.makeFirstResponder(nil)
      }
      if let editor = view.currentEditor() as? NSTextView, editor.selectedRange() != selection {
        editor.setSelectedRange(selection)
      }
    }

    private func apply(_ traits: RufletTextInputTraits, to view: NSTextField) {
      view.isEditable = !traits.readOnly && traits.canRequestFocus
      view.refusesFirstResponder = !traits.canRequestFocus
      view.isSelectable = traits.enableInteractiveSelection || !traits.readOnly
      view.isAutomaticTextCompletionEnabled = traits.enableSuggestions
      view.alignment = Self.alignment(traits.textAlign)
      if let color = traits.textColor { view.textColor = NSColor(color) }
      if let size = traits.fontSize { view.font = .systemFont(ofSize: size) }
      // Flutter's strut sets a floor under the line box: `height` multiplies
      // the font size and `leading` adds to it.
      if traits.strutHeight != nil || traits.strutLeading != nil {
        let size = traits.fontSize ?? view.font?.pointSize ?? NSFont.systemFontSize
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = (traits.strutHeight ?? 1) * size
          + (traits.strutLeading ?? 0) * size
        view.attributedStringValue = NSAttributedString(
          string: view.stringValue, attributes: [.paragraphStyle: paragraph])
      }
      // AppKit paints the caret and selection from the field editor, which is
      // shared per window, so the colours are set when this field owns it.
      (view.cell as? RufletTextFieldCell)?.traits = traits
      (view.cell as? RufletSecureTextFieldCell)?.traits = traits
      if let editor = view.currentEditor() as? NSTextView {
        (editor as? RufletFieldEditor)?.traits = traits
        editor.insertionPointColor = traits.showCursor
          ? NSColor(traits.resolvedCursorColor ?? Color.accentColor) : .clear
        if let selection = traits.selectionColor {
          editor.selectedTextAttributes = [.backgroundColor: NSColor(selection)]
        }
      }
    }

    private static func alignment(_ value: String?) -> NSTextAlignment {
      switch value {
      case "center": return .center
      case "right", "end": return .right
      case "justify": return .justified
      default: return .left
      }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
      var parent: RufletNativeTextInput
      var programmaticBlur = false
      init(parent: RufletNativeTextInput) { self.parent = parent }

      func controlTextDidBeginEditing(_ notification: Notification) {
        parent.focused = true
        parent.onTap()
      }

      func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        let limited = parent.traits.formatted(field.stringValue)
        if field.stringValue != limited { field.stringValue = limited }
        parent.text = limited
        if let editor = field.currentEditor() as? NSTextView { parent.selection = editor.selectedRange() }
      }

      func controlTextDidEndEditing(_ notification: Notification) {
        parent.focused = false
        if programmaticBlur { programmaticBlur = false } else { parent.onTapOutside() }
      }

      func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        parent.onSubmit((control as? NSTextField)?.stringValue ?? "")
        return true
      }

      func textViewDidChangeSelection(_ notification: Notification) {
        guard let editor = notification.object as? NSTextView else { return }
        parent.selection = editor.selectedRange()
      }
    }
  }
#endif
