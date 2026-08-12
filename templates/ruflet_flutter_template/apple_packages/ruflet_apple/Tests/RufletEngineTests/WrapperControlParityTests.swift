import XCTest
@testable import RufletUI

final class WrapperControlParityTests: XCTestCase {
  func testScreenshotUsesFletCaptureDelayDefault() {
    XCTAssertEqual(RufletWrapperDefaults.screenshotDelay(nil), 20)
    XCTAssertEqual(RufletWrapperDefaults.screenshotDelay(0), 0)
    XCTAssertEqual(RufletWrapperDefaults.screenshotDelay(125), 125)
  }

  func testShimmerUsesFletPeriodAndLoopDefaults() {
    XCTAssertEqual(RufletWrapperDefaults.shimmerPeriod(nil), 1.5)
    XCTAssertEqual(RufletWrapperDefaults.shimmerPeriod(250), 0.25)
    XCTAssertNil(RufletWrapperDefaults.shimmerRepeats(nil))
    XCTAssertNil(RufletWrapperDefaults.shimmerRepeats(0))
    XCTAssertEqual(RufletWrapperDefaults.shimmerRepeats(3), 3)
  }
}
