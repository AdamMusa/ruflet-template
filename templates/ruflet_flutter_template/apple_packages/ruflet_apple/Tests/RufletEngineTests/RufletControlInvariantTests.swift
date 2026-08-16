import XCTest
@testable import RufletEngine
@testable import RufletProtocol

@MainActor
final class RufletControlInvariantTests: XCTestCase {
  func testRecursiveMaterializationIndexesParentsBeforeNestedDescendants() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: [
        "configuration": .map([
          "items": .array([
            control(2, "Container", [
              "content": control(3, "Text", ["value": "nested"])
            ])
          ])
        ])
      ],
      backend: backend)

    XCTAssertEqual(backend.indexOrder, [1, 2, 3])
    let container = try XCTUnwrap(backend.controls[2])
    let text = try XCTUnwrap(backend.controls[3])
    XCTAssertTrue(container.parent === root)
    XCTAssertTrue(text.parent === container)
    XCTAssertEqual(text.string("value"), "nested")
  }

  func testSameIDDeepMergePreservesIdentityListenersAndPlainMapFields() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: [
        "content": control(2, "Text", [
          "value": "before",
          "style": ["color": "red", "size": 12],
        ])
      ],
      backend: backend)
    let child = try XCTUnwrap(root.child("content"))
    var notifications = 0
    let token = child.addListener { notifications += 1 }
    defer { child.removeListener(token) }

    XCTAssertTrue(root.update([
      "content": control(2, "Text", [
        "value": "after",
        "style": ["weight": "bold"],
      ])
    ]))

    XCTAssertTrue(root.child("content") === child)
    XCTAssertTrue(backend.controls[2] === child)
    XCTAssertEqual(child.string("value"), "after")
    XCTAssertEqual(child.value("style"), [
      "color": "red", "size": 12, "weight": "bold",
    ])
    XCTAssertEqual(notifications, 0, "notify=false must not invalidate listeners")
  }

  func testNotifyIsExplicitButVisibleAlwaysInvalidatesParent() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: ["content": control(2, "Text", ["visible": true])],
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

    XCTAssertTrue(child.update(["value": "changed"], notify: false))
    XCTAssertEqual(rootNotifications, 0)
    XCTAssertEqual(childNotifications, 0)

    XCTAssertTrue(child.update(["visible": false], notify: false))
    XCTAssertEqual(rootNotifications, 1)
    XCTAssertEqual(childNotifications, 0)

    XCTAssertTrue(child.update(["value": "notified"], notify: true))
    XCTAssertEqual(childNotifications, 1)
  }

  func testNestedVisibleMergeDoesNotInvalidateParentLikePinnedFlet() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: ["content": control(2, "Text", ["visible": true])],
      backend: backend)
    var rootNotifications = 0
    let token = root.addListener { rootNotifications += 1 }
    defer { root.removeListener(token) }

    XCTAssertTrue(root.update([
      "content": control(2, "Text", ["visible": false])
    ]))

    XCTAssertEqual(rootNotifications, 0)
    XCTAssertFalse(try XCTUnwrap(backend.controls[2]).visible)
  }

  func testInvokeListenersWaitForMountAndRunInRegistrationOrder() async throws {
    let backend = ControlInvariantBackend()
    let control = RufletControl(id: 1, type: "Page", properties: [:], backend: backend)
    var order: [Int] = []
    let invocation = Task { @MainActor in
      try await control.invokeMethod("ready", arguments: .null)
    }
    await Task.yield()

    _ = control.addInvokeMethodListener { _, _ in order.append(1); return "first" }
    _ = control.addInvokeMethodListener { _, _ in order.append(2); return "second" }

    let result = try await invocation.value
    XCTAssertEqual(result, ["first", "second"])
    XCTAssertEqual(order, [1, 2])
  }

  func testMalformedPatchKeepsEarlierOperationsLikePinnedFlet() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: ["controls": .array([control(2, "Text", ["value": "A"])])],
      backend: backend)
    let tree: RufletValue = .array([
      0,
      .map(["controls": .array([1])]),
    ])
    let patch: [RufletValue] = [
      tree,
      .array([1, 1, 1, control(3, "Text", ["value": "B"])]),
      .array([2, 1, 99]),
    ]

    XCTAssertThrowsError(try root.applyPatch(patch))
    XCTAssertEqual(root.children("controls").map(\.id), [2, 3])
    XCTAssertNotNil(backend.controls[3])
  }

  func testPatchTreePreservesIntegerKeysAndTargetsNestedControl() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: [
        "controls": .array([
          control(2, "Chart", [
            "series": .array([control(3, "Series", ["value": "before"])])
          ])
        ])
      ],
      backend: backend)
    let tree: RufletValue = .array([
      0,
      .keyedMap([
        .string("controls"): .array([
          1,
          .keyedMap([
            .int(0): .array([
              2,
              .keyedMap([
                .string("series"): .array([
                  3,
                  .keyedMap([.int(0): .array([4])]),
                ])
              ]),
            ])
          ]),
        ])
      ]),
    ])

    try root.applyPatch([
      tree,
      .array([0, 4, "value", "after"]),
    ])

    XCTAssertEqual(backend.controls[3]?.string("value"), "after")
  }

  func testPatchReplaceIsExactWhileLocalUpdateDeepMerges() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: ["style": ["color": "red", "size": 12]],
      backend: backend)

    try root.applyPatch([
      .array([0]),
      .array([0, 0, "style", ["color": "blue"]]),
    ])
    XCTAssertEqual(root.value("style"), ["color": "blue"])

    XCTAssertTrue(root.update(["style": ["weight": "bold"]]))
    XCTAssertEqual(root.value("style"), ["color": "blue", "weight": "bold"])
  }

  func testPatchIgnoresExtraOperationAndTreeFieldsLikePinnedFlet() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: ["title": "before"],
      backend: backend)

    try root.applyPatch([
      .array([0, 999, "ignored tree metadata"]),
      .array([0, 0, "title", "after", "ignored operation metadata"]),
    ])

    XCTAssertEqual(root.string("title"), "after")
  }

  func testMoveOfMissingMapKeyAssignsNullLikeDartMapRemove() throws {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: ["title": "unchanged"],
      backend: backend)

    try root.applyPatch([
      .array([0]),
      .array([3, 0, "missing", 0, "moved"]),
    ])

    XCTAssertEqual(root.value("moved"), .null)
    XCTAssertEqual(root.string("title"), "unchanged")
  }

  func testPropertyMapStripsControlMetadataRecursively() {
    let backend = ControlInvariantBackend()
    let root = RufletControl(
      id: 1,
      type: "Page",
      properties: [
        "window": control(2, "Window"),
        "child": control(3, "Text", ["value": "hello"]),
        "ignored": .null,
      ],
      backend: backend)

    XCTAssertEqual(root.propertyMap, [
      "window": [:],
      "child": ["value": "hello"],
    ])
    XCTAssertEqual(root.valueMap["window"]?["_c"], "Window")
  }

  private func control(
    _ id: Int,
    _ type: String,
    _ properties: [String: RufletValue] = [:]
  ) -> RufletValue {
    var result = properties
    result["_i"] = .int(Int64(id))
    result["_c"] = .string(type)
    return .map(result)
  }
}

@MainActor
private final class ControlInvariantBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var indexOrder: [Int] = []
  var controls: [Int: RufletControl] = [:]

  func index(_ control: RufletControl) {
    indexOrder.append(control.id)
    controls[control.id] = control
  }

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    if client { _ = controls[id]?.update(properties, notify: notify) }
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
