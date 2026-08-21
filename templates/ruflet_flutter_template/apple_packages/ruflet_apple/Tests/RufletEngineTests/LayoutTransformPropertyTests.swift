import QuartzCore
import XCTest

@testable import RufletEngine

final class LayoutTransformPropertyTests: XCTestCase {
  func testFlipConsumesCurrentFletAndRubyCompatibilityNames() throws {
    let current = try XCTUnwrap(parseFlipDetails([
      "flip_x": true,
      "flip_y": false,
      "origin": ["x": 12, "y": 8],
      "transform_hit_tests": false,
    ]))
    XCTAssertTrue(current.flipX)
    XCTAssertFalse(current.flipY)
    XCTAssertEqual(current.origin, CGSize(width: 12, height: 8))
    XCTAssertFalse(current.transformHitTests)

    let ruby = try XCTUnwrap(parseFlipDetails(["horizontal": true, "vertical": true]))
    XCTAssertTrue(ruby.flipX)
    XCTAssertTrue(ruby.flipY)
  }

  func testTransformConsumesRecordedFletMatrixOperations() throws {
    let details = try XCTUnwrap(parseTransformDetails([
      "matrix": [
        "ctor": ["name": "translation_values", "args": [12, 8, 0]],
        "ops": [["name": "scale", "args": [2, 3]]],
      ],
      "alignment": ["x": 0, "y": 0],
    ]))

    XCTAssertEqual(details.matrix.m41, 12, accuracy: 0.0001)
    XCTAssertEqual(details.matrix.m42, 8, accuracy: 0.0001)
    XCTAssertEqual(details.matrix.m11, 2, accuracy: 0.0001)
    XCTAssertEqual(details.matrix.m22, 3, accuracy: 0.0001)
    XCTAssertEqual(details.alignment, .center)
  }

  func testTransformConsumesLegacyDirectMatrixEntries() throws {
    let details = try XCTUnwrap(parseTransformDetails([
      "m00": 1,
      "m11": 2,
      "m03": 25,
      "m13": 30,
    ]))

    XCTAssertEqual(details.matrix.m11, 1, accuracy: 0.0001)
    XCTAssertEqual(details.matrix.m22, 2, accuracy: 0.0001)
    XCTAssertEqual(details.matrix.m41, 25, accuracy: 0.0001)
    XCTAssertEqual(details.matrix.m42, 30, accuracy: 0.0001)
  }
}
