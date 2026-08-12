import CoreGraphics
import XCTest
import RufletProtocol
@testable import RufletUI

final class InteractiveViewerEventParityTests: XCTestCase {
  func testSinglePointerPanStartCarriesNativeFocalPoints() {
    XCTAssertEqual(
      RufletInteractionParity.scaleStart(
        local: CGPoint(x: 12, y: 18), global: CGPoint(x: 112, y: 218),
        pointerCount: 1, timestamp: 500),
      .map([
        "gfp": point(112, 218), "lfp": point(12, 18),
        "pc": .int(1), "ts": .double(500),
      ]))
  }

  func testPanUpdateUsesGestureRelativeScaleAndFocalDelta() {
    XCTAssertEqual(
      RufletInteractionParity.scaleUpdate(
        scale: 1, local: CGPoint(x: 35, y: 44),
        global: CGPoint(x: 135, y: 244),
        previousLocal: CGPoint(x: 30, y: 40), pointerCount: 1,
        timestamp: 750),
      .map([
        "gfp": point(135, 244), "fpd": point(5, 4),
        "lfp": point(35, 44), "pc": .int(1),
        "hs": .double(1), "vs": .double(1), "s": .double(1),
        "rot": .double(0), "ts": .double(750),
      ]))
  }

  func testMagnificationUpdatePreservesTwoPointersAndGestureScale() {
    let payload = RufletInteractionParity.scaleUpdate(
      scale: 1.25, local: CGPoint(x: 50, y: 40),
      global: CGPoint(x: 150, y: 240), previousLocal: CGPoint(x: 50, y: 40),
      pointerCount: 2, timestamp: 900)

    XCTAssertEqual(payload.mapValue?["pc"], .int(2))
    XCTAssertEqual(payload.mapValue?["s"], .double(1.25))
    XCTAssertEqual(payload.mapValue?["fpd"], point(0, 0))
  }

  func testInteractionEndCarriesReleasedPointerCountAndNativeVelocity() {
    XCTAssertEqual(
      RufletInteractionParity.scaleEnd(
        pointerCount: 0, velocity: CGVector(dx: 320, dy: -45)),
      .map([
        "pc": .int(0),
        "v": .map(["x": .double(320), "y": .double(-45)]),
      ]))
  }

  func testExistingGestureDetectorDefaultsRemainTwoFingerScale() {
    XCTAssertEqual(
      RufletInteractionParity.scaleStart(
        local: .zero, global: .zero, timestamp: 1).mapValue?["pc"],
      .int(2))
    XCTAssertEqual(
      RufletInteractionParity.scaleEnd().mapValue?["pc"], .int(2))
  }

  private func point(_ x: Double, _ y: Double) -> RufletValue {
    .map(["x": .double(x), "y": .double(y)])
  }
}
