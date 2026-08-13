import RufletEngine
import RufletProtocol
import XCTest
import Combine

final class OptimisticControlStoreParityTests: XCTestCase {
  private var cancellables: Set<AnyCancellable> = []

  override func tearDown() {
    cancellables.removeAll()
    super.tearDown()
  }

  func testPatchInvalidatesOnlyChangedControlAndItsAncestors() {
    let store = ControlStore()
    XCTAssertTrue(store.apply(ControlPatch(controlID: 1, operations: [
      .set(key: "_c", value: .string("Page")),
      .set(key: "controls", value: .array([
        .map(["_i": .int(100), "_c": .string("Column"), "controls": .array([
          .map(["_i": .int(101), "_c": .string("Text"), "value": .string("old")])
        ])]),
        .map(["_i": .int(200), "_c": .string("TextField"), "value": .string("")])
      ]))
    ])))

    var invalidated: Set<Int> = []
    for id in [1, 100, 101, 200] {
      store.observation(for: id).objectWillChange.sink { invalidated.insert(id) }
        .store(in: &cancellables)
    }

    XCTAssertTrue(store.apply(ControlPatch(controlID: 101, operations: [
      .set(key: "value", value: .string("new"))
    ])))
    XCTAssertEqual(invalidated, [1, 100, 101])
  }

  func testParentStateInvalidatesItsSubtreeButNotSiblingSubtrees() {
    let store = ControlStore()
    XCTAssertTrue(store.apply(ControlPatch(controlID: 1, operations: [
      .set(key: "_c", value: .string("Page")),
      .set(key: "controls", value: .array([
        .map(["_i": .int(100), "_c": .string("RadioGroup"), "value": .string("a"),
          "content": .map(["_i": .int(101), "_c": .string("Radio"), "value": .string("a")])]),
        .map(["_i": .int(200), "_c": .string("TextField"), "value": .string("")])
      ]))
    ])))

    var invalidated: Set<Int> = []
    for id in [1, 100, 101, 200] {
      store.observation(for: id).objectWillChange.sink { invalidated.insert(id) }
        .store(in: &cancellables)
    }

    store.setLocalProperty(100, key: "value", value: .string("b"))
    XCTAssertEqual(invalidated, [1, 100, 101])
  }

  func testStagedTextEditsDoNotInvalidateTheWholeControlTree() {
    let store = makeStore(value: "")
    let revision = store.revision

    store.stageLocalProperty(100, key: "value", value: .string("h"))
    store.stageLocalProperty(100, key: "value", value: .string("ho"))

    XCTAssertEqual(store.revision, revision)
    XCTAssertEqual(store.node(100)?.string("value"), "ho")

    XCTAssertFalse(applyValue("h", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "ho")
    XCTAssertFalse(applyValue("ho", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "ho")
  }

  func testExplicitRubyOverrideWinsOverStagedNativeText() {
    let store = makeStore(value: "old")
    store.stageLocalProperty(100, key: "value", value: .string("native"))

    XCTAssertTrue(applyValue("ruby", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "ruby")
  }

  func testDuplicateOldEchoDoesNotConsumeARepeatedLaterEdit() {
    let store = makeStore(value: "")
    for value in ["h", "ho", "hom", "home", "homes", "home"] {
      store.stageLocalProperty(100, key: "value", value: .string(value))
    }

    XCTAssertFalse(applyValue("home", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "home")
    // Duplicate acknowledgement for the earlier `home` must not jump over
    // `homes` and consume the final Backspace result.
    XCTAssertFalse(applyValue("home", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "home")
    XCTAssertFalse(applyValue("homes", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "home")
    XCTAssertFalse(applyValue("home", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "home")
  }

  func testDelayedTextEchoNeverPaintsOverANewerNativeEdit() {
    let store = makeStore(value: "")

    store.setLocalProperty(100, key: "value", value: .string("h"))
    store.setLocalProperty(100, key: "value", value: .string("ho"))
    store.setLocalProperty(100, key: "value", value: .string("hom"))

    XCTAssertFalse(applyValue("h", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "hom")
    XCTAssertFalse(applyValue("ho", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "hom")
    XCTAssertFalse(applyValue("hom", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "hom")
  }

  func testExplicitRubyOverrideWinsOverPendingNativeValue() {
    let store = makeStore(value: "old")
    store.setLocalProperty(100, key: "value", value: .string("native"))

    XCTAssertTrue(applyValue("ruby", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "ruby")
  }

  func testUnrelatedPatchDoesNotAcknowledgePendingValue() {
    let store = makeStore(value: "")
    store.setLocalProperty(100, key: "value", value: .string("new"))

    XCTAssertTrue(store.apply(ControlPatch(controlID: 100, operations: [
      .set(key: "hint_text", value: .string("Search"))
    ])))
    XCTAssertEqual(store.node(100)?.string("value"), "new")

    XCTAssertFalse(applyValue("new", to: store))
    XCTAssertEqual(store.node(100)?.string("value"), "new")
  }

  func testRepeatedBooleanEditsReconcileInOrder() {
    let store = makeStore(value: false, type: "Switch")
    store.setLocalProperty(100, key: "value", value: .bool(true))
    store.setLocalProperty(100, key: "value", value: .bool(false))
    store.setLocalProperty(100, key: "value", value: .bool(true))

    XCTAssertFalse(applyValue(true, to: store))
    XCTAssertEqual(store.node(100)?.bool("value"), true)
    XCTAssertFalse(applyValue(false, to: store))
    XCTAssertEqual(store.node(100)?.bool("value"), true)
    XCTAssertFalse(applyValue(true, to: store))
    XCTAssertEqual(store.node(100)?.bool("value"), true)
  }

  private func makeStore(value: String) -> ControlStore {
    makeStore(value: .string(value), type: "TextField")
  }

  private func makeStore(value: Bool, type: String) -> ControlStore {
    makeStore(value: .bool(value), type: type)
  }

  private func makeStore(value: RufletValue, type: String) -> ControlStore {
    let store = ControlStore()
    XCTAssertTrue(store.apply(ControlPatch(controlID: 100, operations: [
      .set(key: "_c", value: .string(type)),
      .set(key: "value", value: value),
    ])))
    return store
  }

  @discardableResult
  private func applyValue(_ value: String, to store: ControlStore) -> Bool {
    applyValue(.string(value), to: store)
  }

  @discardableResult
  private func applyValue(_ value: Bool, to store: ControlStore) -> Bool {
    applyValue(.bool(value), to: store)
  }

  @discardableResult
  private func applyValue(_ value: RufletValue, to store: ControlStore) -> Bool {
    store.apply(ControlPatch(controlID: 100, operations: [
      .set(key: "value", value: value)
    ]))
  }
}
