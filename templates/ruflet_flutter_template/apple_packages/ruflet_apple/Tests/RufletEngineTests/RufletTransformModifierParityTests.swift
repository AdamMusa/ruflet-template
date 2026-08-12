import SwiftUI
import XCTest
import RufletProtocol
@testable import RufletUI

final class RufletTransformModifierParityTests: XCTestCase {
  func testNumericRotationUsesPinnedFletDefaults() throws {
    let value = try XCTUnwrap(ControlProps.rotationPresentation(.double(0.75)))

    XCTAssertEqual(value.radians, 0.75)
    XCTAssertEqual(value.alignment, .center)
    XCTAssertEqual(value.origin, .zero)
    XCTAssertTrue(value.transformHitTests)
    XCTAssertNil(value.filterQuality)
  }

  func testRotationPreservesCompleteRotateWireShape() throws {
    let value = try XCTUnwrap(ControlProps.rotationPresentation(.map([
      "angle": .double(1.25),
      "alignment": .map(["x": .double(-1), "y": .double(1)]),
      "origin": .map(["x": .double(12), "y": .double(-8)]),
      "transform_hit_tests": .bool(false),
      "filter_quality": .string("HIGH"),
    ])))

    XCTAssertEqual(value.radians, 1.25)
    XCTAssertEqual(value.alignment, .bottomLeft)
    XCTAssertEqual(value.origin, CGSize(width: 12, height: -8))
    XCTAssertFalse(value.transformHitTests)
    XCTAssertEqual(value.filterQuality, "high")
  }

  func testRotationDefaultsMissingAngleAndStructuredOptionsLikeDartParser() throws {
    let value = try XCTUnwrap(ControlProps.rotationPresentation(.map([:])))

    XCTAssertEqual(value.radians, 0)
    XCTAssertEqual(value.alignment, .center)
    XCTAssertEqual(value.origin, .zero)
    XCTAssertTrue(value.transformHitTests)
  }

  func testScaleUniformFactorWinsOverAxisFactors() throws {
    let value = try XCTUnwrap(ControlProps.scalePresentation(.map([
      "scale": .double(2),
      "scale_x": .double(8),
      "scale_y": .double(9),
    ])))

    XCTAssertEqual(value.factors, CGSize(width: 2, height: 2))
  }

  func testScalePreservesAxesPivotAndHitTestPolicy() throws {
    let value = try XCTUnwrap(ControlProps.scalePresentation(.map([
      "scale_x": .double(1.5),
      "scale_y": .double(0.25),
      "alignment": .string("top_right"),
      "origin": .map(["x": .double(-10), "y": .double(20)]),
      "transform_hit_tests": .bool(false),
      "filter_quality": .string("low"),
    ])))

    XCTAssertEqual(value.factors, CGSize(width: 1.5, height: 0.25))
    XCTAssertEqual(value.alignment, .topRight)
    XCTAssertEqual(value.origin, CGSize(width: -10, height: 20))
    XCTAssertFalse(value.transformHitTests)
    XCTAssertEqual(value.filterQuality, "low")
  }

  func testScaleMissingAxesUseFletIdentityDefaults() throws {
    let value = try XCTUnwrap(ControlProps.scalePresentation(.map([:])))
    XCTAssertEqual(value.factors, CGSize(width: 1, height: 1))
  }

  func testAlignmentAndPixelOriginResolveToSwiftUIUnitPivot() throws {
    let rotation = try XCTUnwrap(ControlProps.rotationPresentation(.map([
      "alignment": .map(["x": .double(-1), "y": .double(0)]),
      "origin": .map(["x": .double(20), "y": .double(-10)]),
    ])))
    let anchor = rotation.anchor(in: CGSize(width: 100, height: 50))

    XCTAssertEqual(anchor.x, 0.2, accuracy: 0.000_001)
    XCTAssertEqual(anchor.y, 0.3, accuracy: 0.000_001)
  }

  func testUnknownFilterQualityFallsBackToNoBitmapFilter() throws {
    let value = try XCTUnwrap(ControlProps.scalePresentation(.map([
      "filter_quality": .string("not-a-flet-quality")
    ])))
    XCTAssertNil(value.filterQuality)
  }
}
