import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class CupertinoListTileSlotResidualTests: XCTestCase {
  func testHiddenOptionalControlsDoNotReserveCupertinoLayoutSlots() {
    let node = ControlNode(
      id: 1, type: "CupertinoListTile",
      props: [
        "title": .string("Settings"),
        "leading": .controlRef(10),
        "subtitle": .controlRef(11),
        "additional_info": .controlRef(12),
        "trailing": .controlRef(13),
      ])
    let presentation = CupertinoListTilePresentation(
      node: node, visibilityForID: { _ in false })

    XCTAssertFalse(presentation.hasLeading)
    XCTAssertFalse(presentation.hasSubtitle)
    XCTAssertFalse(presentation.hasTrailing)
    XCTAssertNil(presentation.leadingID)
    XCTAssertNil(presentation.subtitleID)
    XCTAssertNil(presentation.additionalInfoID)
    XCTAssertNil(presentation.trailingID)
    XCTAssertEqual(presentation.minHeight, 44)
    XCTAssertEqual(presentation.titleSubtitleSpacing, 0)
  }

  func testVisibleOptionalControlsPreserveTheirSlots() {
    let node = ControlNode(
      id: 2, type: "CupertinoListTile",
      props: [
        "title": .controlRef(20),
        "leading": .controlRef(21),
        "subtitle": .controlRef(22),
        "additional_info": .controlRef(23),
        "trailing": .controlRef(24),
      ])
    let presentation = CupertinoListTilePresentation(
      node: node, visibilityForID: { _ in true })

    XCTAssertEqual(presentation.titleID, 20)
    XCTAssertEqual(presentation.leadingID, 21)
    XCTAssertEqual(presentation.subtitleID, 22)
    XCTAssertEqual(presentation.additionalInfoID, 23)
    XCTAssertEqual(presentation.trailingID, 24)
    XCTAssertTrue(presentation.hasLeading)
    XCTAssertTrue(presentation.hasSubtitle)
    XCTAssertTrue(presentation.hasTrailing)
    XCTAssertEqual(presentation.minHeight, 48)
  }

  func testTextSlotsRejectNonStringScalarsLikeBuildTextOrWidget() {
    let node = ControlNode(
      id: 3, type: "CupertinoListTile",
      props: [
        "title": .int(1), "subtitle": .bool(true),
        "additional_info": .double(2.5),
      ])
    let presentation = CupertinoListTilePresentation(node: node)

    XCTAssertNil(presentation.titleText)
    XCTAssertNil(presentation.subtitleText)
    XCTAssertNil(presentation.additionalInfoText)
    XCTAssertFalse(presentation.hasSubtitle)
    XCTAssertEqual(
      ListTilePresentation.validationMessage(node),
      "CupertinoListTile.title must be provided and visible")
  }

  func testIconSlotsAcceptWireIconDataAndRejectNonIconScalars() {
    let node = ControlNode(
      id: 4, type: "CupertinoListTile",
      props: [
        "title": .string("Settings"),
        "leading": .int(0x10001),
        "trailing": .bool(true),
      ])
    let presentation = CupertinoListTilePresentation(node: node)

    XCTAssertEqual(presentation.leadingIcon, .int(0x10001))
    XCTAssertNil(presentation.trailingIcon)
    XCTAssertTrue(presentation.hasLeading)
    XCTAssertFalse(presentation.hasTrailing)
  }

  func testEmptyStringsRemainValidTextContent() {
    let node = ControlNode(
      id: 5, type: "CupertinoListTile",
      props: ["title": .string(""), "subtitle": .string("")])
    let presentation = CupertinoListTilePresentation(node: node)

    XCTAssertEqual(presentation.titleText, "")
    XCTAssertEqual(presentation.subtitleText, "")
    XCTAssertTrue(presentation.hasSubtitle)
    XCTAssertNil(ListTilePresentation.validationMessage(node))
  }
}
