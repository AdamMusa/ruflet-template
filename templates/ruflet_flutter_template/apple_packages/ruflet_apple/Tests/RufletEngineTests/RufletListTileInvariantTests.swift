import XCTest
import RufletProtocol
@testable import RufletEngine

@MainActor
final class RufletListTileInvariantTests: XCTestCase {
  func testToggleInputListenersRunInRegistrationOrder() {
    let notifier = RufletListTileClickNotifier()
    var calls: [Int] = []
    notifier.addListener { calls.append(1) }
    notifier.addListener { calls.append(2) }

    notifier.onClick()

    XCTAssertEqual(calls, [1, 2])
  }

  func testRemovedToggleInputListenerDoesNotRun() {
    let notifier = RufletListTileClickNotifier()
    var calls = 0
    let listenerID = notifier.addListener { calls += 1 }
    notifier.removeListener(listenerID)

    notifier.onClick()

    XCTAssertEqual(calls, 0)
  }

  func testActivationTogglesInputsBeforeClickEvent() {
    let backend = ListTileTestBackend()
    let control = RufletControl(
      id: 1,
      type: "ListTile",
      properties: ["toggle_inputs": true, "on_click": true],
      backend: backend)
    let notifier = RufletListTileClickNotifier()
    notifier.addListener { backend.operations.append("toggle") }

    RufletListTileActivation(control: control, clickNotifier: notifier)()

    XCTAssertEqual(backend.operations, ["toggle", "click"])
  }

  func testActivationConsumesPinnedFeedbackDefaultAndOverride() {
    let backend = ListTileTestBackend()
    let defaultControl = RufletControl(
      id: 3, type: "ListTile", properties: [:], backend: backend)
    let disabledFeedback = RufletControl(
      id: 4, type: "ListTile", properties: ["enable_feedback": false], backend: backend)

    XCTAssertTrue(RufletListTileActivation(
      control: defaultControl, clickNotifier: RufletListTileClickNotifier()).enableFeedback)
    XCTAssertFalse(RufletListTileActivation(
      control: disabledFeedback, clickNotifier: RufletListTileClickNotifier()).enableFeedback)
  }

  func testDisabledActivationDoesNotToggleOrClick() {
    let backend = ListTileTestBackend()
    let control = RufletControl(
      id: 2,
      type: "CupertinoListTile",
      properties: [
        "disabled": true,
        "toggle_inputs": true,
        "on_click": true,
      ],
      backend: backend)
    let notifier = RufletListTileClickNotifier()
    notifier.addListener { backend.operations.append("toggle") }

    let activation = RufletListTileActivation(control: control, clickNotifier: notifier)
    XCTAssertFalse(activation.isEnabled)
    activation()

    XCTAssertEqual(backend.operations, [])
  }
}

@MainActor
private final class ListTileTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var operations: [String] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    operations.append(name)
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    operations.append(name)
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
