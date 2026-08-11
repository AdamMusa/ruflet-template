import SwiftUI

#if canImport(AppKit)
  import AppKit

  struct RufletNativeKeyboardListener: NSViewRepresentable {
    @Binding var focused: Bool
    let includeSemantics: Bool
    let onKeyDown: (String) -> Void
    let onKeyRepeat: (String) -> Void
    let onKeyUp: (String) -> Void

    func makeNSView(context: Context) -> KeyboardView {
      let view = KeyboardView()
      configure(view)
      return view
    }

    func updateNSView(_ view: KeyboardView, context: Context) {
      configure(view)
      if focused, view.window?.firstResponder !== view {
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
      }
    }

    private func configure(_ view: KeyboardView) {
      view.onKeyDown = onKeyDown
      view.onKeyRepeat = onKeyRepeat
      view.onKeyUp = onKeyUp
      view.setAccessibilityElement(includeSemantics)
    }

    final class KeyboardView: NSView {
      var onKeyDown: (String) -> Void = { _ in }
      var onKeyRepeat: (String) -> Void = { _ in }
      var onKeyUp: (String) -> Void = { _ in }
      override var acceptsFirstResponder: Bool { true }

      override func keyDown(with event: NSEvent) {
        let label = event.charactersIgnoringModifiers ?? event.characters ?? ""
        event.isARepeat ? onKeyRepeat(label) : onKeyDown(label)
      }

      override func keyUp(with event: NSEvent) {
        onKeyUp(event.charactersIgnoringModifiers ?? event.characters ?? "")
      }
    }
  }

#elseif canImport(UIKit)
  import UIKit

  struct RufletNativeKeyboardListener: UIViewRepresentable {
    @Binding var focused: Bool
    let includeSemantics: Bool
    let onKeyDown: (String) -> Void
    let onKeyRepeat: (String) -> Void
    let onKeyUp: (String) -> Void

    func makeUIView(context: Context) -> KeyboardView {
      let view = KeyboardView()
      configure(view)
      return view
    }

    func updateUIView(_ view: KeyboardView, context: Context) {
      configure(view)
      if focused, !view.isFirstResponder {
        DispatchQueue.main.async { view.becomeFirstResponder() }
      }
    }

    private func configure(_ view: KeyboardView) {
      view.onKeyDown = onKeyDown
      view.onKeyRepeat = onKeyRepeat
      view.onKeyUp = onKeyUp
      view.isAccessibilityElement = includeSemantics
    }

    final class KeyboardView: UIView {
      var onKeyDown: (String) -> Void = { _ in }
      var onKeyRepeat: (String) -> Void = { _ in }
      var onKeyUp: (String) -> Void = { _ in }
      private var pressed = Set<String>()
      override var canBecomeFirstResponder: Bool { true }

      override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
          let label = Self.label(for: press)
          if pressed.contains(label) { onKeyRepeat(label) } else {
            pressed.insert(label)
            onKeyDown(label)
          }
        }
      }

      override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
          let label = Self.label(for: press)
          pressed.remove(label)
          onKeyUp(label)
        }
      }

      override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
      }

      private static func label(for press: UIPress) -> String {
        press.key?.charactersIgnoringModifiers ?? press.key?.characters ?? ""
      }
    }
  }
#endif
