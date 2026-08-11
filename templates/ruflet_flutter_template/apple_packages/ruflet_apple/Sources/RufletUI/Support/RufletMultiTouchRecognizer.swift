import RufletEngine
import RufletProtocol
import SwiftUI

/// Flutter's `PointerDeviceKind` set, which a gesture is restricted to.
///
/// SwiftUI gestures report neither the pointer kind nor how many fingers are
/// down, so a control that filters on either drops to the gesture recognisers
/// underneath, where both are first-class.
enum RufletPointerDevice {
  /// UIKit's touch types against the names Flet sends. `trackpad` arrives as
  /// an indirect pointer, which is also how a connected mouse arrives, so the
  /// two share a type.
  static func allowedTouchTypeNumbers(_ names: [String]) -> [NSNumber]? {
    #if canImport(UIKit)
      guard !names.isEmpty else { return nil }
      var types: Set<UITouch.TouchType> = []
      for name in names.map({ $0.lowercased() }) {
        switch name {
        case "touch": types.insert(.direct)
        case "stylus", "invertedstylus": types.insert(.pencil)
        case "mouse", "trackpad":
          types.insert(.indirect)
          if #available(iOS 13.4, *) { types.insert(.indirectPointer) }
        default: continue
        }
      }
      guard !types.isEmpty else { return nil }
      return types.map { NSNumber(value: $0.rawValue) }
    #else
      return nil
    #endif
  }
}

#if canImport(UIKit)
  import UIKit

  /// The multi-finger tap and long press Flet's `MultiTouchGestureRecognizer`
  /// reports, with the touch count and the pointer kinds it accepts.
  ///
  /// SwiftUI's magnification gesture stands in for "two or more fingers" but
  /// cannot be told how many, so a control naming `multi_tap_touches` needs a
  /// recogniser of its own.
  struct RufletMultiTouchRecognizer: UIViewRepresentable {
    let node: ControlNode
    let events: RufletEventSink

    func makeCoordinator() -> Coordinator { Coordinator(node: node, events: events) }

    func makeUIView(context: Context) -> UIView {
      let view = PassthroughView()
      let tap = UITapGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
      let press = UILongPressGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.pressed(_:)))
      view.addGestureRecognizer(tap)
      view.addGestureRecognizer(press)
      context.coordinator.apply(node: node, to: [tap, press])
      return view
    }

    func updateUIView(_ view: UIView, context: Context) {
      context.coordinator.node = node
      context.coordinator.events = events
      context.coordinator.apply(node: node, to: view.gestureRecognizers ?? [])
    }

    /// The recogniser view must not take the touches its content wants, so it
    /// declines hit testing and the recognisers observe instead.
    final class PassthroughView: UIView {
      override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
    }

    final class Coordinator: NSObject {
      var node: ControlNode
      var events: RufletEventSink

      init(node: ControlNode, events: RufletEventSink) {
        self.node = node
        self.events = events
      }

      /// Flet defaults `multi_tap_touches` to zero, which its recogniser reads
      /// as "any number above one".
      func apply(node: ControlNode, to recognizers: [UIGestureRecognizer]) {
        let required = max(node.int("multi_tap_touches") ?? 0, 2)
        let devices = (node.array("allowed_devices") ?? []).compactMap(\.stringValue)
        let allowed = RufletPointerDevice.allowedTouchTypeNumbers(devices)
        for recognizer in recognizers {
          if let allowed { recognizer.allowedTouchTypes = allowed }
          (recognizer as? UITapGestureRecognizer)?.numberOfTouchesRequired = required
          (recognizer as? UILongPressGestureRecognizer)?.numberOfTouchesRequired = required
        }
      }

      @objc func tapped(_ sender: UITapGestureRecognizer) {
        // `ct` is `correctNumberOfTouches`, a boolean despite the abbreviated
        // name; see Flet's MultiTouchGestureRecognizer.
        events.fire(node, "multi_tap", data: .map(["ct": .bool(true)]))
      }

      @objc func pressed(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        events.fire(node, "multi_long_press")
      }
    }
  }
#endif
