import CoreGraphics
import RufletProtocol
import SwiftUI

/// Canonical payload construction shared by the native interaction controls.
///
/// The compact keys deliberately match `flet/lib/src/utils/events.dart` in the
/// vendored Flet client. Keeping this outside individual views prevents an
/// Apple control from quietly inventing a friendlier but incompatible event
/// shape.
enum FletInteractionParity {
  static func point(_ point: CGPoint) -> RufletValue {
    .map(["x": .double(point.x), "y": .double(point.y)])
  }

  static func tap(kind: String, local: CGPoint, global: CGPoint) -> RufletValue {
    .map(["k": .string(kind), "l": point(local), "g": point(global)])
  }

  static func dragDown(local: CGPoint, global: CGPoint) -> RufletValue {
    .map(["l": point(local), "g": point(global)])
  }

  static func dragStart(
    kind: String, local: CGPoint, global: CGPoint, timestamp: Double
  ) -> RufletValue {
    .map([
      "k": .string(kind), "l": point(local), "g": point(global),
      "ts": .double(timestamp),
    ])
  }

  static func dragUpdate(
    local: CGPoint, global: CGPoint, previousLocal: CGPoint,
    previousGlobal: CGPoint, primaryDelta: Double?, timestamp: Double
  ) -> RufletValue {
    .map([
      "l": point(local), "g": point(global),
      "ld": point(CGPoint(x: local.x - previousLocal.x, y: local.y - previousLocal.y)),
      "gd": point(CGPoint(x: global.x - previousGlobal.x, y: global.y - previousGlobal.y)),
      "pd": primaryDelta.map(RufletValue.double) ?? .null,
      "ts": .double(timestamp),
    ])
  }

  static func dragEnd(
    local: CGPoint, global: CGPoint, velocity: CGVector, primaryVelocity: Double?
  ) -> RufletValue {
    .map([
      "l": point(local), "g": point(global),
      "v": .map(["x": .double(velocity.dx), "y": .double(velocity.dy)]),
      "pv": primaryVelocity.map(RufletValue.double) ?? .null,
    ])
  }

  static func scaleStart(local: CGPoint, global: CGPoint, timestamp: Double) -> RufletValue {
    .map([
      "gfp": point(global), "lfp": point(local), "pc": .int(2),
      "ts": .double(timestamp),
    ])
  }

  static func scaleUpdate(
    scale: Double, local: CGPoint, global: CGPoint, previousLocal: CGPoint,
    timestamp: Double
  ) -> RufletValue {
    .map([
      "gfp": point(global),
      "fpd": point(CGPoint(x: local.x - previousLocal.x, y: local.y - previousLocal.y)),
      "lfp": point(local), "pc": .int(2), "hs": .double(scale),
      "vs": .double(scale), "s": .double(scale), "rot": .double(0),
      "ts": .double(timestamp),
    ])
  }

  static func scaleEnd(velocity: CGVector = .zero) -> RufletValue {
    .map([
      "pc": .int(2),
      "v": .map(["x": .double(velocity.dx), "y": .double(velocity.dy)]),
    ])
  }

  static func dismissUpdate(
    direction: String, progress: Double, previousReached: Bool, reached: Bool
  ) -> RufletValue {
    .map([
      "direction": .string(direction), "progress": .double(progress),
      "reached": .bool(reached), "previous_reached": .bool(previousReached),
    ])
  }

  static func key(_ label: String) -> RufletValue { .map(["key": .string(label)]) }

  static func normalizedDismissDirection(_ raw: String?) -> String {
    switch raw?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "none": return "none"
    case "up": return "up"
    case "down": return "down"
    case "starttoend": return "startToEnd"
    case "endtostart": return "endToStart"
    case "vertical": return "vertical"
    default: return "horizontal"
    }
  }

  static func dismissDirection(
    translation: CGSize, allowed raw: String?, layoutDirection: LayoutDirection = .leftToRight
  ) -> String? {
    let allowed = normalizedDismissDirection(raw)
    let horizontal = abs(translation.width) >= abs(translation.height)
    if horizontal {
      guard ["horizontal", "startToEnd", "endToStart"].contains(allowed),
        translation.width != 0
      else { return nil }
      let positiveIsStart = layoutDirection == .leftToRight
      let startToEnd = (translation.width > 0) == positiveIsStart
      let direction = startToEnd ? "startToEnd" : "endToStart"
      return allowed == "horizontal" || allowed == direction ? direction : nil
    }
    guard ["vertical", "up", "down"].contains(allowed), translation.height != 0 else {
      return nil
    }
    let direction = translation.height > 0 ? "down" : "up"
    return allowed == "vertical" || allowed == direction ? direction : nil
  }
}
