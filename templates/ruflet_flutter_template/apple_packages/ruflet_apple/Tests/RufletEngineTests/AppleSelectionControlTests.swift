import RufletProtocol
import XCTest
@testable import RufletEngine

@MainActor
final class AppleSelectionControlTests: XCTestCase {
  func testChipSelectionIsImmediateAndMatchesPinnedWireContract() {
    let backend = SelectionBackend()
    let control = RufletControl(
      id: 1,
      type: "Chip",
      properties: ["on_select": true, "selected": false],
      backend: backend)
    let coordinator = RufletChipCoordinator(control: control)

    coordinator.activate()

    XCTAssertTrue(coordinator.selected)
    XCTAssertEqual(backend.updates.last?.properties, ["selected": true])
    XCTAssertEqual(backend.updates.last?.notify, true)
    XCTAssertEqual(backend.events.last?.name, "select")
    XCTAssertEqual(backend.events.last?.data, true)
  }

  func testChipClickDeleteAndFocusEventsRemainDistinct() {
    let backend = SelectionBackend()
    let control = RufletControl(
      id: 2,
      type: "Chip",
      properties: ["on_click": true, "on_delete": true],
      backend: backend)
    let coordinator = RufletChipCoordinator(control: control)

    coordinator.activate()
    coordinator.delete()
    coordinator.focusChanged(true)
    coordinator.focusChanged(false)

    XCTAssertEqual(backend.events.map(\.name), ["click", "delete", "focus", "blur"])
  }

  func testSegmentedButtonSingleSelectionAndEmptySelectionContract() {
    let backend = SelectionBackend()
    let control = RufletControl(
      id: 3,
      type: "SegmentedButton",
      properties: [
        "allow_empty_selection": true,
        "selected": ["one"],
      ],
      backend: backend)
    let coordinator = RufletSegmentSelectionCoordinator(control: control)

    coordinator.toggle("one", orderedValues: ["one", "two"])
    XCTAssertEqual(coordinator.selected, [])
    coordinator.toggle("two", orderedValues: ["one", "two"])

    XCTAssertEqual(coordinator.selected, ["two"])
    XCTAssertEqual(backend.updates.map(\.properties), [
      ["selected": []],
      ["selected": ["two"]],
    ])
    XCTAssertTrue(backend.updates.allSatisfy(\.notify))
    XCTAssertEqual(backend.events.map(\.name), ["change", "change"])
  }

  func testSegmentedButtonMultipleSelectionPreservesSegmentOrder() {
    let backend = SelectionBackend()
    let control = RufletControl(
      id: 4,
      type: "SegmentedButton",
      properties: [
        "allow_multiple_selection": true,
        "selected": ["two"],
      ],
      backend: backend)
    let coordinator = RufletSegmentSelectionCoordinator(control: control)

    coordinator.toggle("one", orderedValues: ["one", "two", "three"])

    XCTAssertEqual(coordinator.selected, ["one", "two"])
    XCTAssertEqual(backend.events.last?.data, ["one", "two"])
  }

  func testCupertinoSegmentedAndSlidingNotifyBehaviorMatchesPinnedControls() {
    let regularBackend = SelectionBackend()
    let regularControl = RufletControl(
      id: 5,
      type: "CupertinoSegmentedButton",
      properties: [:],
      backend: regularBackend)
    let regular = RufletIndexedSegmentCoordinator(
      control: regularControl, defaultIndex: nil, notify: false)
    XCTAssertNil(regular.selectedIndex)
    regular.select(2)

    XCTAssertEqual(regular.selectedIndex, 2)
    XCTAssertEqual(regularBackend.updates.last?.properties, ["selected_index": 2])
    XCTAssertEqual(regularBackend.updates.last?.notify, false)
    XCTAssertEqual(regularBackend.events.last?.data, 2)

    let slidingBackend = SelectionBackend()
    let slidingControl = RufletControl(
      id: 6,
      type: "CupertinoSlidingSegmentedButton",
      properties: [:],
      backend: slidingBackend)
    let sliding = RufletIndexedSegmentCoordinator(
      control: slidingControl, defaultIndex: 0, notify: true)
    XCTAssertEqual(sliding.selectedIndex, 0)
    sliding.select(1)

    XCTAssertEqual(slidingBackend.updates.last?.properties, ["selected_index": 1])
    XCTAssertEqual(slidingBackend.updates.last?.notify, true)
    XCTAssertEqual(slidingBackend.events.last?.data, 1)
  }
}

@MainActor
private final class SelectionBackend: RufletBackendProtocol {
  struct Update: Equatable {
    let properties: [String: RufletValue]
    let notify: Bool
  }

  struct Event: Equatable {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var updates: [Update] = []
  var events: [Event] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    updates.append(Update(properties: properties, notify: notify))
  }
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
