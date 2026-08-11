#if os(macOS)
  import AppKit
  import RufletProtocol
  import SwiftUI

  /// A non-hit-testing AppKit observer for pointer channels SwiftUI does not
  /// expose (secondary/tertiary buttons, wheel deltas, pressure and right-pan).
  /// Returning nil from hitTest keeps the wrapped Ruflet content interactive.
  struct RufletNativePointerMonitor: NSViewRepresentable {
    let onEvent: (String, RufletValue) -> Void

    func makeNSView(context: Context) -> MonitorView {
      let view = MonitorView()
      view.onEvent = onEvent
      return view
    }

    func updateNSView(_ view: MonitorView, context: Context) { view.onEvent = onEvent }

    final class MonitorView: NSView {
      var onEvent: (String, RufletValue) -> Void = { _, _ in }
      private var monitor: Any?
      private var secondaryStart: CGPoint?
      private var tertiaryStart: CGPoint?
      private var secondaryLongPress: Timer?
      private var tertiaryLongPress: Timer?
      override var isFlipped: Bool { true }
      override func hitTest(_ point: NSPoint) -> NSView? { nil }

      override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [
          .rightMouseDown, .rightMouseDragged, .rightMouseUp,
          .otherMouseDown, .otherMouseDragged, .otherMouseUp,
          .scrollWheel, .pressure,
        ]) { [weak self] event in
          self?.handle(event)
          return event
        }
      }

      deinit { removeMonitor() }

      private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
      }

      private func handle(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        let local = convert(event.locationInWindow, from: nil)
        guard bounds.contains(local) else { return }
        let global = window.convertPoint(toScreen: event.locationInWindow)
        let tap = RufletInteractionParity.tap(kind: "mouse", local: local, global: global)

        switch event.type {
        case .rightMouseDown:
          secondaryStart = local
          onEvent("secondary_tap_down", tap)
          onEvent("secondary_long_press_down", tap)
          onEvent("right_pan_start", pointer(event, local: local, global: global))
          secondaryLongPress = longPressTimer(for: .secondary, tap: tap)
        case .rightMouseDragged:
          secondaryLongPress?.invalidate()
          let start = secondaryStart ?? local
          let update = longPressMove(event, local: local, global: global, start: start)
          onEvent("secondary_long_press_move_update", update)
          onEvent("right_pan_update", pointer(event, local: local, global: global, start: start))
        case .rightMouseUp:
          let long = secondaryLongPress == nil
          secondaryLongPress?.invalidate()
          secondaryLongPress = nil
          onEvent("secondary_tap_up", tap)
          onEvent("right_pan_end", pointer(event, local: local, global: global))
          if long {
            onEvent("secondary_long_press_up", .null)
            onEvent("secondary_long_press_end", longPressEnd(local: local, global: global))
          } else if let start = secondaryStart,
            hypot(local.x - start.x, local.y - start.y) <= 18
          {
            onEvent("secondary_tap", .null)
            onEvent("secondary_long_press_cancel", .null)
          } else {
            onEvent("secondary_tap_cancel", .null)
            onEvent("secondary_long_press_cancel", .null)
          }
          secondaryStart = nil
        case .otherMouseDown where event.buttonNumber == 2:
          tertiaryStart = local
          onEvent("tertiary_tap_down", tap)
          onEvent("tertiary_long_press_down", tap)
          tertiaryLongPress = longPressTimer(for: .tertiary, tap: tap)
        case .otherMouseDragged where event.buttonNumber == 2:
          tertiaryLongPress?.invalidate()
          onEvent(
            "tertiary_long_press_move_update",
            longPressMove(event, local: local, global: global, start: tertiaryStart ?? local))
        case .otherMouseUp where event.buttonNumber == 2:
          let long = tertiaryLongPress == nil
          tertiaryLongPress?.invalidate()
          tertiaryLongPress = nil
          onEvent("tertiary_tap_up", tap)
          if long {
            onEvent("tertiary_long_press_up", .null)
            onEvent("tertiary_long_press_end", longPressEnd(local: local, global: global))
          } else if let start = tertiaryStart,
            hypot(local.x - start.x, local.y - start.y) <= 18
          {
            onEvent("tertiary_long_press_cancel", .null)
          } else {
            onEvent("tertiary_tap_cancel", .null)
            onEvent("tertiary_long_press_cancel", .null)
          }
          tertiaryStart = nil
        case .scrollWheel:
          onEvent(
            "scroll",
            .map([
              "l": RufletInteractionParity.point(local),
              "g": RufletInteractionParity.point(global),
              "sd": .map(["x": .double(event.scrollingDeltaX), "y": .double(event.scrollingDeltaY)]),
            ]))
        case .pressure:
          let payload: RufletValue = .map([
            "l": RufletInteractionParity.point(local), "g": RufletInteractionParity.point(global),
            "p": .double(Double(event.pressure)),
          ])
          switch event.stage {
          case 1: onEvent("force_press_start", payload)
          case 2: onEvent("force_press_peak", payload)
          default: onEvent("force_press_update", payload)
          }
          if event.pressure == 0 { onEvent("force_press_end", payload) }
        default: break
        }
      }

      enum Button { case secondary, tertiary }

      /// Flet raises `<button>_long_press_start` with the pointer and then the
      /// bare `<button>_long_press`. The names are spelled out per button
      /// rather than interpolated, so grepping for an event finds where it is
      /// raised.
      private func longPressTimer(for button: Button, tap: RufletValue) -> Timer {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
          switch button {
          case .secondary:
            self?.onEvent("secondary_long_press_start", tap)
            self?.onEvent("secondary_long_press", .null)
            self?.secondaryLongPress = nil
          case .tertiary:
            self?.onEvent("tertiary_long_press_start", tap)
            self?.onEvent("tertiary_long_press", .null)
            self?.tertiaryLongPress = nil
          }
        }
      }

      private func pointer(
        _ event: NSEvent, local: CGPoint, global: CGPoint, start: CGPoint? = nil
      ) -> RufletValue {
        var values: [String: RufletValue] = [
          "k": .string("mouse"),
          "l": RufletInteractionParity.point(local),
          "g": RufletInteractionParity.point(global),
          "ts": .double(event.timestamp * 1_000),
          "dev": .int(0),
          "ps": .double(Double(event.pressure)),
          "pMin": .double(0), "pMax": .double(1),
          "dist": .double(0), "distMax": .double(0), "size": .double(0),
          "rMj": .double(0), "rMn": .double(0), "rMin": .double(0),
          "rMax": .double(0), "or": .double(0), "tilt": .double(0),
        ]
        if let start {
          values["ld"] = RufletInteractionParity.point(
            CGPoint(x: local.x - start.x, y: local.y - start.y))
        } else {
          values["ld"] = .null
        }
        return .map(values)
      }

      private func longPressMove(
        _ event: NSEvent, local: CGPoint, global: CGPoint, start: CGPoint
      ) -> RufletValue {
        .map([
          "l": RufletInteractionParity.point(local), "g": RufletInteractionParity.point(global),
          "ofo": RufletInteractionParity.point(
            CGPoint(x: local.x - start.x, y: local.y - start.y)),
          "lofo": RufletInteractionParity.point(
            CGPoint(x: local.x - start.x, y: local.y - start.y)),
        ])
      }

      private func longPressEnd(local: CGPoint, global: CGPoint) -> RufletValue {
        .map([
          "l": RufletInteractionParity.point(local), "g": RufletInteractionParity.point(global),
          "v": .map(["x": .double(0), "y": .double(0)]),
        ])
      }
    }
  }
#endif
