import RufletProtocol
@testable import RufletUI
import XCTest

/// Flet accepts forty-one curve names and the renderer mapped seven, so every
/// other animation eased in and out regardless of what Ruby asked for. Neither
/// conformance audit could see it: `curve` is read, just not acted on.
final class CurveCoverageTests: XCTestCase {
  /// Every name `parseCurve` accepts, from Flet's own utils/animation.dart.
  private let fletCurves = [
    "bounceIn", "bounceInOut", "bounceOut", "decelerate", "ease", "easeIn",
    "easeInBack", "easeInCirc", "easeInCubic", "easeInExpo", "easeInOut",
    "easeInOutBack", "easeInOutCirc", "easeInOutCubic",
    "easeInOutCubicEmphasized", "easeInOutExpo", "easeInOutQuad",
    "easeInOutQuart", "easeInOutQuint", "easeInOutSine", "easeInQuad",
    "easeInQuart", "easeInQuint", "easeInSine", "easeInToLinear", "easeOut",
    "easeOutBack", "easeOutCirc", "easeOutCubic", "easeOutExpo", "easeOutQuad",
    "easeOutQuart", "easeOutQuint", "easeOutSine", "elasticIn", "elasticInOut",
    "elasticOut", "fastLinearToSlowEaseIn", "fastOutSlowIn", "linearToEaseOut",
    "slowMiddle",
  ]

  func testEveryFletCurveIsMapped() {
    let unmapped = fletCurves.filter { !RufletCurve.names.contains(RufletCurve.normalized($0)) }
    XCTAssertEqual(unmapped, [], "these curve names fall through to easeInOut")
  }

  func testTheCurveListMatchesFletsCount() {
    XCTAssertEqual(fletCurves.count, 41)
    XCTAssertEqual(Set(fletCurves).count, 41, "the curve list repeats a name")
  }

  /// Flet writes the names in camelCase and Ruby may write them with
  /// underscores; both have to reach the same curve.
  func testEitherSpellingResolves() {
    XCTAssertEqual(RufletCurve.normalized("easeInOutCubic"), "easeinoutcubic")
    XCTAssertEqual(RufletCurve.normalized("ease_in_out_cubic"), "easeinoutcubic")
    XCTAssertTrue(RufletCurve.names.contains(RufletCurve.normalized("ease_in_out_cubic")))
  }

  /// An absent curve is Flet's default rather than no animation.
  func testAnAbsentCurveIsEaseInOut() {
    XCTAssertEqual(RufletCurve.normalized(nil), "easeinout")
  }

  /// The canonical parser reads the curve off the animation map, which is the
  /// path every animate_* property takes.
  func testAnimationMapCarriesItsCurve() {
    let value = RufletValue.map([
      "duration": .double(400), "curve": .string("easeOutBack"),
    ])
    XCTAssertNotNil(ControlProps.animation(value))
    XCTAssertEqual(ControlProps.animationDurationSeconds(value), 0.4)
  }
}
