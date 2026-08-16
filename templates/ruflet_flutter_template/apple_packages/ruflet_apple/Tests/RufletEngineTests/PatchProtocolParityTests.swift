import XCTest
@testable import RufletEngine
@testable import RufletProtocol

@MainActor
final class PatchProtocolParityTests: XCTestCase {
  func testAllPinnedOpcodesApplyInOrderAndNotifyPerOperation() throws {
    let backend = PatchProtocolBackend()
    let root = RufletControl(
      id: 1, type: "Page",
      properties: ["items": [1, 2, 3]],
      backend: backend)
    var notifications = 0
    let token = root.addListener { notifications += 1 }
    defer { root.removeListener(token) }

    try root.applyPatch([
      .array([0, .map(["items": .array([1])])]),
      .array([0, 1, 1, 20]),
      .array([1, 1, 1, 10]),
      .array([2, 1, 2]),
      .array([3, 1, 0, 1, 2]),
    ])

    XCTAssertEqual(root.value("items"), [10, 3, 1])
    XCTAssertEqual(notifications, 4)
    XCTAssertEqual(RufletPatchOperation.replace.rawValue, 0)
    XCTAssertEqual(RufletPatchOperation.add.rawValue, 1)
    XCTAssertEqual(RufletPatchOperation.remove.rawValue, 2)
    XCTAssertEqual(RufletPatchOperation.move.rawValue, 3)
  }

  func testMapOperationsUseDynamicKeysAndMissingMoveSourceBecomesNull() throws {
    let backend = PatchProtocolBackend()
    let root = RufletControl(
      id: 1, type: "Page",
      properties: ["meta": ["a": 1, "b": 2]],
      backend: backend)

    try root.applyPatch([
      .array([0, .map(["meta": .array([1])])]),
      .array([0, 1, "a", 11]),
      .array([1, 1, "c", 3]),
      .array([2, 1, "b"]),
      .array([3, 1, "c", 1, "moved"]),
      .array([3, 1, "missing", 1, "missing_moved"]),
    ])

    XCTAssertEqual(root.value("meta"), [
      "a": 11,
      "moved": 3,
      "missing_moved": nil,
    ])
  }

  func testMoveAcrossDistinctControlOwnersNotifiesBothOnce() throws {
    let backend = PatchProtocolBackend()
    let root = RufletControl(
      id: 1, type: "Page",
      properties: [
        "left": control(id: 2, type: "Box", properties: ["items": [1, 2]]),
        "right": control(id: 3, type: "Box", properties: ["items": [3]]),
      ],
      backend: backend)
    let left = try XCTUnwrap(root.child("left"))
    let right = try XCTUnwrap(root.child("right"))
    var leftNotifications = 0
    var rightNotifications = 0
    let leftToken = left.addListener { leftNotifications += 1 }
    let rightToken = right.addListener { rightNotifications += 1 }
    defer {
      left.removeListener(leftToken)
      right.removeListener(rightToken)
    }

    let tree: RufletValue = .array([
      0,
      .map([
        "left": .array([1, .map(["items": .array([2])])]),
        "right": .array([3, .map(["items": .array([4])])]),
      ]),
    ])
    try root.applyPatch([
      tree,
      .array([3, 2, 0, 4, 1]),
    ])

    XCTAssertEqual(left.value("items"), [2])
    XCTAssertEqual(right.value("items"), [3, 1])
    XCTAssertEqual(leftNotifications, 1)
    XCTAssertEqual(rightNotifications, 1)
  }

  func testVisibleReplacementNotifiesParentEvenWhenPatchNotificationsAreOff() throws {
    let backend = PatchProtocolBackend()
    let root = RufletControl(
      id: 1, type: "Page",
      properties: ["content": control(id: 2, type: "Text", properties: ["visible": true])],
      backend: backend)
    let child = try XCTUnwrap(root.child("content"))
    var rootNotifications = 0
    var childNotifications = 0
    let rootToken = root.addListener { rootNotifications += 1 }
    let childToken = child.addListener { childNotifications += 1 }
    defer {
      root.removeListener(rootToken)
      child.removeListener(childToken)
    }

    try root.applyPatch([
      .array([0, .map(["content": .array([1])])]),
      .array([0, 1, "visible", false]),
    ], notify: false)

    XCTAssertFalse(child.visible)
    XCTAssertEqual(childNotifications, 0)
    XCTAssertEqual(rootNotifications, 1)
  }

  func testMixedContainerMoveFailsBeforeMutatingEitherTarget() throws {
    let backend = PatchProtocolBackend()
    let root = RufletControl(
      id: 1, type: "Page",
      properties: ["items": [1, 2], "meta": ["a": 3]],
      backend: backend)
    let tree: RufletValue = .array([
      0,
      .map([
        "items": .array([1]),
        "meta": .array([2]),
      ]),
    ])

    XCTAssertThrowsError(try root.applyPatch([
      tree,
      .array([3, 1, 0, 2, "moved"]),
    ])) {
      XCTAssertEqual($0 as? RufletPatchError, .invalidPath)
    }
    XCTAssertEqual(root.value("items"), [1, 2])
    XCTAssertEqual(root.value("meta"), ["a": 3])
  }

  private func control(
    id: Int,
    type: String,
    properties: [String: RufletValue]
  ) -> RufletValue {
    .map(properties.merging([
      "_c": .string(type),
      "_i": .int(Int64(id)),
    ]) { current, _ in current })
  }
}

@MainActor
private final class PatchProtocolBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  private(set) var controls: [Int: RufletControl] = [:]

  func index(_ control: RufletControl) { controls[control.id] = control }
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ value: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
