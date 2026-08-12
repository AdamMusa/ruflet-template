import XCTest

@testable import RufletUI

final class CupertinoPickerSelectionSyncResidualTests: XCTestCase {
  func testObserverSnapshotCarriesTheDeliveredIndexAndRenderedChildCount() {
    let old = RufletCupertinoPickerSelectionSnapshot(
      selectedIndex: 0, visibleCount: 4, looping: false)
    let next = RufletCupertinoPickerSelectionSnapshot(
      selectedIndex: 3, visibleCount: 2, looping: true)
    XCTAssertNotEqual(old, next)
    XCTAssertEqual(next.selectedIndex, 3)
    XCTAssertEqual(next.visibleCount, 2)
    XCTAssertTrue(next.looping)
  }

  func testFiniteExternalSelectionClampsToNativeWheelRange() {
    XCTAssertEqual(
      CupertinoPickerParity.normalizedSelectedIndex(-3, count: 4, looping: false), 0)
    XCTAssertEqual(
      CupertinoPickerParity.normalizedSelectedIndex(2, count: 4, looping: false), 2)
    XCTAssertEqual(
      CupertinoPickerParity.normalizedSelectedIndex(9, count: 4, looping: false), 3)
    XCTAssertEqual(
      CupertinoPickerParity.normalizedSelectedIndex(9, count: 0, looping: false), 0)
  }

  func testLoopingExternalSelectionMapsThroughVisibleChildCount() {
    XCTAssertEqual(
      CupertinoPickerParity.normalizedSelectedIndex(6, count: 4, looping: true), 2)
    XCTAssertEqual(
      CupertinoPickerParity.normalizedSelectedIndex(-1, count: 4, looping: true), 0)
    XCTAssertEqual(
      CupertinoPickerParity.initialIndex(selected: 2, count: 4, looping: true), 202)
  }

  func testHiddenChildrenCanInvalidateOldLoopingTagDespiteSameRealIndex() {
    // Built for four controls, selected wire index 3.
    let oldWheelIndex = CupertinoPickerParity.initialIndex(
      selected: 3, count: 4, looping: true)
    XCTAssertEqual(oldWheelIndex, 203)

    // After two children become hidden the wheel has tags 0..<202. The old
    // tag still maps to logical item 1, but is no longer a valid tag.
    XCTAssertEqual(
      CupertinoPickerParity.selectedIndex(
        wheelIndex: oldWheelIndex, count: 2, looping: true),
      1)
    XCTAssertFalse(CupertinoPickerParity.isValidWheelIndex(
      oldWheelIndex, count: 2, looping: true))
    XCTAssertEqual(
      CupertinoPickerParity.initialIndex(selected: 1, count: 2, looping: true),
      101)
  }

  func testFiniteWheelSelectionNeverUsesLoopingModulo() {
    XCTAssertEqual(
      CupertinoPickerParity.selectedIndex(
        wheelIndex: 6, count: 4, looping: false),
      3)
    XCTAssertEqual(
      CupertinoPickerParity.selectedIndex(
        wheelIndex: 6, count: 4, looping: true),
      2)
  }

  func testWheelValidityUsesRenderedFiniteDelegateBounds() {
    XCTAssertTrue(CupertinoPickerParity.isValidWheelIndex(
      3, count: 4, looping: false))
    XCTAssertFalse(CupertinoPickerParity.isValidWheelIndex(
      4, count: 4, looping: false))
    XCTAssertTrue(CupertinoPickerParity.isValidWheelIndex(
      403, count: 4, looping: true))
    XCTAssertFalse(CupertinoPickerParity.isValidWheelIndex(
      404, count: 4, looping: true))
    XCTAssertFalse(CupertinoPickerParity.isValidWheelIndex(
      0, count: 0, looping: true))
  }
}
