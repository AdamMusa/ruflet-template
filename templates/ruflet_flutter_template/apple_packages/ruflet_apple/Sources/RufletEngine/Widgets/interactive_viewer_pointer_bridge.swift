import SwiftUI

enum RufletInteractivePointerPhase: Equatable {
  case began
  case changed
  case ended
  case cancelled
}

#if os(iOS)
  import UIKit

  struct RufletInteractivePointerBridge: UIViewRepresentable {
    let onScroll: (RufletInteractivePointerPhase, CGSize, CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> RufletInteractivePointerInstallerView {
      let view = RufletInteractivePointerInstallerView()
      view.onScroll = onScroll
      return view
    }

    func updateUIView(_ view: RufletInteractivePointerInstallerView, context: Context) {
      view.onScroll = onScroll
      view.installIfNeeded()
    }

    static func dismantleUIView(_ view: RufletInteractivePointerInstallerView, coordinator: ()) {
      view.uninstall()
    }
  }

  final class RufletInteractivePointerInstallerView: UIView, UIGestureRecognizerDelegate {
    var onScroll: ((RufletInteractivePointerPhase, CGSize, CGPoint, CGPoint) -> Void)?
    private weak var installedView: UIView?
    private var recognizer: UIPanGestureRecognizer?
    private var previousTranslation = CGPoint.zero

    override func didMoveToSuperview() {
      super.didMoveToSuperview()
      DispatchQueue.main.async { [weak self] in self?.installIfNeeded() }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

    func installIfNeeded() {
      guard recognizer == nil, let target = superview else { return }
      let recognizer = UIPanGestureRecognizer(target: self, action: #selector(scrolled(_:)))
      recognizer.allowedScrollTypesMask = .continuous
      recognizer.cancelsTouchesInView = false
      recognizer.delaysTouchesBegan = false
      recognizer.delaysTouchesEnded = false
      recognizer.delegate = self
      target.addGestureRecognizer(recognizer)
      installedView = target
      self.recognizer = recognizer
    }

    func uninstall() {
      if let recognizer { installedView?.removeGestureRecognizer(recognizer) }
      recognizer = nil
      installedView = nil
      previousTranslation = .zero
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    @objc private func scrolled(_ recognizer: UIPanGestureRecognizer) {
      guard let target = installedView else { return }
      let translation = recognizer.translation(in: target)
      let delta = CGSize(
        width: translation.x - previousTranslation.x,
        height: translation.y - previousTranslation.y)
      let local = recognizer.location(in: target)
      let global = target.convert(local, to: nil)
      let phase: RufletInteractivePointerPhase
      switch recognizer.state {
      case .began: phase = .began
      case .ended: phase = .ended
      case .cancelled, .failed: phase = .cancelled
      default: phase = .changed
      }
      onScroll?(phase, delta, local, global)
      previousTranslation = translation
      if phase == .ended || phase == .cancelled { previousTranslation = .zero }
    }
  }

#elseif os(macOS)
  import AppKit

  struct RufletInteractivePointerBridge: NSViewRepresentable {
    let onScroll: (RufletInteractivePointerPhase, CGSize, CGPoint, CGPoint) -> Void

    func makeNSView(context: Context) -> RufletInteractivePointerMonitorView {
      let view = RufletInteractivePointerMonitorView()
      view.onScroll = onScroll
      return view
    }

    func updateNSView(_ view: RufletInteractivePointerMonitorView, context: Context) {
      view.onScroll = onScroll
      view.installIfNeeded()
    }

    static func dismantleNSView(_ view: RufletInteractivePointerMonitorView, coordinator: ()) {
      view.uninstall()
    }
  }

  final class RufletInteractivePointerMonitorView: NSView {
    var onScroll: ((RufletInteractivePointerPhase, CGSize, CGPoint, CGPoint) -> Void)?
    private var monitor: Any?
    private var scrolling = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window == nil { uninstall() } else { installIfNeeded() }
    }

    func installIfNeeded() {
      guard monitor == nil, window != nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
        self?.handle(event)
        return event
      }
    }

    func uninstall() {
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
      scrolling = false
    }

    private func handle(_ event: NSEvent) {
      guard event.window === window else { return }
      let local = convert(event.locationInWindow, from: nil)
      guard bounds.contains(local) else { return }
      let delta = CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY)
      let global = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow

      if event.phase.isEmpty, event.momentumPhase.isEmpty {
        onScroll?(.began, .zero, local, global)
        onScroll?(.changed, delta, local, global)
        onScroll?(.ended, .zero, local, global)
        return
      }

      let phase: RufletInteractivePointerPhase
      if event.phase == .cancelled {
        phase = .cancelled
      } else if event.phase == .ended {
        phase = .ended
      } else if event.phase == .began || !scrolling {
        phase = .began
      } else {
        phase = .changed
      }
      scrolling = phase != .ended && phase != .cancelled
      onScroll?(phase, delta, local, global)
    }
  }
#endif
