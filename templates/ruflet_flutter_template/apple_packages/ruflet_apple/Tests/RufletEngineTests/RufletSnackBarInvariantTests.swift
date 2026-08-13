import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class RufletSnackBarInvariantTests: XCTestCase {
  func testShowAndExternalCloseFollowPinnedDismissalOrder() {
    let backend = SnackBarTestBackend()
    let control = RufletControl(
      id: 1,
      type: "SnackBar",
      properties: [
        "open": true,
        "persist": true,
        "on_visible": true,
        "on_dismiss": true,
      ],
      backend: backend)
    let lifecycle = RufletSnackBarLifecycle(control: control)

    lifecycle.synchronize()
    XCTAssertEqual(
      backend.operations,
      [
        "update:_dismissed=false,_open=true,_show_generation=1:false",
        "event:visible",
      ])

    control.update(["open": false], notify: true)
    lifecycle.synchronize()

    XCTAssertEqual(
      backend.operations,
      [
        "update:_dismissed=false,_open=true,_show_generation=1:false",
        "event:visible",
        "update:_dismissed=true:false",
        "update:_open=false:false",
        "update:open=false:true",
        "event:dismiss",
      ])
  }

  func testActionAcceptsOnlyStringOrVisibleControl() {
    let backend = SnackBarTestBackend()
    let visibleAction: RufletValue = .map([
      "_c": "SnackBarAction",
      "_i": 2,
      "label": "Undo",
    ])
    let hiddenAction: RufletValue = .map([
      "_c": "SnackBarAction",
      "_i": 3,
      "label": "Hidden",
      "visible": false,
    ])

    let visible = RufletControl(
      id: 10, type: "SnackBar", properties: ["action": visibleAction], backend: backend)
    let hidden = RufletControl(
      id: 11, type: "SnackBar", properties: ["action": hiddenAction], backend: backend)
    let text = RufletControl(
      id: 12, type: "SnackBar", properties: ["action": "Retry"], backend: backend)
    let invalid = RufletControl(
      id: 13, type: "SnackBar", properties: ["action": 42], backend: backend)

    XCTAssertEqual(RufletSnackBarAction(control: visible).label, "Undo")
    XCTAssertEqual(RufletSnackBarAction(control: hidden), .none)
    XCTAssertEqual(RufletSnackBarAction(control: text), .text("Retry"))
    XCTAssertEqual(RufletSnackBarAction(control: invalid), .none)
  }
}

@MainActor
private final class SnackBarTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var operations: [String] = []
  private var controls: [Int: RufletControl] = [:]

  func index(_ control: RufletControl) { controls[control.id] = control }

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    operations.append("event:\(name)")
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    operations.append("event:\(name)")
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    controls[id]?.update(properties, notify: notify)
    let values = properties.sorted(by: { $0.key < $1.key }).map { key, value in
      "\(key)=\(wireString(value))"
    }.joined(separator: ",")
    operations.append("update:\(values):\(server)")
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}

  private func wireString(_ value: RufletValue) -> String {
    if let value = value.bool { return String(value) }
    if let value = value.integer { return String(value) }
    return "null"
  }
}
