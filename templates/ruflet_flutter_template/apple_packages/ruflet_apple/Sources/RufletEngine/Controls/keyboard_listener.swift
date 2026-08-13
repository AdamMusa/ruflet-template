import RufletProtocol
import SwiftUI

@MainActor
public struct KeyboardListenerControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator = RufletKeyboardListenerCoordinator()

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    if let content = control.buildWidget("content") {
      content
        .background {
          RufletKeyboardListenerHost(
            enabled: coordinator.focused,
            includeSemantics: control.boolean("include_semantics", default: true),
            onKey: dispatch)
          .frame(width: 0, height: 0)
        }
        .onAppear {
          coordinator.attach(to: control)
          if control.boolean("autofocus", default: false) { coordinator.focused = true }
        }
        .onDisappear { coordinator.detach(from: control) }
    } else {
      ErrorControl("KeyboardListener control has no content.")
    }
  }

  private func dispatch(_ phase: RufletKeyPhase, key: String) {
    let event: String
    switch phase {
    case .down: event = "key_down"
    case .up: event = "key_up"
    case .repeat: event = "key_repeat"
    }
    control.triggerEvent(event, data: ["key": .string(key)])
  }
}

enum RufletKeyPhase { case down, up, `repeat` }

@MainActor
private final class RufletKeyboardListenerCoordinator: ObservableObject {
  @Published var focused = false
  private var token: UUID?

  func attach(to control: RufletControl) {
    guard token == nil else { return }
    token = control.addInvokeMethodListener { [weak self] name, _ in
      guard name == "focus" else { throw RufletControlError.noMethodListener }
      self?.focused = true
      return .null
    }
  }

  func detach(from control: RufletControl) {
    guard let token else { return }
    control.removeInvokeMethodListener(token)
    self.token = nil
  }
}

#if os(iOS)
import UIKit

private struct RufletKeyboardListenerHost: UIViewControllerRepresentable {
  let enabled: Bool
  let includeSemantics: Bool
  let onKey: (RufletKeyPhase, String) -> Void

  func makeUIViewController(context: Context) -> RufletKeyboardListenerViewController {
    RufletKeyboardListenerViewController()
  }

  func updateUIViewController(_ controller: RufletKeyboardListenerViewController, context: Context) {
    controller.enabled = enabled
    controller.onKey = onKey
    controller.view.isAccessibilityElement = includeSemantics
    if enabled { controller.becomeFirstResponder() }
  }
}

private final class RufletKeyboardListenerViewController: UIViewController {
  var enabled = false
  var onKey: ((RufletKeyPhase, String) -> Void)?
  private var pressedKeys: Set<String> = []
  override var canBecomeFirstResponder: Bool { enabled }

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    var handled = false
    for press in presses {
      guard let key = press.key?.charactersIgnoringModifiers, !key.isEmpty else { continue }
      let repeated = pressedKeys.contains(key)
      pressedKeys.insert(key)
      onKey?(repeated ? .repeat : .down, key)
      handled = true
    }
    if !handled { super.pressesBegan(presses, with: event) }
  }

  override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    var handled = false
    for press in presses {
      guard let key = press.key?.charactersIgnoringModifiers, !key.isEmpty else { continue }
      pressedKeys.remove(key)
      onKey?(.up, key)
      handled = true
    }
    if !handled { super.pressesEnded(presses, with: event) }
  }

  override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    for press in presses {
      guard let key = press.key?.charactersIgnoringModifiers else { continue }
      pressedKeys.remove(key)
      onKey?(.up, key)
    }
    super.pressesCancelled(presses, with: event)
  }
}
#elseif os(macOS)
import AppKit

private struct RufletKeyboardListenerHost: NSViewRepresentable {
  let enabled: Bool
  let includeSemantics: Bool
  let onKey: (RufletKeyPhase, String) -> Void

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

  func updateNSView(_ view: NSView, context: Context) {
    view.setAccessibilityElement(includeSemantics)
    context.coordinator.install(enabled: enabled, onKey: onKey)
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.remove() }

  final class Coordinator {
    private var downMonitor: Any?
    private var upMonitor: Any?

    func install(enabled: Bool, onKey: @escaping (RufletKeyPhase, String) -> Void) {
      remove()
      guard enabled else { return }
      downMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        onKey(event.isARepeat ? .repeat : .down, event.charactersIgnoringModifiers ?? "")
        return event
      }
      upMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
        onKey(.up, event.charactersIgnoringModifiers ?? "")
        return event
      }
    }

    func remove() {
      if let downMonitor { NSEvent.removeMonitor(downMonitor) }
      if let upMonitor { NSEvent.removeMonitor(upMonitor) }
      downMonitor = nil
      upMonitor = nil
    }
  }
}
#endif
