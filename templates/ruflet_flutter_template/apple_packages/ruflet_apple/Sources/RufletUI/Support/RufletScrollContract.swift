import CoreGraphics
import Foundation
import RufletProtocol

/// The wire contract produced by Flet's `ScrollNotificationControl`.
///
/// Flutter throttles each concrete notification class independently. Keeping
/// that distinction here matters when a start, user-direction and update
/// notification are emitted during the same native scroll sample.
enum RufletScrollNotificationKind: String, CaseIterable {
  case start
  case update
  case end
  case user
  case overscroll
}

enum RufletScrollDirection: String {
  case forward
  case reverse
  case idle
}

struct RufletScrollMetrics: Equatable {
  let pixels: CGFloat
  let minScrollExtent: CGFloat
  let maxScrollExtent: CGFloat
  let viewportDimension: CGFloat
}

struct RufletScrollSampleContract: Equatable {
  let metrics: RufletScrollMetrics
  let overscroll: CGFloat

  static func resolve(
    rawPixels: CGFloat,
    contentExtent: CGFloat,
    viewportDimension: CGFloat
  ) -> Self {
    let maximum = max(contentExtent - viewportDimension, 0)
    let pixels = min(max(rawPixels, 0), maximum)
    let overscroll: CGFloat
    if rawPixels < 0 {
      overscroll = rawPixels
    } else if rawPixels > maximum {
      overscroll = rawPixels - maximum
    } else {
      overscroll = 0
    }
    return Self(
      metrics: RufletScrollMetrics(
        pixels: pixels,
        minScrollExtent: 0,
        maxScrollExtent: maximum,
        viewportDimension: viewportDimension),
      overscroll: overscroll)
  }
}

enum RufletScrollContract {
  static let defaultIntervalMilliseconds = 10

  /// Mirrors `now - last <= scroll_interval` in Flet 0.80.5 exactly.
  static func shouldEmit(
    previous: Date?,
    now: Date,
    intervalMilliseconds: Int
  ) -> Bool {
    guard let previous else { return true }
    return now.timeIntervalSince(previous) * 1_000 > Double(intervalMilliseconds)
  }

  static func direction(for delta: CGFloat) -> RufletScrollDirection {
    if delta > 0 { return .reverse }
    if delta < 0 { return .forward }
    return .idle
  }

  static func velocity(delta: CGFloat, elapsed: TimeInterval) -> CGFloat {
    guard elapsed > 0 else { return 0 }
    return delta / elapsed
  }

  static func payload(
    kind: RufletScrollNotificationKind,
    metrics: RufletScrollMetrics,
    scrollDelta: CGFloat? = nil,
    direction: RufletScrollDirection? = nil,
    overscroll: CGFloat? = nil,
    velocity: CGFloat? = nil
  ) -> RufletValue {
    var fields: [String: RufletValue] = [
      "pixels": .double(Double(metrics.pixels)),
      "min_scroll_extent": .double(Double(metrics.minScrollExtent)),
      "max_scroll_extent": .double(Double(metrics.maxScrollExtent)),
      "viewport_dimension": .double(Double(metrics.viewportDimension)),
      "event_type": .string(kind.rawValue),
    ]
    switch kind {
    case .update:
      fields["scroll_delta"] = scrollDelta.map { .double(Double($0)) } ?? .null
    case .user:
      fields["direction"] = .string((direction ?? .idle).rawValue)
    case .overscroll:
      fields["overscroll"] = .double(Double(overscroll ?? 0))
      fields["velocity"] = .double(Double(velocity ?? 0))
    case .start, .end:
      break
    }
    return .map(fields)
  }
}
