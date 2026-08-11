import XCTest
@testable import RufletUI

final class CupertinoControlParityTests: XCTestCase {
  func testActivityIndicatorUsesCupertinoTwelveSpokeModel() {
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.spokeCount, 12)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: nil), 12)
  }

  func testPartiallyRevealedIndicatorClampsAndRoundsLikeFlet() {
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: -1), 0)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 0), 0)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 0.01), 1)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 0.5), 6)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 1), 12)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 2), 12)
  }
}
