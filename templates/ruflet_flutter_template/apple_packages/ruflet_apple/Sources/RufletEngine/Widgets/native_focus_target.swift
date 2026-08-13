import SwiftUI

#if os(iOS)
import UIKit

struct RufletNativeFocusTarget: UIViewRepresentable {
  let enabled: Bool
  let autofocus: Bool
  let request: Int
  let onFocusChange: (Bool) -> Void

  func makeUIView(context: Context) -> RufletFocusUIView { RufletFocusUIView() }

  func updateUIView(_ view: RufletFocusUIView, context: Context) {
    view.update(enabled: enabled, autofocus: autofocus, request: request, callback: onFocusChange)
  }
}

final class RufletFocusUIView: UIView {
  private var enabled = true
  private var didAutofocus = false
  private var request = 0
  private var callback: ((Bool) -> Void)?

  override var canBecomeFirstResponder: Bool { enabled }

  func update(enabled: Bool, autofocus: Bool, request: Int, callback: @escaping (Bool) -> Void) {
    self.enabled = enabled
    self.callback = callback
    if !enabled, isFirstResponder { _ = resignFirstResponder() }
    if autofocus, !didAutofocus {
      didAutofocus = true
      DispatchQueue.main.async { [weak self] in _ = self?.becomeFirstResponder() }
    }
    if self.request != request {
      self.request = request
      DispatchQueue.main.async { [weak self] in _ = self?.becomeFirstResponder() }
    }
  }

  override func becomeFirstResponder() -> Bool {
    let changed = super.becomeFirstResponder()
    if changed { callback?(true) }
    return changed
  }

  override func resignFirstResponder() -> Bool {
    let changed = super.resignFirstResponder()
    if changed { callback?(false) }
    return changed
  }
}
#elseif os(macOS)
import AppKit

struct RufletNativeFocusTarget: NSViewRepresentable {
  let enabled: Bool
  let autofocus: Bool
  let request: Int
  let onFocusChange: (Bool) -> Void

  func makeNSView(context: Context) -> RufletFocusNSView { RufletFocusNSView() }

  func updateNSView(_ view: RufletFocusNSView, context: Context) {
    view.update(enabled: enabled, autofocus: autofocus, request: request, callback: onFocusChange)
  }
}

final class RufletFocusNSView: NSView {
  private var enabled = true
  private var didAutofocus = false
  private var request = 0
  private var callback: ((Bool) -> Void)?

  override var acceptsFirstResponder: Bool { enabled }

  func update(enabled: Bool, autofocus: Bool, request: Int, callback: @escaping (Bool) -> Void) {
    self.enabled = enabled
    self.callback = callback
    if !enabled, window?.firstResponder === self { window?.makeFirstResponder(nil) }
    if autofocus, !didAutofocus {
      didAutofocus = true
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.window?.makeFirstResponder(self)
      }
    }
    if self.request != request {
      self.request = request
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.window?.makeFirstResponder(self)
      }
    }
  }

  override func becomeFirstResponder() -> Bool {
    let changed = super.becomeFirstResponder()
    if changed { callback?(true) }
    return changed
  }

  override func resignFirstResponder() -> Bool {
    let changed = super.resignFirstResponder()
    if changed { callback?(false) }
    return changed
  }
}
#endif
