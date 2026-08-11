import XCTest
@testable import RufletUI
import RufletProtocol

final class RufletFlexMathTests: XCTestCase {
  func testIntegerExpandFactorsReceiveProportionalSpace() {
    let shares = RufletFlexMath.allocations(available: 300, flexes: [1, 2])
    XCTAssertEqual(shares[0], 100, accuracy: 0.001)
    XCTAssertEqual(shares[1], 200, accuracy: 0.001)
  }

  func testBooleanExpandMeansOneFlexUnit() {
    XCTAssertEqual(RufletFlexMath.flex(.bool(true)), 1)
    XCTAssertEqual(RufletFlexMath.flex(.bool(false)), 0)
    XCTAssertEqual(RufletFlexMath.flex(.int(3)), 3)
  }

  func testNegativeFlexIsNotRenderedAsExpanded() {
    XCTAssertEqual(RufletFlexMath.flex(.int(-2)), 0)
  }
}
