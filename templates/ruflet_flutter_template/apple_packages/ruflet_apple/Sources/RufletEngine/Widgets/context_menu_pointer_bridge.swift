import SwiftUI

#if os(iOS)
  import UIKit

  struct RufletContextMenuPointerBridge: UIViewRepresentable {
    let primaryTrigger: RufletContextMenuTrigger
    let secondaryTrigger: RufletContextMenuTrigger
    let tertiaryTrigger: RufletContextMenuTrigger
    let onTrigger: (RufletContextMenuInvocation) -> Void

    func makeUIView(context: Context) -> RufletContextMenuUIView {
      RufletContextMenuUIView(frame: .zero)
    }

    func updateUIView(_ view: RufletContextMenuUIView, context: Context) {
      view.configure(
        primaryTrigger: primaryTrigger,
        secondaryTrigger: secondaryTrigger,
        tertiaryTrigger: tertiaryTrigger,
        onTrigger: onTrigger)
    }

    static func dismantleUIView(_ view: RufletContextMenuUIView, coordinator: ()) {
      view.uninstall()
    }
  }

  final class RufletContextMenuUIView: UIView {
    private weak var gestureHost: UIView?
    private var recognizers: [UIGestureRecognizer] = []
    private var primaryTrigger = RufletContextMenuTrigger.disabled
    private var secondaryTrigger = RufletContextMenuTrigger.down
    private var tertiaryTrigger = RufletContextMenuTrigger.down
    private var onTrigger: ((RufletContextMenuInvocation) -> Void)?

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToSuperview() {
      super.didMoveToSuperview()
      installIfNeeded()
    }

    func configure(
      primaryTrigger: RufletContextMenuTrigger,
      secondaryTrigger: RufletContextMenuTrigger,
      tertiaryTrigger: RufletContextMenuTrigger,
      onTrigger: @escaping (RufletContextMenuInvocation) -> Void
    ) {
      let changed =
        self.primaryTrigger != primaryTrigger
        || self.secondaryTrigger != secondaryTrigger
        || self.tertiaryTrigger != tertiaryTrigger
      self.primaryTrigger = primaryTrigger
      self.secondaryTrigger = secondaryTrigger
      self.tertiaryTrigger = tertiaryTrigger
      self.onTrigger = onTrigger
      if changed { uninstall() }
      installIfNeeded()
    }

    func uninstall() {
      for recognizer in recognizers { gestureHost?.removeGestureRecognizer(recognizer) }
      recognizers.removeAll()
      gestureHost = nil
    }

    private func installIfNeeded() {
      guard let superview, gestureHost !== superview else { return }
      uninstall()
      gestureHost = superview
      addRecognizer(
        to: superview, trigger: primaryTrigger, button: .primary,
        pointerOnly: primaryTrigger == .down)
      addRecognizer(to: superview, trigger: secondaryTrigger, button: .secondary, pointerOnly: true)
      addRecognizer(to: superview, trigger: tertiaryTrigger, button: .tertiary, pointerOnly: true)
    }

    private func addRecognizer(
      to host: UIView,
      trigger: RufletContextMenuTrigger,
      button: RufletContextMenuButton,
      pointerOnly: Bool
    ) {
      guard trigger != .disabled else { return }
      let recognizer: UIGestureRecognizer
      if pointerOnly {
        recognizer = RufletContextMenuPointerRecognizer(
          button: button,
          requiredMask: .button(buttonIndex(button)),
          delay: trigger == .down ? 0 : 0.5,
          target: self,
          action: #selector(longPressed(_:)))
      } else {
        let directLongPress = RufletContextMenuLongPressRecognizer(
          target: self, action: #selector(longPressed(_:)))
        directLongPress.rufletButton = button
        directLongPress.minimumPressDuration = 0.5
        directLongPress.cancelsTouchesInView = false
        recognizer = directLongPress
      }
      host.addGestureRecognizer(recognizer)
      recognizers.append(recognizer)
    }

    @objc private func longPressed(_ recognizer: UIGestureRecognizer) {
      guard recognizer.state == .began,
        let button = (recognizer as? RufletContextMenuLongPressRecognizer)?.rufletButton
          ?? (recognizer as? RufletContextMenuPointerRecognizer)?.rufletButton,
        let window, let onTrigger
      else { return }
      let local = recognizer.location(in: self)
      guard bounds.contains(local) else { return }
      let global = convert(local, to: window)
      onTrigger(
        RufletContextMenuInvocation(
          button: button, globalPosition: global, localPosition: local))
    }

    private func buttonIndex(_ button: RufletContextMenuButton) -> Int {
      switch button {
      case .primary: return 0
      case .secondary: return 1
      case .tertiary: return 2
      }
    }
  }

  private final class RufletContextMenuLongPressRecognizer: UILongPressGestureRecognizer {
    var rufletButton: RufletContextMenuButton?
  }

  private final class RufletContextMenuPointerRecognizer: UIGestureRecognizer,
    UIGestureRecognizerDelegate
  {
    let rufletButton: RufletContextMenuButton
    private let requiredMask: UIEvent.ButtonMask
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private var startPoint: CGPoint?

    init(
      button: RufletContextMenuButton,
      requiredMask: UIEvent.ButtonMask,
      delay: TimeInterval,
      target: Any?,
      action: Selector?
    ) {
      rufletButton = button
      self.requiredMask = requiredMask
      self.delay = delay
      super.init(target: target, action: action)
      delegate = self
      cancelsTouchesInView = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
      guard buttonMask.contains(requiredMask) else {
        state = .failed
        return
      }
      startPoint = touches.first.flatMap { touch in view.map { touch.location(in: $0) } }
      if delay == 0 {
        state = .began
      } else {
        let work = DispatchWorkItem { [weak self] in
          guard let self, self.state == .possible else { return }
          self.state = .began
        }
        workItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
      }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
      guard state == .possible, let touch = touches.first, let view, let startPoint else { return }
      let current = touch.location(in: view)
      if hypot(current.x - startPoint.x, current.y - startPoint.y) > 10 { state = .failed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
      state = state == .began ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
      state = .cancelled
    }

    override func reset() {
      workItem?.cancel()
      workItem = nil
      startPoint = nil
      super.reset()
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }
  }

#elseif os(macOS)
  import AppKit

  struct RufletContextMenuPointerBridge: NSViewRepresentable {
    let primaryTrigger: RufletContextMenuTrigger
    let secondaryTrigger: RufletContextMenuTrigger
    let tertiaryTrigger: RufletContextMenuTrigger
    let onTrigger: (RufletContextMenuInvocation) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> RufletContextMenuNSView {
      let view = RufletContextMenuNSView(frame: .zero)
      view.coordinator = context.coordinator
      context.coordinator.view = view
      return view
    }

    func updateNSView(_ view: RufletContextMenuNSView, context: Context) {
      context.coordinator.configure(
        primaryTrigger: primaryTrigger,
        secondaryTrigger: secondaryTrigger,
        tertiaryTrigger: tertiaryTrigger,
        onTrigger: onTrigger)
    }

    static func dismantleNSView(_ view: RufletContextMenuNSView, coordinator: Coordinator) {
      coordinator.remove()
    }

    final class Coordinator {
      weak var view: RufletContextMenuNSView?
      private var monitor: Any?
      private var primaryTrigger = RufletContextMenuTrigger.disabled
      private var secondaryTrigger = RufletContextMenuTrigger.down
      private var tertiaryTrigger = RufletContextMenuTrigger.down
      private var onTrigger: ((RufletContextMenuInvocation) -> Void)?
      private var pendingLongPress: [RufletContextMenuButton: DispatchWorkItem] = [:]

      func configure(
        primaryTrigger: RufletContextMenuTrigger,
        secondaryTrigger: RufletContextMenuTrigger,
        tertiaryTrigger: RufletContextMenuTrigger,
        onTrigger: @escaping (RufletContextMenuInvocation) -> Void
      ) {
        self.primaryTrigger = primaryTrigger
        self.secondaryTrigger = secondaryTrigger
        self.tertiaryTrigger = tertiaryTrigger
        self.onTrigger = onTrigger
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
          matching: [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseUp, .rightMouseUp, .otherMouseUp,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
          ]) { [weak self] event in
            self?.handle(event)
            return event
          }
      }

      func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        for workItem in pendingLongPress.values { workItem.cancel() }
        pendingLongPress.removeAll()
      }

      private func handle(_ event: NSEvent) {
        guard let button = button(for: event) else { return }
        if isReleaseOrDrag(event) {
          pendingLongPress.removeValue(forKey: button)?.cancel()
          return
        }
        guard let invocation = invocation(for: event, button: button) else { return }
        switch trigger(for: button) {
        case .disabled:
          break
        case .down:
          onTrigger?(invocation)
        case .longPress:
          let work = DispatchWorkItem { [weak self] in self?.onTrigger?(invocation) }
          pendingLongPress[button]?.cancel()
          pendingLongPress[button] = work
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
      }

      private func invocation(
        for event: NSEvent, button: RufletContextMenuButton
      ) -> RufletContextMenuInvocation? {
        guard let view, event.window === view.window else { return nil }
        let local = view.convert(event.locationInWindow, from: nil)
        guard view.bounds.contains(local) else { return nil }
        let windowPoint = view.convert(local, to: nil)
        let contentHeight = view.window?.contentView?.bounds.height ?? view.bounds.height
        let global = CGPoint(x: windowPoint.x, y: contentHeight - windowPoint.y)
        return RufletContextMenuInvocation(
          button: button, globalPosition: global, localPosition: local)
      }

      private func button(for event: NSEvent) -> RufletContextMenuButton? {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged: return .primary
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged: return .secondary
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
          return event.buttonNumber == 2 ? .tertiary : nil
        default: return nil
        }
      }

      private func trigger(for button: RufletContextMenuButton) -> RufletContextMenuTrigger {
        switch button {
        case .primary: return primaryTrigger
        case .secondary: return secondaryTrigger
        case .tertiary: return tertiaryTrigger
        }
      }

      private func isReleaseOrDrag(_ event: NSEvent) -> Bool {
        switch event.type {
        case .leftMouseUp, .rightMouseUp, .otherMouseUp,
          .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
          return true
        default:
          return false
        }
      }
    }
  }

  final class RufletContextMenuNSView: NSView {
    weak var coordinator: RufletContextMenuPointerBridge.Coordinator?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
  }
#endif
