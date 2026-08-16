import XCTest

@testable import RufletEngine

final class ModalMissingContentParityTests: XCTestCase {
  func testPinnedMissingContentMessagesAreExact() {
    XCTAssertEqual(
      RufletModalKind.alertDialog.missingContentMessage,
      "AlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions.")
    XCTAssertEqual(
      RufletModalKind.cupertinoAlertDialog.missingContentMessage,
      "CupertinoAlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions.")
    XCTAssertEqual(
      RufletModalKind.bottomSheet.missingContentMessage,
      "BottomSheet.content must be visible")
    XCTAssertEqual(
      RufletModalKind.cupertinoBottomSheet.missingContentMessage,
      "CupertinoButtomSheet.content is empty.")
  }

  func testDialogsAndCupertinoSheetRejectEmptyPendingPresentation() {
    for kind in [
      RufletModalKind.alertDialog,
      .cupertinoAlertDialog,
      .cupertinoBottomSheet,
    ] {
      XCTAssertEqual(
        rufletModalPresentationError(
          kind: kind,
          open: true,
          lastOpen: false,
          hasContent: false),
        kind.missingContentMessage)
      XCTAssertFalse(
        rufletModalShouldPresent(
          kind: kind,
          open: true,
          lastOpen: false,
          presented: false,
          hasContent: false))
    }
  }

  func testMaterialBottomSheetPresentsItsMissingContentErrorInsideTheSheet() {
    XCTAssertNil(
      rufletModalPresentationError(
        kind: .bottomSheet,
        open: true,
        lastOpen: false,
        hasContent: false))
    XCTAssertTrue(
      rufletModalShouldPresent(
        kind: .bottomSheet,
        open: true,
        lastOpen: false,
        presented: false,
        hasContent: false))
  }

  func testValidationOnlyRunsForAnOpeningEdge() {
    for kind in RufletModalKind.allCases {
      XCTAssertNil(
        rufletModalPresentationError(
          kind: kind,
          open: false,
          lastOpen: false,
          hasContent: false))
      XCTAssertNil(
        rufletModalPresentationError(
          kind: kind,
          open: true,
          lastOpen: true,
          hasContent: false))
    }
  }

  func testEveryModalKindPresentsWhenContentIsAvailable() {
    for kind in RufletModalKind.allCases {
      XCTAssertNil(
        rufletModalPresentationError(
          kind: kind,
          open: true,
          lastOpen: false,
          hasContent: true))
      XCTAssertTrue(
        rufletModalShouldPresent(
          kind: kind,
          open: true,
          lastOpen: false,
          presented: false,
          hasContent: true))
    }
  }

  func testAlreadyOpenModalRehydratesAfterNativeViewRecreation() {
    for kind in RufletModalKind.allCases {
      XCTAssertTrue(
        rufletModalShouldPresent(
          kind: kind,
          open: true,
          lastOpen: true,
          presented: false,
          hasContent: true))
    }
  }

  func testPickerPresentationFollowsEveryServerOpenCycleEvenWithAStalePrivateMarker() {
    XCTAssertEqual(
      rufletPickerPresentationAction(open: true, presented: false),
      .present)
    XCTAssertEqual(
      rufletPickerPresentationAction(open: true, presented: true),
      .unchanged)
    XCTAssertEqual(
      rufletPickerPresentationAction(open: false, presented: true),
      .dismiss)
    XCTAssertEqual(
      rufletPickerPresentationAction(open: false, presented: false),
      .unchanged)

    // A second false -> true server edge must make the same native sheet
    // present again; no `_open` latch participates in this decision.
    XCTAssertEqual(
      rufletPickerPresentationAction(open: true, presented: false),
      .present)
  }
}
