import RufletEngine
@testable import RufletUI
import XCTest

final class MenuItemButtonSlotResidualTests: XCTestCase {
  func testHiddenAndDanglingMenuItemSlotsAreAbsent() {
    let item = ControlNode(
      id: 1, type: "MenuItemButton",
      props: ["leading": .controlRef(2), "content": .controlRef(3), "trailing_icon": .controlRef(4)])
    XCTAssertNil(MenuItemButtonSlots.visibleControlID(
      item, key: "leading", visibilityForID: { _ in false }))
    XCTAssertNil(MenuItemButtonSlots.visibleControlID(
      item, key: "content", visibilityForID: { _ in nil }))
  }

  func testVisibleTrailingIconKeepsItsWireIdentity() {
    let item = ControlNode(
      id: 1, type: "MenuItemButton", props: ["trailing_icon": .controlRef(4)])
    XCTAssertEqual(MenuItemButtonSlots.visibleControlID(
      item, key: "trailing_icon", visibilityForID: { _ in true }), 4)
  }

  func testPinnedWireUsesTrailingIconNotInventedTrailingAlias() {
    let item = ControlNode(
      id: 1, type: "MenuItemButton", props: ["trailing": .controlRef(5)])
    XCTAssertNil(MenuItemButtonSlots.visibleControlID(
      item, key: "trailing_icon", visibilityForID: { _ in true }))
  }
}
