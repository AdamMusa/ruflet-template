import XCTest
@testable import RufletUI
import RufletProtocol

final class FletGeometryTests: XCTestCase {
  func testOffsetIsFractionOfChildSizeRatherThanLogicalPoints() {
    let translation = FletGeometry.fractionalTranslation(
      fraction: CGSize(width: 0.5, height: -1),
      childSize: CGSize(width: 120, height: 40))

    XCTAssertEqual(translation, CGSize(width: 60, height: -40))
  }

  func testFractionalOffsetOfZeroSizedChildIsZero() {
    let translation = FletGeometry.fractionalTranslation(
      fraction: CGSize(width: 4, height: -3), childSize: .zero)

    XCTAssertEqual(translation, .zero)
  }

  func testContinuousAlignmentPreservesIntermediateCoordinates() {
    let origin = FletGeometry.alignedOrigin(
      alignment: FletAlignment(x: 0.25, y: -0.6),
      containerSize: CGSize(width: 200, height: 100),
      childSize: CGSize(width: 40, height: 20))

    XCTAssertEqual(origin.x, 100, accuracy: 0.001)
    XCTAssertEqual(origin.y, 16, accuracy: 0.001)
  }

  func testContinuousAlignmentDoesNotClampCoordinatesOutsideUnitRange() {
    let origin = FletGeometry.alignedOrigin(
      alignment: FletAlignment(x: 2, y: -2),
      containerSize: CGSize(width: 200, height: 100),
      childSize: CGSize(width: 40, height: 20))

    XCTAssertEqual(origin.x, 240, accuracy: 0.001)
    XCTAssertEqual(origin.y, -40, accuracy: 0.001)
  }

  func testContinuousAlignmentMapsExactlyToGradientUnitCoordinates() {
    let point = FletGeometry.unitPoint(alignment: FletAlignment(x: 0.25, y: -0.6))

    XCTAssertEqual(point.x, 0.625, accuracy: 0.001)
    XCTAssertEqual(point.y, 0.2, accuracy: 0.001)
  }

  func testAlignmentParserKeepsMapValuesContinuous() {
    let alignment = ControlProps.continuousAlignment(.map([
      "x": .double(0.25),
      "y": .double(-0.6),
    ]))

    XCTAssertEqual(alignment, FletAlignment(x: 0.25, y: -0.6))
  }

  func testAlignmentParserSupportsFletNamedConstants() {
    XCTAssertEqual(ControlProps.continuousAlignment(.string("top_left")), .topLeft)
    XCTAssertEqual(ControlProps.continuousAlignment(.string("bottomEnd")), .bottomRight)
  }

  func testIndependentBorderRadiiRemainIndependent() {
    let radii = ControlProps.cornerRadii(.map([
      "top_left": .double(4),
      "top_right": .double(8),
      "bottom_left": .double(12),
      "bottom_right": .double(16),
    ]))

    XCTAssertEqual(
      radii,
      FletCornerRadii(topLeft: 4, topRight: 8, bottomLeft: 12, bottomRight: 16))
    XCTAssertEqual(ControlProps.cornerRadius(.map(["top_left": .double(4)])), 4)
  }

  func testRoundedRectangleNormalizesOversizedAdjacentCorners() {
    let shape = FletRoundedRectangle(
      radii: FletCornerRadii(topLeft: 80, topRight: 80, bottomLeft: 0, bottomRight: 0))
    let path = shape.path(in: CGRect(x: 0, y: 0, width: 100, height: 40))

    XCTAssertEqual(path.boundingRect, CGRect(x: 0, y: 0, width: 100, height: 40))
  }
}
