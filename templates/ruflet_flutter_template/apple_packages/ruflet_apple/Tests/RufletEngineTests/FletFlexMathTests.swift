import XCTest
@testable import RufletUI
import RufletProtocol

final class FletFlexMathTests: XCTestCase {
  func testIntegerExpandFactorsReceiveProportionalSpace() {
    let shares = FletFlexMath.allocations(available: 300, flexes: [1, 2])
    XCTAssertEqual(shares[0], 100, accuracy: 0.001)
    XCTAssertEqual(shares[1], 200, accuracy: 0.001)
  }

  func testBooleanExpandMeansOneFlexUnit() {
    XCTAssertEqual(FletFlexMath.flex(.bool(true)), 1)
    XCTAssertEqual(FletFlexMath.flex(.bool(false)), 0)
    XCTAssertEqual(FletFlexMath.flex(.int(3)), 3)
  }

  func testNegativeFlexIsNotRenderedAsExpanded() {
    XCTAssertEqual(FletFlexMath.flex(.int(-2)), 0)
  }
}
