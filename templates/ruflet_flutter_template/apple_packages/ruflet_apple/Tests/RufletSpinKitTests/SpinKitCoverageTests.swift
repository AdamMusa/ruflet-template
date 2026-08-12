import RufletEngine
import RufletProtocol
@testable import RufletSpinKit
@testable import RufletUI
import XCTest

/// Ruflet exposes one `RufletSpinKit` control with a `variant`, where Flet has
/// thirty separate wire types. The renderer therefore has to cover every one of
/// those thirty by name, and neither conformance audit measures that: the
/// property audit sees `variant` read once, and the control audit allows the
/// thirty Flet types because Ruby never sends them.
@MainActor
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
      .appendingPathComponent("Sources/RufletSpinKit/SpinKitControl.swift")
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

  func testPinnedDefaultsMatchFletSpinKit() {
    let configuration = RufletSpinKitConfiguration(
      node: ControlNode(id: 1, type: "RufletSpinKit", props: [:]))
    XCTAssertEqual(configuration.variant, "rotating_circle")
    XCTAssertEqual(configuration.size, 50)
    XCTAssertEqual(configuration.duration, 1.2)
    XCTAssertEqual(configuration.itemCount, 5)
    XCTAssertEqual(configuration.waveType, "start")
  }

  func testIndividualFletWireTypeResolvesItsOwnVariant() {
    let configuration = RufletSpinKitConfiguration(
      node: ControlNode(
        id: 1,
        type: "SpinKitPouringHourGlassRefined",
        props: ["size": .double(64), "duration": .int(2400)]))
    XCTAssertEqual(configuration.variant, "pouring_hour_glass_refined")
    XCTAssertEqual(configuration.size, 64)
    XCTAssertEqual(configuration.duration, 2.4)
  }

  func testVariantSpecificMeasurementsAreResolved() {
    let configuration = RufletSpinKitConfiguration(
      node: ControlNode(
        id: 1,
        type: "SpinKitWave",
        props: [
          "line_width": .double(9), "border_width": .double(4),
          "item_count": .int(8), "wave_type": .string("end")
        ]))
    XCTAssertEqual(configuration.lineWidth, 9)
    XCTAssertEqual(configuration.borderWidth, 4)
    XCTAssertEqual(configuration.itemCount, 8)
    XCTAssertEqual(configuration.waveType, "end")
  }

  func testEveryIndividualFletSpinnerWireTypeIsRegistered() {
    RufletSpinKit.register(in: ServiceRegistry())
    for variant in fletVariants {
      let type = "SpinKit" + variant.split(separator: "_")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined()
      let node = ControlNode(id: 1, type: type, props: [:])
      XCTAssertNotNil(ControlRegistry.build(node: node, axis: .none))
      XCTAssertEqual(ControlRegistry.descriptor(for: type)?.rendering, .nativeView)
    }
  }
}
