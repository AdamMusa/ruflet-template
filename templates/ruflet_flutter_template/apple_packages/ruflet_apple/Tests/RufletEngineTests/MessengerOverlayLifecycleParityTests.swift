import XCTest
import RufletEngine
import RufletProtocol
@testable import RufletUI

final class MessengerOverlayLifecycleParityTests: XCTestCase {
  func testNativeSnackBarDismissMatchesPinnedFletStateAndEventOrder() {
    let node = ControlNode(
      id: 1, type: "SnackBar", props: ["on_dismiss": .bool(true)])
    var operations: [String] = []
    let sink = RufletEventSink(
      send: { _, event, payload in
        operations.append("event:\(event):\(payload == .null)")
      },
      setLocal: { _, key, value in
        let rendered = value == .bool(true) ? "true" : "false"
        operations.append("local:\(key):\(rendered)")
      },
      update: { _, values in
        if values["_dismissed"] == .bool(true) {
          operations.append("update:_dismissed:true")
        } else if values["open"] == .bool(false) {
          operations.append("update:open:false")
        }
      })

    RufletOverlaySemantics.dismissMessengerOverlay(node, through: sink)

    XCTAssertEqual(operations, [
      "local:_dismissed:true",
      "update:_dismissed:true",
      "local:_open:false",
      "local:open:false",
      "update:open:false",
      "event:dismiss:true",
    ])
  }

  func testDismissEventRemainsGatedByAttachedHandler() {
    let node = ControlNode(id: 2, type: "SnackBar")
    var sentEvents: [String] = []
    var updated: [[String: RufletValue]] = []
    let sink = RufletEventSink(
      send: { _, name, _ in sentEvents.append(name) },
      update: { _, values in updated.append(values) })

    RufletOverlaySemantics.dismissMessengerOverlay(node, through: sink)

    XCTAssertTrue(sentEvents.isEmpty)
    XCTAssertEqual(updated, [
      ["_dismissed": .bool(true)],
      ["open": .bool(false)],
    ])
  }

  func testOrdinaryDialogDismissDoesNotInventMessengerDismissedState() {
    let node = ControlNode(
      id: 3, type: "AlertDialog", props: ["on_dismiss": .bool(true)])
    var localKeys: [String] = []
    let sink = RufletEventSink(
      setLocal: { _, key, _ in localKeys.append(key) })

    RufletOverlaySemantics.dismiss(node, through: sink)

    XCTAssertEqual(localKeys, ["open"])
  }
}
