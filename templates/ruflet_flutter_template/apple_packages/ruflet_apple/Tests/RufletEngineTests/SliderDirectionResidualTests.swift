import XCTest
@testable import RufletUI

final class SliderDirectionResidualTests: XCTestCase {
  func testRTLPlacesMinimumOnRightAndMaximumOnLeft() {
    let scale = RufletSliderScale(
      minimum: 0, maximum: 100, divisions: nil, width: 120, thumbWidth: 20,
      reversed: true)

    XCTAssertEqual(scale.position(of: 0), 110, accuracy: 0.0001)
    XCTAssertEqual(scale.position(of: 100), 10, accuracy: 0.0001)
    XCTAssertEqual(scale.position(of: 25), 85, accuracy: 0.0001)
  }

  func testRTLPointerCoordinatesResolveToMirroredValues() {
    let scale = RufletSliderScale(
      minimum: 0, maximum: 100, divisions: nil, width: 120, thumbWidth: 20,
      reversed: true)

    XCTAssertEqual(scale.value(at: 10), 100, accuracy: 0.0001)
    XCTAssertEqual(scale.value(at: 110), 0, accuracy: 0.0001)
    XCTAssertEqual(scale.value(at: 85), 25, accuracy: 0.0001)
  }

  func testRTLDragDeltaMovesInLogicalDirectionAndStillSnaps() {
    let scale = RufletSliderScale(
      minimum: 0, maximum: 100, divisions: 10, width: 120, thumbWidth: 20,
      reversed: true)

    XCTAssertEqual(scale.value(startingAt: 50, translation: 20), 30, accuracy: 0.0001)
    XCTAssertEqual(scale.value(startingAt: 50, translation: -20), 70, accuracy: 0.0001)
  }

  func testLTRBehaviorRemainsTheDefault() {
    let scale = RufletSliderScale(
      minimum: 0, maximum: 100, divisions: nil, width: 120, thumbWidth: 20)

    XCTAssertEqual(scale.position(of: 25), 35, accuracy: 0.0001)
    XCTAssertEqual(scale.value(at: 35), 25, accuracy: 0.0001)
    XCTAssertEqual(scale.value(startingAt: 25, translation: 10), 35, accuracy: 0.0001)
  }
}
