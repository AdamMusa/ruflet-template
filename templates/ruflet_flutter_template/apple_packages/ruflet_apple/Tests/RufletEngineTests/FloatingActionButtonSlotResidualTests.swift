import RufletEngine
@testable import RufletUI
import XCTest

final class FloatingActionButtonSlotResidualTests: XCTestCase {
  func testFabIconAcceptsOnlyIntegerOrVisibleControl() {
    let stringIcon = ControlNode(id: 1, type: "FloatingActionButton", props: [
      "icon": .string("add"),
    ])
    let integerIcon = ControlNode(id: 2, type: "FloatingActionButton", props: [
      "icon": .int(0x10001),
    ])
    let controlIcon = ControlNode(id: 3, type: "FloatingActionButton", props: [
      "icon": .controlRef(4),
    ])

    XCTAssertFalse(FloatingActionSlots(node: stringIcon) { _ in true }.hasIcon)
    XCTAssertTrue(FloatingActionSlots(node: integerIcon) { _ in true }.hasIcon)
    XCTAssertFalse(FloatingActionSlots(node: controlIcon) { _ in false }.hasIcon)
    XCTAssertEqual(FloatingActionSlots(node: controlIcon) { _ in true }.iconID, 4)
  }

  func testFabContentAcceptsOnlyStringOrVisibleControl() {
    let numeric = ControlNode(id: 1, type: "FloatingActionButton", props: [
      "content": .int(12),
    ])
    let empty = ControlNode(id: 2, type: "FloatingActionButton", props: [
      "content": .string(""),
    ])

    XCTAssertFalse(FloatingActionSlots(node: numeric) { _ in true }.hasContent)
    XCTAssertEqual(FloatingActionSlots(node: empty) { _ in true }.contentText, "")
  }

  func testFabExtendedModeUsesResolvedSlots() {
    let node = ControlNode(id: 1, type: "FloatingActionButton", props: [
      "icon": .controlRef(2), "content": .string("Compose"),
    ])
    let hiddenIcon = FloatingActionSlots(node: node) { _ in false }
    let visibleIcon = FloatingActionSlots(node: node) { _ in true }

    XCTAssertFalse(hiddenIcon.isExtended)
    XCTAssertTrue(visibleIcon.isExtended)
    XCTAssertFalse(FloatingActionPresentation(node: node, slots: hiddenIcon).isExtended)
    XCTAssertTrue(FloatingActionPresentation(node: node, slots: visibleIcon).isExtended)
  }

  func testFabValidationUsesResolvedSlotValues() {
    let invalid = ControlNode(id: 1, type: "FloatingActionButton", props: [
      "icon": .bool(true), "content": .double(3.5),
    ])
    let valid = ControlNode(id: 2, type: "FloatingActionButton", props: [
      "content": .string("Create"),
    ])

    XCTAssertNotNil(ButtonPresentation.validationMessage(
      invalid, variant: .floatingAction,
      floatingActionSlots: FloatingActionSlots(node: invalid) { _ in true }))
    XCTAssertNil(ButtonPresentation.validationMessage(
      valid, variant: .floatingAction,
      floatingActionSlots: FloatingActionSlots(node: valid) { _ in true }))
  }
}
