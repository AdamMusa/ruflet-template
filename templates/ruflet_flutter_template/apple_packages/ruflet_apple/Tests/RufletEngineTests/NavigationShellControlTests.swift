import Foundation
@testable import RufletEngine
import RufletProtocol
import XCTest

@MainActor
final class NavigationShellControlTests: XCTestCase {
  func testSelectionResolutionSupportsPythonNegativeIndicesAndBounds() {
    XCTAssertEqual(resolveRufletSelectionIndex(-1, count: 4), 3)
    XCTAssertEqual(resolveRufletSelectionIndex(-9, count: 4), 0)
    XCTAssertEqual(resolveRufletSelectionIndex(9, count: 4), 3)
    XCTAssertNil(resolveRufletSelectionIndex(0, count: 0))
  }

  func testNavigationDestinationsUseVisibleChildrenAndNotifyTheirParent() {
    let backend = NavigationShellTestBackend()
    let control = backend.control(
      type: "NavigationBar",
      properties: [
        "destinations": .array([
          wireControl(id: 2, type: "NavigationBarDestination"),
          wireControl(
            id: 3, type: "NavigationBarDestination",
            properties: ["visible": .bool(false)]),
          wireControl(id: 4, type: "NavigationBarDestination"),
        ])
      ])

    let children = rufletNavigationChildren(control)

    XCTAssertEqual(children.map(\.id), [2, 4])
    XCTAssertTrue(children.allSatisfy(\.notifyParent))
  }

  func testDrawerDestinationIndicesIgnoreStructuralChildren() {
    let backend = NavigationShellTestBackend()
    let control = backend.control(
      type: "NavigationDrawer",
      properties: [
        "controls": .array([
          wireControl(id: 2, type: "Text"),
          wireControl(id: 3, type: "NavigationDrawerDestination"),
          wireControl(id: 4, type: "Divider"),
          wireControl(id: 5, type: "NavigationDrawerDestination"),
        ])
      ])

    let entries = rufletNavigationDrawerEntries(control)

    XCTAssertEqual(entries.map(\.id), [2, 3, 4, 5])
    XCTAssertEqual(entries.map(\.destinationIndex), [nil, 0, nil, 1])
    XCTAssertTrue(entries.allSatisfy { $0.control.notifyParent })
  }

  func testNavigationSelectionUpdatesBeforeChangeEventAndNotifiesParent() {
    let backend = NavigationShellTestBackend()
    let control = backend.control(type: "NavigationBar")

    rufletCommitSelection(control: control, index: 2, notify: true)

    XCTAssertEqual(backend.operations, ["update:2:true", "event:change:2"])
  }

  func testTabsResolveNegativeSelectionAndCommitWithoutParentNotification() {
    let backend = NavigationShellTestBackend()
    let control = backend.control(
      type: "Tabs",
      properties: ["length": .int(3), "selected_index": .int(-1)])
    let state = RufletTabsState(control: control)

    XCTAssertEqual(state.selectedIndex, 2)
    state.select(1)

    XCTAssertEqual(state.selectedIndex, 1)
    XCTAssertEqual(backend.operations, ["update:1:false", "event:change:1"])
  }

  func testTabsPreserveAndClampCurrentSelectionWhenLengthChanges() {
    let backend = NavigationShellTestBackend()
    let control = backend.control(
      type: "Tabs",
      properties: ["length": .int(4), "selected_index": .int(3)])
    let state = RufletTabsState(control: control)
    control.update(["length": .int(2)])

    state.synchronizeFromControl()

    XCTAssertEqual(state.length, 2)
    XCTAssertEqual(state.selectedIndex, 1)
    XCTAssertEqual(backend.operations, ["update:1:false"])
  }

  func testNavigationLabelBehaviorMatchesPinnedFletNames() {
    XCTAssertTrue(RufletNavigationLabelBehavior.wire("alwaysShow").showsLabel(selected: false))
    XCTAssertFalse(RufletNavigationLabelBehavior.wire("alwaysHide").showsLabel(selected: true))
    XCTAssertFalse(RufletNavigationLabelBehavior.wire("onlyShowSelected").showsLabel(selected: false))
    XCTAssertTrue(RufletNavigationLabelBehavior.wire("onlyShowSelected").showsLabel(selected: true))
  }
}

private func wireControl(
  id: Int,
  type: String,
  properties: [String: RufletValue] = [:]
) -> RufletValue {
  .map(properties.merging([
    "_i": .int(Int64(id)),
    "_c": .string(type),
  ]) { current, _ in current })
}

@MainActor
private final class NavigationShellTestBackend: RufletBackendProtocol {
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
    operations.append("event:\(name):\(data.integer ?? -1)")
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    operations.append("event:\(name):\(data.integer ?? -1)")
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    operations.append("update:\(properties["selected_index"]?.integer ?? -1):\(notify)")
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
