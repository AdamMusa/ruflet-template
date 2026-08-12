import XCTest
@testable import RufletUI

final class BottomAppBarVisibilityResidualTests: XCTestCase {
  func testHiddenContentMatchesFletBuildWidgetAbsence() {
    XCTAssertNil(RufletBottomAppBarSlots.visibleContentID(
      2, visibilityForID: { $0 == 2 ? false : true }))
  }

  func testVisibleContentKeepsItsWireIdentity() {
    XCTAssertEqual(RufletBottomAppBarSlots.visibleContentID(
      3, visibilityForID: { _ in true }), 3)
  }

  func testUnresolvedContentRemainsUntilStoreMaterialization() {
    XCTAssertEqual(RufletBottomAppBarSlots.visibleContentID(
      7, visibilityForID: { _ in nil }), 7)
    XCTAssertNil(RufletBottomAppBarSlots.visibleContentID(
      nil, visibilityForID: { _ in true }))
  }
}
