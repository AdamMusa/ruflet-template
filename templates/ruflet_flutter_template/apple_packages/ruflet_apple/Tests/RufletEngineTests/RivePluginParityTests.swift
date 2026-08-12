@testable import RufletRive
import RiveRuntime
import RufletProtocol
import XCTest

final class RivePluginParityTests: XCTestCase {
  func testMissingSourceUsesPinnedFletError() {
    XCTAssertEqual(
      RiveControlSemantics.missingSourceMessage,
      "Rive must have \"src\" specified.")
  }

  func testFitUsesDartEnumNamesAndDefaultsToRiveContain() {
    let fits: [(String?, RiveFit)] = [
      (nil, .contain), ("FILL", .fill), ("contain", .contain),
      ("cover", .cover), ("fitHeight", .fitHeight),
      ("FITWIDTH", .fitWidth), ("scaleDown", .scaleDown),
      ("none", .noFit),
    ]
    for (wire, expected) in fits {
      XCTAssertEqual(RiveControlSemantics.fit(wire), expected, wire ?? "nil")
    }

    XCTAssertEqual(RiveControlSemantics.fit("fit_height"), .contain)
    XCTAssertEqual(RiveControlSemantics.fit("scale-down"), .contain)
    XCTAssertEqual(RiveControlSemantics.fit("futureFit"), .contain)
  }

  func testFlutterAlignmentMapsUseEveryNativeRiveAnchor() {
    let alignments: [(Double, Double, RiveAlignment)] = [
      (-1, -1, .topLeft), (0, -1, .topCenter), (1, -1, .topRight),
      (-1, 0, .centerLeft), (0, 0, .center), (1, 0, .centerRight),
      (-1, 1, .bottomLeft), (0, 1, .bottomCenter), (1, 1, .bottomRight),
    ]
    for (x, y, expected) in alignments {
      XCTAssertEqual(
        RiveControlSemantics.alignment(.map(["x": .double(x), "y": .double(y)])),
        expected, "(\(x), \(y))")
    }
  }

  func testMissingAlignmentCoordinatesUseFlutterZeroDefaults() {
    XCTAssertEqual(RiveControlSemantics.alignment(nil), .center)
    XCTAssertEqual(RiveControlSemantics.alignment(.map([:])), .center)
    XCTAssertEqual(
      RiveControlSemantics.alignment(.map(["x": .double(-1)])),
      .centerLeft)
    XCTAssertEqual(
      RiveControlSemantics.alignment(.map(["y": .double(1)])),
      .bottomCenter)
  }

  func testAlignmentKeyTracksWireMapUpdates() {
    XCTAssertEqual(RiveControlSemantics.alignmentKey(nil), "0.0,0.0")
    XCTAssertEqual(
      RiveControlSemantics.alignmentKey(.map([
        "x": .double(-1), "y": .double(0.25),
      ])),
      "-1.0,0.25")
  }

  func testSpeedMultiplierIsAppliedVerbatimIncludingZeroAndReverse() {
    XCTAssertEqual(RiveControlSemantics.scaledDelta(0.25, multiplier: 2), 0.5)
    XCTAssertEqual(RiveControlSemantics.scaledDelta(0.25, multiplier: 0), 0)
    XCTAssertEqual(RiveControlSemantics.scaledDelta(0.25, multiplier: -2), -0.5)
  }

  func testClipRectMatchesFlutterLTRBAndRejectsInvalidBounds() throws {
    let clip = try XCTUnwrap(RufletRiveClipRect(.map([
      "left": .double(10), "top": .double(20),
      "right": .double(70), "bottom": .double(55),
    ])))
    XCTAssertEqual(clip.rect, CGRect(x: 10, y: 20, width: 60, height: 35))
    XCTAssertNil(RufletRiveClipRect(.map([
      "left": .double(9), "top": .double(0),
      "right": .double(2), "bottom": .double(10),
    ])))
  }

  func testPointerCoordinatesHonorNativeFitAndAlignment() {
    let point = RiveControlSemantics.artboardLocation(
      CGPoint(x: 100, y: 50),
      container: CGSize(width: 200, height: 100),
      artboard: CGRect(x: 0, y: 0, width: 100, height: 100),
      fit: .contain,
      alignment: .center)
    XCTAssertEqual(point.x, 50, accuracy: 0.001)
    XCTAssertEqual(point.y, 50, accuracy: 0.001)
  }
}
