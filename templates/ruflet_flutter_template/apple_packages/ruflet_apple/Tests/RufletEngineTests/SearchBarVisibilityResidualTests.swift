import XCTest
@testable import RufletUI

final class SearchBarVisibilityResidualTests: XCTestCase {
  func testHiddenLeadingSlotBehavesLikeMissingBuildWidget() {
    XCTAssertNil(
      RufletSearchBarSlots.visibleID(2, visibilityForID: { $0 == 2 ? false : true }))
    XCTAssertEqual(
      RufletSearchBarSlots.visibleID(3, visibilityForID: { _ in true }), 3)
  }

  func testTrailingAndSuggestionControlsUseVisibleOrder() {
    let ids = RufletSearchBarSlots.visibleIDs(
      [1, 2, 1, 3, 4],
      visibilityForID: { id in id == 2 || id == 4 ? false : true })
    XCTAssertEqual(ids, [1, 3])
  }

  func testUnresolvedReferencesMatchFletVisibleChildrenAbsence() {
    XCTAssertNil(
      RufletSearchBarSlots.visibleID(7, visibilityForID: { _ in nil }))
    XCTAssertEqual(
      RufletSearchBarSlots.visibleIDs([7], visibilityForID: { _ in nil }), [])
  }
}
