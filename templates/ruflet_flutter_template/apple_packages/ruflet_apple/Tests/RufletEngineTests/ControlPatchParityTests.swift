import XCTest
import RufletEngine
import RufletProtocol

/// Source translations of `Control.applyPatch()` in the pinned Flet 0.80.5
/// `flet/lib/src/models/control.dart`.
final class ControlPatchParityTests: XCTestCase {
  func testDecoderPreservesFletTreeIndexAndAllFourOperationTypes() throws {
    let patch = try ControlPatch.decode(payload: .map([
      "id": .int(1),
      "patch": .array([
        .array([.int(0), .map([
          "controls": .array([.int(1), .map([
            "0": .array([.int(2)])
          ])])
        ])]),
        .array([.int(0), .int(2), .string("value"), .string("replaced")]),
        .array([.int(1), .int(1), .int(0), .string("added")]),
        .array([.int(2), .int(1), .int(1)]),
        .array([.int(3), .int(1), .int(0), .int(1), .int(1)])
      ])
    ]))

    XCTAssertEqual(patch.pathIndex, [0: [], 1: ["controls"], 2: ["controls", "0"]])
    XCTAssertEqual(patch.operations, [
      .replace(target: 2, key: .string("value"), value: .string("replaced")),
      .add(target: 1, key: .int(0), value: .string("added")),
      .remove(target: 1, key: .int(1)),
      .move(fromTarget: 1, fromKey: .int(0), toTarget: 1, toKey: .int(1))
    ])
  }

  func testAddRemoveAndMoveKeepControlIdentityAndListOrder() throws {
    let store = pageStore(controls: [text(100, "A"), text(101, "B")])
    let revision = store.revision

    let patch = try ControlPatch.decode(payload: .map([
      "id": .int(1),
      "patch": .array([
        .array([.int(0), .map(["controls": .array([.int(1)])])]),
        .array([.int(1), .int(1), .int(1), text(102, "C")]),
        .array([.int(2), .int(1), .int(0)]),
        .array([.int(3), .int(1), .int(1), .int(1), .int(0)])
      ])
    ]))

    XCTAssertTrue(store.apply(patch))
    XCTAssertEqual(store.page?.childIDs, [101, 102])
    XCTAssertEqual(store.node(101)?.string("value"), "B")
    XCTAssertEqual(store.node(102)?.string("value"), "C")
    XCTAssertNil(store.node(100), "removed controls are swept from the flat index")
    XCTAssertGreaterThan(store.revision, revision)
  }

  func testPathTargetsAreResolvedAgainAfterAnEarlierMove() throws {
    let firstSeries: RufletValue = .map([
      "_i": .int(200), "_c": .string("LineChartData"),
      "name": .string("first"), "data_points": .array([.int(10)])
    ])
    let secondSeries: RufletValue = .map([
      "_i": .int(201), "_c": .string("LineChartData"),
      "name": .string("second"), "data_points": .array([.int(20)])
    ])
    let chart: RufletValue = .map([
      "_i": .int(100), "_c": .string("LineChart"),
      "data_series": .array([firstSeries, secondSeries])
    ])
    let store = pageStore(controls: [chart])

    let patch = try ControlPatch.decode(payload: .map([
      "id": .int(1),
      "patch": .array([
        .array([.int(0), .map([
          "controls": .array([.int(1), .map([
            "0": .array([.int(2), .map([
              "data_series": .array([.int(3), .map([
                "1": .array([.int(4), .map([
                  "data_points": .array([.int(5)])
                ])])
              ])])
            ])])
          ])])
        ])]),
        // Move the second series to the front.
        .array([.int(3), .int(3), .int(1), .int(3), .int(0)]),
        // Target 4 is path data_series[1], so it now resolves to id 200.
        .array([.int(0), .int(4), .string("name"), .string("moved-first")]),
        .array([.int(1), .int(5), .int(1), .int(11)])
      ])
    ]))

    XCTAssertTrue(store.apply(patch))
    XCTAssertEqual(store.node(100)?.controlIDs(forKey: "data_series"), [201, 200])
    XCTAssertEqual(store.node(201)?.string("name"), "second")
    XCTAssertEqual(store.node(200)?.string("name"), "moved-first")
    XCTAssertEqual(store.node(200)?.array("data_points"), [.int(10), .int(11)])
  }

  func testMapAddRemoveAndMoveMatchDartMapOperations() throws {
    let store = pageStore(properties: [
      "source": .map(["a": .int(1), "b": .int(2)]),
      "destination": .map(["kept": .bool(true)])
    ])
    let patch = try ControlPatch.decode(payload: .map([
      "id": .int(1),
      "patch": .array([
        .array([.int(0), .map([
          "source": .array([.int(1)]),
          "destination": .array([.int(2)])
        ])]),
        .array([.int(1), .int(1), .string("c"), .int(3)]),
        .array([.int(2), .int(1), .string("a")]),
        .array([.int(3), .int(1), .string("b"), .int(2), .string("moved")])
      ])
    ]))

    XCTAssertTrue(store.apply(patch))
    XCTAssertEqual(store.page?.map("source"), ["c": .int(3)])
    XCTAssertEqual(store.page?.map("destination"), [
      "kept": .bool(true), "moved": .int(2)
    ])
  }

  func testWireReplaceReplacesMapWhileLocalSetKeepsControlUpdateMergeSemantics() throws {
    let store = pageStore(properties: [
      "style": .map(["color": .string("red"), "size": .int(12)])
    ])

    XCTAssertTrue(store.apply(try ControlPatch.decode(payload: .map([
      "id": .int(1),
      "patch": .array([
        .array([.int(0)]),
        .array([.int(0), .int(0), .string("style"), .map(["color": .string("blue")])])
      ])
    ]))))
    XCTAssertEqual(store.page?.map("style"), ["color": .string("blue")])

    XCTAssertTrue(store.apply(ControlPatch(controlID: 1, operations: [
      .set(key: "style", value: .map(["weight": .string("bold")]))
    ])))
    XCTAssertEqual(store.page?.map("style"), [
      "color": .string("blue"), "weight": .string("bold")
    ])
  }

  func testIdenticalAndEmptyPatchesAreNoOps() throws {
    let store = pageStore(properties: ["value": .string("same")])
    let revision = store.revision
    let identical = try ControlPatch.decode(payload: .map([
      "id": .int(1),
      "patch": .array([
        .array([.int(0)]),
        .array([.int(0), .int(0), .string("value"), .string("same")])
      ])
    ]))

    XCTAssertFalse(store.apply(identical))
    XCTAssertFalse(store.apply(try ControlPatch.decode(payload: .map([
      "id": .int(404), "patch": .array([])
    ]))))
    XCTAssertEqual(store.revision, revision)
    XCTAssertNil(store.node(404))
    XCTAssertTrue(store.lastChangedIDs.isEmpty)
  }

  func testLocalScalarEditInvalidatesOnlyItsControl() {
    let store = pageStore(controls: [text(100, "before"), text(101, "other")])
    let revision = store.revision

    store.setLocalProperty(100, key: "value", value: .string("after"))

    XCTAssertEqual(store.node(100)?.string("value"), "after")
    XCTAssertEqual(store.node(101)?.string("value"), "other")
    XCTAssertEqual(store.lastChangedIDs, [100])
    XCTAssertEqual(store.revision, revision + 1)
  }

  func testMalformedPatchIsRejectedAtomically() {
    let store = pageStore(controls: [text(100, "A")])
    let before = store.nodes
    let revision = store.revision
    let patch = ControlPatch(
      controlID: 1,
      pathIndex: [0: [], 1: ["controls"]],
      operations: [
        .add(target: 1, key: .int(1), value: text(101, "B")),
        .remove(target: 1, key: .int(99))
      ])

    XCTAssertFalse(store.apply(patch))
    XCTAssertEqual(store.nodes, before)
    XCTAssertEqual(store.revision, revision)
    XCTAssertTrue(store.lastChangedIDs.isEmpty)
  }

  func testMalformedTreeAndUnknownOpcodeFailDuringDecode() {
    XCTAssertThrowsError(try ControlPatch.decode(payload: .map([
      "id": .int(1), "patch": .array([.string("not-a-tree")])
    ]))) { error in
      XCTAssertEqual(error as? ControlPatch.DecodingError, .malformedTreeIndex)
    }

    XCTAssertThrowsError(try ControlPatch.decode(payload: .map([
      "id": .int(1),
      "patch": .array([
        .array([.int(0)]),
        .array([.int(99), .int(0), .string("value"), .int(1)])
      ])
    ]))) { error in
      XCTAssertEqual(error as? ControlPatch.DecodingError, .unknownOperation(99))
    }
  }

  private func pageStore(
    controls: [RufletValue] = [],
    properties: [String: RufletValue] = [:]
  ) -> ControlStore {
    let store = ControlStore()
    var operations: [ControlPatch.Operation] = [
      .set(key: "_c", value: .string("Page"))
    ]
    if !controls.isEmpty {
      operations.append(.set(key: "controls", value: .array(controls)))
    }
    operations.append(contentsOf: properties.map { .set(key: $0.key, value: $0.value) })
    XCTAssertTrue(store.apply(ControlPatch(controlID: 1, operations: operations)))
    return store
  }

  private func text(_ id: Int, _ value: String) -> RufletValue {
    .map(["_i": .int(Int64(id)), "_c": .string("Text"), "value": .string(value)])
  }
}
