import SwiftUI
import RufletProtocol

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
      return view
    }

    func updateUIView(_ view: UITextField, context: Context) {
      context.coordinator.parent = self
      if view.text != text { view.text = text }
      view.placeholder = placeholder
      view.isSecureTextEntry = secure
      if focused, !view.isFirstResponder {
        DispatchQueue.main.async { view.becomeFirstResponder() }
      } else if !focused, view.isFirstResponder {
        context.coordinator.programmaticBlur = true
        view.resignFirstResponder()
      }
      context.coordinator.apply(selection, to: view)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
      var parent: RufletNativeTextInput
      var programmaticBlur = false
      private var lastSelection = NSRange(location: NSNotFound, length: 0)

      init(parent: RufletNativeTextInput) { self.parent = parent }

      @objc func changed(_ sender: UITextField) { parent.text = sender.text ?? "" }

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
      return field
    }

    func updateNSView(_ view: NSTextField, context: Context) {
      context.coordinator.parent = self
      if view.stringValue != text { view.stringValue = text }
      view.placeholderString = placeholder
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
        parent.text = field.stringValue
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
