import XCTest

/// Ruflet exposes one `RufletSpinKit` control with a `variant`, where Flet has
/// thirty separate wire types. The renderer therefore has to cover every one of
/// those thirty by name, and neither conformance audit measures that: the
/// property audit sees `variant` read once, and the control audit allows the
/// thirty Flet types because Ruby never sends them.
final class SpinKitCoverageTests: XCTestCase {
  /// The thirty `flet_spinkit` types, as the snake-case variant names Ruby
  /// sends. Taken from the vendored contract rather than retyped.
  private let fletVariants = [
    "chasing_dots", "circle", "cube_grid", "dancing_square", "double_bounce",
    "dual_ring", "fading_circle", "fading_cube", "fading_four", "fading_grid",
    "folding_cube", "hour_glass", "piano_wave", "pouring_hour_glass",
    "pouring_hour_glass_refined", "pulse", "pulsing_grid", "pumping_heart",
    "ring", "ripple", "rotating_circle", "rotating_plain", "spinning_circle",
    "spinning_lines", "square_circle", "three_bounce", "three_in_out",
    "wandering_cubes", "wave", "wave_spinner",
  ]

  func testEverySpinnerVariantIsDrawn() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletUI/Controls/SpinKitControl.swift")
    let source = try String(contentsOf: url)

    let unhandled = fletVariants.filter { !source.contains("\"\($0)\"") }
    XCTAssertEqual(
      unhandled, [],
      "SpinKitControlView draws no glyph for these Flet spinner variants")
  }

  func testTheVariantListMatchesFletsCount() {
    XCTAssertEqual(fletVariants.count, 30)
    XCTAssertEqual(Set(fletVariants).count, 30, "the variant list repeats a name")
  }
}
