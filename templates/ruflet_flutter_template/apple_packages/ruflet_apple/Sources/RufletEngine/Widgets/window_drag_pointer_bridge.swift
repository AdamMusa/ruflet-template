import SwiftUI

func rufletWindowToggleAction(wasMaximized: Bool) -> String {
  wasMaximized ? "unmaximize" : "maximize"
}

#if os(macOS)
  import AppKit

  struct RufletWindowDragPointerBridge: NSViewRepresentable {
    let maximizable: Bool
    let onDragStart: (CGPoint, CGPoint) -> Void
    let onDragEnd: (CGPoint, CGPoint, CGVector) -> Void
    let onDoubleTap: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> RufletWindowDragNSView {
      let view = RufletWindowDragNSView(frame: .zero)
      context.coordinator.view = view
      return view
    }

    func updateNSView(_ view: RufletWindowDragNSView, context: Context) {
      context.coordinator.configure(
        maximizable: maximizable,
        onDragStart: onDragStart,
        onDragEnd: onDragEnd,
        onDoubleTap: onDoubleTap)
    }

    static func dismantleNSView(_ view: RufletWindowDragNSView, coordinator: Coordinator) {
      coordinator.remove()
    }

    final class Coordinator {
      weak var view: RufletWindowDragNSView?
      private var monitor: Any?
      private var pendingMouseDown: NSEvent?
      private var lastTapUpTime: TimeInterval?
      private var lastTapUpPosition: CGPoint?
      private var maximizable = true
      private var onDragStart: ((CGPoint, CGPoint) -> Void)?
      private var onDragEnd: ((CGPoint, CGPoint, CGVector) -> Void)?
      private var onDoubleTap: ((String) -> Void)?

      func configure(
        maximizable: Bool,
        onDragStart: @escaping (CGPoint, CGPoint) -> Void,
        onDragEnd: @escaping (CGPoint, CGPoint, CGVector) -> Void,
        onDoubleTap: @escaping (String) -> Void
      ) {
        self.maximizable = maximizable
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
        self.onDoubleTap = onDoubleTap
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
          matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
          self?.handle(event) ?? event
        }
      }

      func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        resetTapState()
        pendingMouseDown = nil
      }

      private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown:
          return mouseDown(event)
        case .leftMouseDragged:
          return mouseDragged(event)
        case .leftMouseUp:
          return mouseUp(event)
        default:
          return event
        }
      }

      private func mouseDown(_ event: NSEvent) -> NSEvent? {
        guard contains(event), let point = points(for: event) else { return event }
        if maximizable, let lastTapUpTime, let lastTapUpPosition,
          ProcessInfo.processInfo.systemUptime - lastTapUpTime <= NSEvent.doubleClickInterval,
          hypot(point.global.x - lastTapUpPosition.x, point.global.y - lastTapUpPosition.y) <= 18
        {
          resetTapState()
          pendingMouseDown = nil
          if let window = view?.window {
            let wasMaximized = window.isZoomed
            window.zoom(nil)
            onDoubleTap?(rufletWindowToggleAction(wasMaximized: wasMaximized))
          }
          return event
        }
        pendingMouseDown = event
        return event
      }

      private func mouseDragged(_ event: NSEvent) -> NSEvent? {
        guard let mouseDown = pendingMouseDown,
          let start = points(for: mouseDown),
          let window = view?.window
        else { return event }
        pendingMouseDown = nil
        resetTapState()
        let startedAt = ProcessInfo.processInfo.systemUptime
        onDragStart?(start.local, start.global)
        window.performDrag(with: mouseDown)
        let end = currentPoints(in: window)
        let elapsed = max(ProcessInfo.processInfo.systemUptime - startedAt, 0.001)
        let velocity = CGVector(
          dx: (end.global.x - start.global.x) / elapsed,
          dy: (end.global.y - start.global.y) / elapsed)
        onDragEnd?(end.local, end.global, velocity)
        return nil
      }

      private func mouseUp(_ event: NSEvent) -> NSEvent? {
        guard pendingMouseDown != nil, let point = points(for: event) else { return event }
        pendingMouseDown = nil
        if maximizable {
          lastTapUpTime = ProcessInfo.processInfo.systemUptime
          lastTapUpPosition = point.global
        }
        return event
      }

      private func contains(_ event: NSEvent) -> Bool {
        guard let view, event.window === view.window else { return false }
        return view.bounds.contains(view.convert(event.locationInWindow, from: nil))
      }

      private func points(for event: NSEvent) -> (local: CGPoint, global: CGPoint)? {
        guard let view, event.window === view.window else { return nil }
        let local = view.convert(event.locationInWindow, from: nil)
        guard view.bounds.contains(local) else { return nil }
        let contentHeight = view.window?.contentView?.bounds.height ?? view.bounds.height
        return (
          local, CGPoint(x: event.locationInWindow.x, y: contentHeight - event.locationInWindow.y)
        )
      }

      private func currentPoints(in window: NSWindow) -> (local: CGPoint, global: CGPoint) {
        guard let view else { return (.zero, .zero) }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let local = view.convert(windowPoint, from: nil)
        let contentHeight = window.contentView?.bounds.height ?? view.bounds.height
        return (local, CGPoint(x: windowPoint.x, y: contentHeight - windowPoint.y))
      }

      private func resetTapState() {
        lastTapUpTime = nil
        lastTapUpPosition = nil
      }
    }
  }

  final class RufletWindowDragNSView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
  }
#endif
