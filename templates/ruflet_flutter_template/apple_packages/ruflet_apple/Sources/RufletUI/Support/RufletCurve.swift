import SwiftUI

/// Flutter's `Curves` against SwiftUI animations.
///
/// Most of Flutter's curves are cubic béziers, and SwiftUI takes the same four
/// control points through `timingCurve`, so they carry across exactly. The
/// control points here are the ones Flutter declares in
/// `packages/flutter/lib/src/animation/curves.dart`.
///
/// The families that are not béziers — bounce, elastic and decelerate — are
/// approximated: bounce and elastic map onto springs whose damping gives the
/// same character, and decelerate is Flutter's flipped parabola, which
/// `easeOut` follows closely.
enum RufletCurve {
  /// The bézier control points, keyed by the name Flet sends with underscores
  /// stripped. `parseCurve` lower-cases and removes them before matching, so a
  /// Ruby app may write either spelling.
  private static let beziers: [String: (Double, Double, Double, Double)] = [
    "ease": (0.25, 0.1, 0.25, 1.0),
    "easein": (0.42, 0.0, 1.0, 1.0),
    "easeinback": (0.6, -0.28, 0.735, 0.045),
    "easeincirc": (0.6, 0.04, 0.98, 0.335),
    "easeincubic": (0.55, 0.055, 0.675, 0.19),
    "easeinexpo": (0.95, 0.05, 0.795, 0.035),
    "easeinout": (0.42, 0.0, 0.58, 1.0),
    "easeinoutback": (0.68, -0.55, 0.265, 1.55),
    "easeinoutcirc": (0.785, 0.135, 0.15, 0.86),
    "easeinoutcubic": (0.645, 0.045, 0.355, 1.0),
    // Flutter's emphasized curve is a three-point cubic; its first segment is
    // the closest single bézier, which is what a two-point curve can express.
    "easeinoutcubicemphasized": (0.645, 0.045, 0.355, 1.0),
    "easeinoutexpo": (1.0, 0.0, 0.0, 1.0),
    "easeinoutquad": (0.455, 0.03, 0.515, 0.955),
    "easeinoutquart": (0.77, 0.0, 0.175, 1.0),
    "easeinoutquint": (0.86, 0.0, 0.07, 1.0),
    "easeinoutsine": (0.445, 0.05, 0.55, 0.95),
    "easeinquad": (0.55, 0.085, 0.68, 0.53),
    "easeinquart": (0.895, 0.03, 0.685, 0.22),
    "easeinquint": (0.755, 0.05, 0.855, 0.06),
    "easeinsine": (0.47, 0.0, 0.745, 0.715),
    "easeintolinear": (0.67, 0.03, 0.65, 0.09),
    "easeout": (0.0, 0.0, 0.58, 1.0),
    "easeoutback": (0.175, 0.885, 0.32, 1.275),
    "easeoutcirc": (0.075, 0.82, 0.165, 1.0),
    "easeoutcubic": (0.215, 0.61, 0.355, 1.0),
    "easeoutexpo": (0.19, 1.0, 0.22, 1.0),
    "easeoutquad": (0.25, 0.46, 0.45, 0.94),
    "easeoutquart": (0.165, 0.84, 0.44, 1.0),
    "easeoutquint": (0.23, 1.0, 0.32, 1.0),
    "easeoutsine": (0.39, 0.575, 0.565, 1.0),
    "fastlineartosloweasein": (0.18, 1.0, 0.04, 1.0),
    "fastoutslowin": (0.4, 0.0, 0.2, 1.0),
    "lineartoeaseout": (0.35, 0.91, 0.33, 0.97),
    "slowmiddle": (0.15, 0.85, 0.85, 0.15),
  ]

  /// Every curve name Flet accepts. Kept beside the table so a name added
  /// upstream shows up as unmapped rather than silently easing in and out.
  static let names: Set<String> = Set(beziers.keys).union([
    "linear", "decelerate", "bouncein", "bounceout", "bounceinout",
    "elasticin", "elasticout", "elasticinout",
  ])

  static func normalized(_ name: String?) -> String {
    (name ?? "easeinout").lowercased().replacingOccurrences(of: "_", with: "")
  }

  /// The animation for a curve name over a duration in seconds.
  static func animation(_ name: String?, duration: Double) -> Animation {
    let key = normalized(name)
    if let points = beziers[key] {
      return .timingCurve(points.0, points.1, points.2, points.3, duration: duration)
    }
    switch key {
    case "linear": return .linear(duration: duration)
    // Flutter's DecelerateCurve is a flipped parabola: fast at the start,
    // settling at the end, which is the shape easeOut draws.
    case "decelerate": return .easeOut(duration: duration)
    // Bounce and elastic overshoot; a spring is the same character, and the
    // damping separates the two — elastic rings longer than bounce.
    case "bouncein", "bounceout", "bounceinout":
      return .spring(response: duration, dampingFraction: 0.62)
    case "elasticin", "elasticout", "elasticinout":
      return .spring(response: duration, dampingFraction: 0.35)
    default: return .easeInOut(duration: duration)
    }
  }
}
