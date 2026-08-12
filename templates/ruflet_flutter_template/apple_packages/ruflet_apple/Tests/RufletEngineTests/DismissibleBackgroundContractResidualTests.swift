@testable import RufletUI
import XCTest

final class DismissibleBackgroundContractResidualTests: XCTestCase {
  func testVisibleSecondaryBackgroundRequiresVisiblePrimaryBackground() {
    XCTAssertEqual(
      RufletDismissibleDefaults.backgroundValidationMessage(
        backgroundIsVisible: false, secondaryBackgroundIsVisible: true),
      RufletDismissibleDefaults.secondaryBackgroundError)
  }

  func testBothVisibleBackgroundsSatisfyDismissibleInvariant() {
    XCTAssertNil(RufletDismissibleDefaults.backgroundValidationMessage(
      backgroundIsVisible: true, secondaryBackgroundIsVisible: true))
  }

  func testHiddenSecondaryBackgroundDoesNotRequirePrimaryBackground() {
    XCTAssertNil(RufletDismissibleDefaults.backgroundValidationMessage(
      backgroundIsVisible: false, secondaryBackgroundIsVisible: false))
  }

  func testPrimaryBackgroundAloneRemainsValidForBothDirections() {
    XCTAssertNil(RufletDismissibleDefaults.backgroundValidationMessage(
      backgroundIsVisible: true, secondaryBackgroundIsVisible: false))
  }
}
