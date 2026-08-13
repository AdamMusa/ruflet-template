import XCTest
@testable import RufletEngine

final class NativeTextInputOutsideTapContractTests: XCTestCase {
  func testWindowMonitoringExistsOnlyForOptedInMountedInput() {
    XCTAssertFalse(
      RufletOutsideTapMonitoringContract.shouldAttach(
        reportsTapOutside: false,
        hasWindow: true))
    XCTAssertFalse(
      RufletOutsideTapMonitoringContract.shouldAttach(
        reportsTapOutside: true,
        hasWindow: false))
    XCTAssertTrue(
      RufletOutsideTapMonitoringContract.shouldAttach(
        reportsTapOutside: true,
        hasWindow: true))
  }

  func testOutsideMonitorRejectsItsOwnInputAndNeverConsumesUnrelatedTaps() {
    XCTAssertFalse(
      RufletOutsideTapMonitoringContract.shouldReceiveTouch(
        reportsTapOutside: true,
        isInsideInput: true))
    XCTAssertFalse(
      RufletOutsideTapMonitoringContract.shouldReceiveTouch(
        reportsTapOutside: false,
        isInsideInput: false))
    XCTAssertTrue(
      RufletOutsideTapMonitoringContract.shouldReceiveTouch(
        reportsTapOutside: true,
        isInsideInput: false))
  }
}
