import XCTest
@testable import RufletUI

final class CupertinoAppBarVisibilityResidualTests: XCTestCase {
  func testHiddenSingleSlotsBehaveLikeMissingBuildWidgetResults() {
    let visibility: (Int) -> Bool? = { $0 == 2 ? false : true }

    XCTAssertEqual(RufletCupertinoAppBarSlots.visibleID(1, visibilityForID: visibility), 1)
    XCTAssertNil(RufletCupertinoAppBarSlots.visibleID(2, visibilityForID: visibility))
    XCTAssertNil(RufletCupertinoAppBarSlots.visibleID(nil, visibilityForID: visibility))
  }

  func testActionsFollowVisibleBuildWidgetsOrderAndDeduplicate() {
    let result = RufletCupertinoAppBarSlots.visibleIDs(
      [1, 2, 1, 3, 4],
      visibilityForID: { id in id == 2 || id == 4 ? false : true })

    XCTAssertEqual(result, [1, 3])
  }

  func testUnresolvedSlotRemainsEligibleUntilStoreMaterializesIt() {
    XCTAssertEqual(
      RufletCupertinoAppBarSlots.visibleID(7, visibilityForID: { _ in nil }), 7)
    XCTAssertEqual(
      RufletCupertinoAppBarSlots.visibleIDs([7], visibilityForID: { _ in nil }), [7])
  }
}
