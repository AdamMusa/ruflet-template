import RufletEngine
@testable import RufletUI
import XCTest

final class MaterialListTileSlotResidualTests: XCTestCase {
  func testTextSlotsAcceptOnlyStringsOrVisibleControls() {
    let node = ControlNode(id: 1, type: "ListTile", props: [
      "title": .int(42),
      "subtitle": .controlRef(2),
    ])

    let hidden = MaterialListTileSlots(node: node) { $0 == 2 ? false : nil }
    XCTAssertNil(hidden.titleText)
    XCTAssertNil(hidden.titleID)
    XCTAssertNil(hidden.subtitleID)

    let visible = MaterialListTileSlots(node: node) { $0 == 2 ? true : nil }
    XCTAssertEqual(visible.subtitleID, 2)
  }

  func testEmptyStringRemainsARealTextWidget() {
    let node = ControlNode(id: 1, type: "ListTile", props: [
      "title": .string(""), "subtitle": .string("Details"),
    ])
    let slots = MaterialListTileSlots(node: node) { _ in nil }

    XCTAssertEqual(slots.titleText, "")
    XCTAssertEqual(slots.subtitleText, "Details")
    XCTAssertNil(ListTilePresentation.validationMessage(node))
  }

  func testIconSlotsAcceptOnlyIntegerCodesOrVisibleControls() {
    let node = ControlNode(id: 1, type: "ListTile", props: [
      "leading": .string("home"),
      "trailing": .int(0x10001),
    ])
    let slots = MaterialListTileSlots(node: node) { _ in true }

    XCTAssertNil(slots.leadingIcon)
    XCTAssertEqual(slots.trailingIcon, .int(0x10001))
  }

  func testDanglingControlSlotsAreOmitted() {
    let node = ControlNode(id: 1, type: "ListTile", props: [
      "leading": .controlRef(7), "trailing": .controlRef(8),
    ])
    let slots = MaterialListTileSlots(node: node) { _ in nil }

    XCTAssertNil(slots.leadingID)
    XCTAssertNil(slots.trailingID)
  }
}
