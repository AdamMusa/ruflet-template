import RufletEngine
import RufletProtocol
import RufletSpinKit
import XCTest

@MainActor
final class SpinKitCompatibilityTests: XCTestCase {
  private let variants: [String: String] = [
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

  func testCanonicalRubyVariantsMapExactlyToPinnedFletTypes() {
    XCTAssertEqual(RufletSpinKit.variantControlTypes, variants)
    XCTAssertEqual(RufletSpinKit.variantControlTypes.count, 30)
    XCTAssertEqual(Set(RufletSpinKit.variantControlTypes.values), RufletSpinKit.pinnedControlTypes)
  }

  func testCanonicalAndPinnedTypesAreBothRendered() {
    let extensionRegistry = RufletExtensionRegistry([RufletSpinKitExtension()])
    XCTAssertEqual(
      extensionRegistry.renderedControlTypes,
      RufletSpinKit.pinnedControlTypes.union([RufletSpinKit.canonicalControlType]))

    for (variant, pinnedType) in variants {
      XCTAssertEqual(
        RufletSpinKit.resolvedControlType(
          controlType: RufletSpinKit.canonicalControlType,
          variant: variant),
        pinnedType)
      XCTAssertNotNil(extensionRegistry.view(for: control(type: "RufletSpinKit", variant: variant)))
      XCTAssertNotNil(extensionRegistry.view(for: control(type: pinnedType)))
    }
  }

  /// Literal translation of `flet_spinkit/test/spinkit_test.dart`.
  func testMapsRufletSnakeCaseVariantsToFletSpinKitControlTypes() {
    XCTAssertEqual(
      RufletSpinKit.resolvedControlType(controlType: "RufletSpinKit", variant: nil),
      "SpinKitRotatingCircle")
    XCTAssertEqual(
      RufletSpinKit.resolvedControlType(controlType: "RufletSpinKit", variant: "double_bounce"),
      "SpinKitDoubleBounce")
    XCTAssertEqual(
      RufletSpinKit.resolvedControlType(
        controlType: "RufletSpinKit", variant: "pouring_hour_glass_refined"),
      "SpinKitPouringHourGlassRefined")
  }

  func testUnknownCanonicalVariantIsRejectedByContract() {
    XCTAssertNil(
      RufletSpinKit.resolvedControlType(controlType: "RufletSpinKit", variant: "unknown"))
    XCTAssertNil(RufletSpinKit.resolvedControlType(controlType: "Unknown", variant: nil))
  }

  private func control(type: String, variant: String? = nil) -> RufletControl {
    var properties: [String: RufletValue] = [:]
    if let variant {
      properties["variant"] = .string(variant)
    }
    return RufletControl(
      id: 1,
      type: type,
      properties: properties,
      backend: SpinKitTestBackend())
  }
}

@MainActor
private final class SpinKitTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([RufletSpinKitExtension()])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
