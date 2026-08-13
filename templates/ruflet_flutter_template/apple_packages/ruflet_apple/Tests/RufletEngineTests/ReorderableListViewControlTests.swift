import Foundation
import RufletProtocol
import Testing

@testable import RufletEngine

@MainActor
@Suite("Pinned Flet ReorderableListView contract")
struct ReorderableListViewControlTests {
  @Test("downward reorder emits start, insertion end, then adjusted reorder")
  func downwardLifecycle() {
    let backend = ReorderableTestBackend()
    let control = makeList(ids: [10, 20, 30], backend: backend)
    let coordinator = RufletReorderCoordinator(initialIDs: [10, 20, 30])

    coordinator.mount(control: control)
    #expect(coordinator.beginDragging(at: 0) == 10)
    coordinator.enter(targetID: 30)
    #expect(coordinator.orderedIDs == [20, 30, 10])
    #expect(coordinator.performDrop())

    #expect(backend.events == [
      .init(name: "reorder_start", data: ["old_index": 0]),
      .init(name: "reorder_end", data: ["new_index": 3]),
      .init(name: "reorder", data: ["old_index": 0, "new_index": 2]),
    ])
  }

  @Test("upward and stationary drops retain Flutter insertion semantics")
  func upwardAndStationary() {
    let backend = ReorderableTestBackend()
    let control = makeList(ids: [10, 20, 30], backend: backend)
    let coordinator = RufletReorderCoordinator(initialIDs: [10, 20, 30])
    coordinator.mount(control: control)

    #expect(coordinator.beginDragging(at: 2) == 30)
    coordinator.enter(targetID: 10)
    #expect(coordinator.orderedIDs == [30, 10, 20])
    #expect(coordinator.performDrop())
    #expect(backend.events.suffix(2) == [
      .init(name: "reorder_end", data: ["new_index": 0]),
      .init(name: "reorder", data: ["old_index": 2, "new_index": 0]),
    ])

    backend.events.removeAll()
    #expect(coordinator.beginDragging(at: 0) == 30)
    #expect(coordinator.performDrop())
    #expect(backend.events == [
      .init(name: "reorder_start", data: ["old_index": 0]),
      .init(name: "reorder_end", data: ["new_index": 0]),
    ])
  }

  @Test("server child updates replace local order and unmount removes synchronization")
  func synchronizationLifecycle() {
    let backend = ReorderableTestBackend()
    let control = makeList(ids: [10, 20, 30], backend: backend)
    let coordinator = RufletReorderCoordinator(initialIDs: [])

    coordinator.mount(control: control)
    coordinator.mount(control: control)
    #expect(coordinator.orderedIDs == [10, 20, 30])

    control.update(["controls": .array([wireControl(40), wireControl(50)])], notify: true)
    #expect(coordinator.orderedIDs == [40, 50])

    coordinator.unmount()
    control.update(["controls": .array([wireControl(60)])], notify: true)
    #expect(coordinator.orderedIDs == [40, 50])
  }

  @Test("disabled lists and invalid indices cannot begin a native drag")
  func disabledAndBounds() {
    let backend = ReorderableTestBackend()
    let control = makeList(ids: [10], backend: backend, disabled: true)
    let coordinator = RufletReorderCoordinator(initialIDs: [10])
    coordinator.mount(control: control)

    #expect(coordinator.beginDragging(at: 0) == nil)
    #expect(coordinator.beginDragging(at: 4) == nil)
    #expect(backend.events.isEmpty)
  }

  @Test("item identity preserves every pinned scalar key type and ID fallback")
  func identities() {
    let backend = ReorderableTestBackend()
    let fallback = RufletControl(id: 8, type: "Text", properties: [:], backend: backend)
    let integer = RufletControl(
      id: 9, type: "Text", properties: ["key": 1], backend: backend)
    let double = RufletControl(
      id: 10, type: "Text", properties: ["key": 1.5], backend: backend)
    let boolean = RufletControl(
      id: 11, type: "Text", properties: ["key": true], backend: backend)
    let string = RufletControl(
      id: 12, type: "Text", properties: ["key": "1"], backend: backend)

    #expect(rufletReorderIdentity(fallback) == .integer(8))
    #expect(rufletReorderIdentity(integer) == .integer(1))
    #expect(rufletReorderIdentity(double) == .double(1.5))
    #expect(rufletReorderIdentity(boolean) == .boolean(true))
    #expect(rufletReorderIdentity(string) == .string("1"))
    #expect(
      parseKey(.map(["_type": "scroll", "value": true]) as RufletValue)
        == .scroll(.boolean(true)))
  }

  private func makeList(
    ids: [Int],
    backend: ReorderableTestBackend,
    disabled: Bool = false
  ) -> RufletControl {
    RufletControl(
      id: 1,
      type: "ReorderableListView",
      properties: [
        "controls": .array(ids.map(wireControl)),
        "disabled": .bool(disabled),
      ],
      backend: backend)
  }
}

private func wireControl(_ id: Int) -> RufletValue {
  .map([
    "_c": "Text",
    "_i": .int(Int64(id)),
    "value": .string("Item \(id)"),
  ])
}

@MainActor
private final class ReorderableTestBackend: RufletBackendProtocol {
  struct Event: Equatable {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var events: [Event] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(.init(name: name, data: data))
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
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
