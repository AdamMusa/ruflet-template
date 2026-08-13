import Foundation
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class MenuFamilyControlTests: XCTestCase {
  func testMenuBarUsesOnlyVisibleChildrenInWireOrder() {
    let backend = MenuFamilyTestBackend()
    let control = backend.control(
      type: "MenuBar",
      properties: [
        "controls": .array([
          menuWireControl(id: 2, type: "SubmenuButton"),
          menuWireControl(
            id: 3, type: "MenuItemButton",
            properties: ["visible": .bool(false)]),
          menuWireControl(id: 4, type: "MenuItemButton"),
        ])
      ])

    XCTAssertEqual(rufletMenuChildren(control).map(\.id), [2, 4])
  }

  func testSubmenuChildrenPreserveVisibleOwnershipWithoutScreenSpecificFiltering() {
    let backend = MenuFamilyTestBackend()
    let control = backend.control(
      type: "SubmenuButton",
      properties: [
        "controls": .array([
          menuWireControl(id: 2, type: "MenuItemButton"),
          menuWireControl(id: 3, type: "Divider"),
          menuWireControl(
            id: 4, type: "MenuItemButton",
            properties: ["visible": .bool(false)]),
        ])
      ])

    XCTAssertEqual(rufletMenuChildren(control).map(\.id), [2, 3])
  }

  func testMenuItemActivationHonorsSubscriptionAndCloseOnClick() {
    let backend = MenuFamilyTestBackend()
    let control = backend.control(
      type: "MenuItemButton",
      properties: ["on_click": .bool(true), "close_on_click": .bool(true)])
    var dismissed = false

    rufletActivateMenuItem(control) { dismissed = true }

    XCTAssertEqual(backend.operations, ["event:1:click:null"])
    XCTAssertTrue(dismissed)
  }

  func testMenuItemWithoutClickHandlerDoesNotActivateOrClose() {
    let backend = MenuFamilyTestBackend()
    let control = backend.control(type: "MenuItemButton")
    var dismissed = false

    rufletActivateMenuItem(control) { dismissed = true }

    XCTAssertTrue(backend.operations.isEmpty)
    XCTAssertFalse(dismissed)
  }

  func testMenuItemCloseOnClickFalseLeavesHierarchyOpen() {
    let backend = MenuFamilyTestBackend()
    let control = backend.control(
      type: "MenuItemButton",
      properties: ["on_click": .bool(true), "close_on_click": .bool(false)])
    var dismissed = false

    rufletActivateMenuItem(control) { dismissed = true }

    XCTAssertEqual(backend.operations, ["event:1:click:null"])
    XCTAssertFalse(dismissed)
  }

  func testDisabledMenuItemCannotActivateOrClose() {
    let backend = MenuFamilyTestBackend()
    let control = backend.control(
      type: "MenuItemButton",
      properties: ["on_click": .bool(true), "disabled": .bool(true)])
    var dismissed = false

    rufletActivateMenuItem(control) { dismissed = true }

    XCTAssertTrue(backend.operations.isEmpty)
    XCTAssertFalse(dismissed)
  }

  func testPopupSelectionTriggersItemClickBeforeParentSelection() {
    let backend = MenuFamilyTestBackend()
    let parent = backend.control(type: "PopupMenuButton")
    let item = backend.control(type: "PopupMenuItem")
    let entry = RufletPopupMenuEntry.item(item, checked: nil, height: 48, padding: nil)

    rufletSelectPopupMenuEntry(entry, from: parent)

    XCTAssertEqual(
      backend.operations,
      ["event:2:click:null", "event:1:select:string(\"2\")"])
  }

  func testCheckedPopupSelectionSendsToggledValueBeforeParentSelection() {
    let backend = MenuFamilyTestBackend()
    let parent = backend.control(type: "PopupMenuButton")
    let item = backend.control(type: "PopupMenuItem")
    let entry = RufletPopupMenuEntry.item(item, checked: true, height: 48, padding: nil)

    rufletSelectPopupMenuEntry(entry, from: parent)

    XCTAssertEqual(
      backend.operations,
      ["event:2:click:bool(false)", "event:1:select:string(\"2\")"])
  }

  func testDisabledPopupItemDoesNotEmitItemOrParentEvents() {
    let backend = MenuFamilyTestBackend()
    let parent = backend.control(type: "PopupMenuButton")
    let item = backend.control(
      type: "PopupMenuItem",
      properties: ["disabled": .bool(true)])
    let entry = RufletPopupMenuEntry.item(item, checked: nil, height: 48, padding: nil)

    rufletSelectPopupMenuEntry(entry, from: parent)

    XCTAssertTrue(backend.operations.isEmpty)
  }

  func testPopupEntryBuilderFiltersNonItemsAndUsesEmptyItemsAsDividers() {
    let backend = MenuFamilyTestBackend()
    let parent = backend.control(
      type: "PopupMenuButton",
      properties: [
        "items": .array([
          menuWireControl(id: 2, type: "Text"),
          menuWireControl(id: 3, type: "PopupMenuItem"),
          menuWireControl(
            id: 4, type: "PopupMenuItem",
            properties: ["content": .string("Open")]),
        ])
      ])

    let entries = buildPopupMenuEntries(parent.children("items"))

    XCTAssertEqual(entries.map(\.id), [3, 4])
    guard case .divider = entries[0], case .item = entries[1] else {
      return XCTFail("Pinned popup entry structure was not preserved")
    }
  }

  func testPopupConstraintsPreserveAllWireBounds() {
    let constraints = RufletPopupMenuSizeConstraints([
      "min_width": 120,
      "max_width": 320,
      "min_height": 40,
      "max_height": 500,
    ])

    XCTAssertEqual(constraints.minWidth, 120)
    XCTAssertEqual(constraints.maxWidth, 320)
    XCTAssertEqual(constraints.minHeight, 40)
    XCTAssertEqual(constraints.maxHeight, 500)
  }

  func testPopupSplashRadiusConsumesPinnedProperty() {
    let backend = MenuFamilyTestBackend()
    let control = backend.control(
      type: "PopupMenuButton",
      properties: ["splash_radius": .double(31)])

    XCTAssertEqual(PopupMenuButtonControl(control: control).splashRadius, 31)
  }

  func testPopupFeedbackConsumesPinnedDefaultAndOverride() {
    let backend = MenuFamilyTestBackend()
    XCTAssertTrue(PopupMenuButtonControl(
      control: backend.control(type: "PopupMenuButton")).enableFeedback)
    XCTAssertFalse(PopupMenuButtonControl(control: backend.control(
      type: "PopupMenuButton", properties: ["enable_feedback": .bool(false)])).enableFeedback)
  }
}

private func menuWireControl(
  id: Int,
  type: String,
  properties: [String: RufletValue] = [:]
) -> RufletValue {
  .map(
    properties.merging([
      "_i": .int(Int64(id)),
      "_c": .string(type),
    ]) { current, _ in current })
}

@MainActor
private final class MenuFamilyTestBackend: RufletBackendProtocol {
  var pageURI: URL?
  lazy var extensionRegistry = RufletExtensionRegistry([])
  var operations: [String] = []
  private var nextID = 1

  func control(
    type: String,
    properties: [String: RufletValue] = [:]
  ) -> RufletControl {
    defer { nextID += 1 }
    return RufletControl(id: nextID, type: type, properties: properties, backend: self)
  }

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    operations.append("event:\(control.id):\(name):\(data)")
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    operations.append("event:\(controlID):\(name):\(data)")
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
