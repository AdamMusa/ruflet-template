public enum RufletSpinKit {
  public static let packageName = "ruflet_spinkit"
  public static let canonicalControlType = "RufletSpinKit"

  /// Canonical Ruflet variants mapped to the exact pinned Flet control type.
  public static let variantControlTypes: [String: String] = [
    "rotating_circle": "SpinKitRotatingCircle",
    "rotating_plain": "SpinKitRotatingPlain",
    "double_bounce": "SpinKitDoubleBounce",
    "wave": "SpinKitWave",
    "wandering_cubes": "SpinKitWanderingCubes",
    "fading_four": "SpinKitFadingFour",
    "fading_cube": "SpinKitFadingCube",
    "pulse": "SpinKitPulse",
    "chasing_dots": "SpinKitChasingDots",
    "three_bounce": "SpinKitThreeBounce",
    "circle": "SpinKitCircle",
    "cube_grid": "SpinKitCubeGrid",
    "fading_circle": "SpinKitFadingCircle",
    "folding_cube": "SpinKitFoldingCube",
    "pumping_heart": "SpinKitPumpingHeart",
    "hour_glass": "SpinKitHourGlass",
    "pouring_hour_glass": "SpinKitPouringHourGlass",
    "pouring_hour_glass_refined": "SpinKitPouringHourGlassRefined",
    "fading_grid": "SpinKitFadingGrid",
    "ring": "SpinKitRing",
    "ripple": "SpinKitRipple",
    "dual_ring": "SpinKitDualRing",
    "spinning_circle": "SpinKitSpinningCircle",
    "spinning_lines": "SpinKitSpinningLines",
    "square_circle": "SpinKitSquareCircle",
    "three_in_out": "SpinKitThreeInOut",
    "dancing_square": "SpinKitDancingSquare",
    "piano_wave": "SpinKitPianoWave",
    "pulsing_grid": "SpinKitPulsingGrid",
    "wave_spinner": "SpinKitWaveSpinner",
  ]

  public static let pinnedControlTypes: Set<String> = [
    "SpinKitRotatingPlain", "SpinKitDoubleBounce", "SpinKitWave", "SpinKitWanderingCubes",
    "SpinKitFadingFour", "SpinKitFadingCube", "SpinKitPulse", "SpinKitChasingDots",
    "SpinKitThreeBounce", "SpinKitCircle", "SpinKitCubeGrid", "SpinKitFadingCircle",
    "SpinKitRotatingCircle", "SpinKitFoldingCube", "SpinKitPumpingHeart", "SpinKitHourGlass",
    "SpinKitPouringHourGlass", "SpinKitPouringHourGlassRefined", "SpinKitFadingGrid",
    "SpinKitRing", "SpinKitRipple", "SpinKitDualRing", "SpinKitSpinningCircle",
    "SpinKitSpinningLines", "SpinKitSquareCircle", "SpinKitThreeInOut",
    "SpinKitDancingSquare", "SpinKitPianoWave", "SpinKitPulsingGrid", "SpinKitWaveSpinner",
  ]

  /// Exact types claimed by the extension registry. Keep this a literal set so
  /// the source auditor can prove each dispatch edge without executing Swift.
  public static let controlTypes: Set<String> = [
    "RufletSpinKit", "SpinKitRotatingPlain", "SpinKitDoubleBounce", "SpinKitWave",
    "SpinKitWanderingCubes", "SpinKitFadingFour", "SpinKitFadingCube", "SpinKitPulse",
    "SpinKitChasingDots", "SpinKitThreeBounce", "SpinKitCircle", "SpinKitCubeGrid",
    "SpinKitFadingCircle", "SpinKitRotatingCircle", "SpinKitFoldingCube",
    "SpinKitPumpingHeart", "SpinKitHourGlass", "SpinKitPouringHourGlass",
    "SpinKitPouringHourGlassRefined", "SpinKitFadingGrid", "SpinKitRing", "SpinKitRipple",
    "SpinKitDualRing", "SpinKitSpinningCircle", "SpinKitSpinningLines", "SpinKitSquareCircle",
    "SpinKitThreeInOut", "SpinKitDancingSquare", "SpinKitPianoWave", "SpinKitPulsingGrid",
    "SpinKitWaveSpinner",
  ]

  public static func resolvedControlType(controlType: String, variant: String?) -> String? {
    if controlType == canonicalControlType {
      guard let variant else { return nil }
      return variantControlTypes[variant]
    }
    return pinnedControlTypes.contains(controlType) ? controlType : nil
  }
}
