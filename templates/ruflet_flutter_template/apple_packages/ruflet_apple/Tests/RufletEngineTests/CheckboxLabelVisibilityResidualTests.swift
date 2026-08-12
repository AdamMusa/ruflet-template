import XCTest
@testable import RufletUI

final class CheckboxLabelVisibilityResidualTests: XCTestCase {
  func testHiddenControlLabelMatchesBuildTextOrWidgetAbsence() {
    XCTAssertNil(RufletCheckboxLabel.visibleControlID(
      2, visibilityForID: { $0 == 2 ? false : true }))
  }

  func testVisibleControlLabelKeepsItsIdentity() {
    XCTAssertEqual(RufletCheckboxLabel.visibleControlID(
      3, visibilityForID: { _ in true }), 3)
  }

  func testUnresolvedLabelRemainsUntilStoreMaterialization() {
    XCTAssertEqual(RufletCheckboxLabel.visibleControlID(
      7, visibilityForID: { _ in nil }), 7)
    XCTAssertNil(RufletCheckboxLabel.visibleControlID(
      nil, visibilityForID: { _ in true }))
  }
}
