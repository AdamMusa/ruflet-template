import RufletEngine
import RufletProtocol
@testable import RufletSpinKit
import XCTest

@MainActor
final class SpinKitConstructorParityTests: XCTestCase {
  func testEveryPinnedConstructorDuration() {
    let expectedMilliseconds: [String: Double] = [
      "SpinKitRotatingPlain": 1_200, "SpinKitDoubleBounce": 2_000,
      "SpinKitWave": 1_200, "SpinKitWanderingCubes": 1_800,
      "SpinKitFadingFour": 1_200, "SpinKitFadingCube": 1_200,
      "SpinKitPulse": 1_000, "SpinKitChasingDots": 2_000,
      "SpinKitThreeBounce": 1_400, "SpinKitCircle": 1_200,
      "SpinKitCubeGrid": 1_200, "SpinKitFadingCircle": 1_200,
      "SpinKitRotatingCircle": 1_200, "SpinKitFoldingCube": 2_400,
      "SpinKitPumpingHeart": 1_000, "SpinKitHourGlass": 1_200,
      "SpinKitPouringHourGlass": 2_400, "SpinKitPouringHourGlassRefined": 2_400,
      "SpinKitFadingGrid": 1_200, "SpinKitRing": 1_200,
      "SpinKitRipple": 1_800, "SpinKitDualRing": 1_200,
      "SpinKitSpinningCircle": 1_200, "SpinKitSpinningLines": 1_200,
      "SpinKitSquareCircle": 500, "SpinKitThreeInOut": 1_500,
      "SpinKitDancingSquare": 1_200, "SpinKitPianoWave": 1_200,
      "SpinKitPulsingGrid": 1_200, "SpinKitWaveSpinner": 1_200,
    ]

    XCTAssertEqual(expectedMilliseconds.count, RufletSpinKitConfiguration.fletWireTypes.count)
    for wireType in RufletSpinKitConfiguration.fletWireTypes {
      XCTAssertEqual(
        RufletSpinKitConfiguration(node: ControlNode(id: 1, type: wireType)).duration,
        expectedMilliseconds[wireType, default: -1] / 1_000,
        accuracy: 0.000_001,
        "wrong flet_spinkit constructor default for \(wireType)")
    }
  }

  func testDurationDecodingMatchesFletParseDuration() {
    XCTAssertEqual(
      RufletSpinKitConfiguration.durationSeconds(.int(750), defaultMilliseconds: 1_200),
      0.75)
    XCTAssertEqual(
      RufletSpinKitConfiguration.durationSeconds(.string("825"), defaultMilliseconds: 1_200),
      0.825)
    XCTAssertEqual(
      RufletSpinKitConfiguration.durationSeconds(
        .extended(type: 3, string: "1500000"), defaultMilliseconds: 1_200),
      1.5)
    XCTAssertEqual(
      RufletSpinKitConfiguration.durationSeconds(
        .map(["seconds": .int(1), "milliseconds": .int(250), "microseconds": .int(500)]),
        defaultMilliseconds: 1_200),
      1.2505)
    XCTAssertEqual(
      RufletSpinKitConfiguration.durationSeconds(.double(12.5), defaultMilliseconds: 1_200),
      0,
      "Dart parseInt does not truncate a fractional duration")
    XCTAssertEqual(
      RufletSpinKitConfiguration.durationSeconds(nil, defaultMilliseconds: 1_800),
      1.8)
  }

  func testConstructorIntrinsicSizesMatchFlutterSpinKit() {
    let wave = RufletSpinKitConfiguration(
      node: ControlNode(id: 1, type: "SpinKitWave", props: ["size": .int(40)]))
    XCTAssertEqual(wave.frameWidth, 50)
    XCTAssertEqual(wave.frameHeight, 40)

    let piano = RufletSpinKitConfiguration(
      node: ControlNode(id: 1, type: "SpinKitPianoWave", props: ["size": .int(64)]))
    XCTAssertEqual(piano.frameWidth, 80)
    XCTAssertEqual(piano.frameHeight, 64)

    for type in ["SpinKitThreeBounce", "SpinKitThreeInOut"] {
      let configuration = RufletSpinKitConfiguration(
        node: ControlNode(id: 1, type: type, props: ["size": .int(30)]))
      XCTAssertEqual(configuration.frameWidth, 60)
      XCTAssertEqual(configuration.frameHeight, 30)
    }

    let square = RufletSpinKitConfiguration(
      node: ControlNode(id: 1, type: "SpinKitRotatingCircle", props: ["size": .int(42)]))
    XCTAssertEqual(square.frameWidth, 42)
    XCTAssertEqual(square.frameHeight, 42)
  }

  func testVariantSpecificArgumentsAndFallbacks() {
    let ring = RufletSpinKitConfiguration(node: ControlNode(id: 1, type: "SpinKitRing"))
    let lines = RufletSpinKitConfiguration(node: ControlNode(id: 1, type: "SpinKitSpinningLines"))
    let ripple = RufletSpinKitConfiguration(node: ControlNode(id: 1, type: "SpinKitRipple"))
    XCTAssertEqual(ring.effectiveLineWidth, 7)
    XCTAssertEqual(lines.effectiveLineWidth, 2)
    XCTAssertEqual(ripple.effectiveBorderWidth, 6)

    let custom = RufletSpinKitConfiguration(
      node: ControlNode(
        id: 1, type: "SpinKitWave",
        props: [
          "line_width": .double(3.5), "border_width": .double(4.5),
          "item_count": .int(1), "wave_type": .string("CENTER"),
        ]))
    XCTAssertEqual(custom.lineWidth, 3.5)
    XCTAssertEqual(custom.borderWidth, 4.5)
    XCTAssertEqual(custom.itemCount, 2)
    XCTAssertEqual(custom.waveType, "center")

    let invalidWave = RufletSpinKitConfiguration(
      node: ControlNode(
        id: 1, type: "SpinKitWave", props: ["wave_type": .string("sideways")]))
    XCTAssertEqual(invalidWave.waveType, "start")
  }

  func testWaveDelayOrderingMatchesPinnedConstructors() {
    let cases: [(String, [Double])] = [
      ("start", [-1.2, -1.1, -1, -0.9, -0.8]),
      ("end", [-0.8, -0.9, -1, -1.1, -1.2]),
      ("center", [-0.6, -0.8, -1, -0.8, -0.6]),
    ]
    for (type, expected) in cases {
      let actual = SpinKitAnimationSemantics.waveDelays(count: 5, type: type)
      XCTAssertEqual(actual.count, expected.count)
      for (actual, expected) in zip(actual, expected) {
        XCTAssertEqual(actual, expected, accuracy: 0.000_001)
      }
    }
    XCTAssertEqual(SpinKitAnimationSemantics.waveDelays(count: 1, type: "start").count, 2)
  }

  func testTimelinePhaseIsStableForZeroAndNegativeElapsedTime() {
    XCTAssertEqual(SpinKitAnimationSemantics.phase(elapsed: 2.5, duration: 1), 0.5)
    XCTAssertEqual(SpinKitAnimationSemantics.phase(elapsed: -0.25, duration: 1), 0.75)
    XCTAssertEqual(SpinKitAnimationSemantics.phase(elapsed: 1, duration: 0), 0)
  }

  func testNativeGlyphsDoNotDependOnPlatformSymbolArtwork() throws {
    let source = try String(contentsOf: sourceURL)
    XCTAssertFalse(source.contains("systemName:"))
    XCTAssertTrue(source.contains("SpinKitHeartShape"))
    XCTAssertTrue(source.contains("SpinKitHourGlassShape"))
    XCTAssertTrue(source.contains("SpinKitWaveShape"))
    XCTAssertTrue(source.contains("MaterialPalette.color(for: node, property: \"color\""))
    XCTAssertTrue(source.contains("fallback is SpinKitRotatingCircle"))
  }

  private var sourceURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletSpinKit/SpinKitControl.swift")
  }
}
