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
}

#if canImport(UIKit)
  import UIKit

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

    func makeUIView(context: Context) -> UITextField {
      let view = UITextField(frame: .zero)
      view.delegate = context.coordinator
      view.placeholder = placeholder
      view.isSecureTextEntry = secure
      view.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
      view.addTarget(context.coordinator, action: #selector(Coordinator.began(_:)), for: .editingDidBegin)
      view.addTarget(context.coordinator, action: #selector(Coordinator.ended(_:)), for: .editingDidEnd)
      apply(traits, to: view)
      return view
    }

    func updateUIView(_ view: UITextField, context: Context) {
      context.coordinator.parent = self
      if view.text != text { view.text = text }
      view.placeholder = placeholder
      view.isSecureTextEntry = secure
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
      // so a cursor colour wins and a selection colour is the fallback.
      if let cursor = traits.cursorColor ?? traits.selectionColor {
        view.tintColor = UIColor(cursor)
      }
      // There is no switch for hiding the caret, but a clear tint hides it
      // without disabling selection, which is what show_cursor means.
      if !traits.showCursor { view.tintColor = .clear }
      if let color = traits.textColor { view.textColor = UIColor(color) }
      if let size = traits.fontSize { view.font = .systemFont(ofSize: size) }
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
      private var lastSelection = NSRange(location: NSNotFound, length: 0)

      init(parent: RufletNativeTextInput) { self.parent = parent }

      @objc func changed(_ sender: UITextField) {
        let limited = parent.traits.limited(sender.text ?? "")
        if sender.text != limited { sender.text = limited }
        parent.text = limited
      }

      /// `max_length` rejects the insertion rather than truncating after it, so
      /// the caret does not jump the way it would if the field were rewritten.
      func textField(
        _ textField: UITextField, shouldChangeCharactersIn range: NSRange,
        replacementString string: String
      ) -> Bool {
        guard let maximum = parent.traits.maxLength else { return true }
        let current = (textField.text ?? "") as NSString
        return current.replacingCharacters(in: range, with: string).utf16.count <= maximum
      }

      @objc func began(_ sender: UITextField) {
        parent.focused = true
        parent.onTap()
        reportSelection(sender)
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

      func textFieldDidChangeSelection(_ textField: UITextField) { reportSelection(textField) }

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
      view.isEditable = !traits.readOnly
      view.isSelectable = traits.enableInteractiveSelection || !traits.readOnly
      view.isAutomaticTextCompletionEnabled = traits.enableSuggestions
      view.alignment = Self.alignment(traits.textAlign)
      if let color = traits.textColor { view.textColor = NSColor(color) }
      if let size = traits.fontSize { view.font = .systemFont(ofSize: size) }
      // AppKit paints the caret and selection from the field editor, which is
      // shared per window, so the colours are set when this field owns it.
      if let editor = view.currentEditor() as? NSTextView {
        editor.insertionPointColor = traits.showCursor
          ? NSColor(traits.cursorColor ?? Color.accentColor) : .clear
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
        let limited = parent.traits.limited(field.stringValue)
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
