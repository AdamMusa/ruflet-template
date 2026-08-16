import XCTest
@testable import RufletProtocol

final class ProtocolBodyTests: XCTestCase {
  func testMessageActionsMatchPinnedFletWireValues() {
    XCTAssertEqual(RufletMessageAction.registerClient.rawValue, 1)
    XCTAssertEqual(RufletMessageAction.patchControl.rawValue, 2)
    XCTAssertEqual(RufletMessageAction.controlEvent.rawValue, 3)
    XCTAssertEqual(RufletMessageAction.updateControl.rawValue, 4)
    XCTAssertEqual(RufletMessageAction.invokeControlMethod.rawValue, 5)
    XCTAssertEqual(RufletMessageAction.sessionCrashed.rawValue, 6)
  }

  func testMessageRoundTripUsesTwoElementList() throws {
    let original = RufletMessage(
      action: .controlEvent,
      payload: ["target": 42, "name": "click", "data": "payload"])

    XCTAssertEqual(
      original.list,
      [.int(3), ["target": 42, "name": "click", "data": "payload"]])
    XCTAssertEqual(try RufletMessage(list: original.list), original)
    XCTAssertEqual(
      try RufletMessage(list: original.list + ["ignored-by-pinned-flet"]),
      original)
    XCTAssertThrowsError(try RufletMessage(list: [.int(3)]))
    XCTAssertThrowsError(try RufletMessage(list: [.int(99), .null]))
  }

  func testControlEventBodyUsesPinnedKeys() {
    let body = RufletControlEventBody(target: 7, name: "change", data: true)
    XCTAssertEqual(
      body.value,
      ["target": 7, "name": "change", "data": true])
  }

  func testUpdateControlBodyUsesPinnedKeys() {
    let body = RufletUpdateControlBody(
      id: 11,
      properties: ["value": "Ruby", "disabled": false])
    XCTAssertEqual(
      body.value,
      ["id": 11, "props": ["value": "Ruby", "disabled": false]])
  }

  func testRegisterClientRequestUsesPinnedSnakeCaseKeys() {
    let body = RufletRegisterClientRequestBody(
      sessionID: "session-1",
      pageName: "p/demo",
      page: ["id": 1])
    XCTAssertEqual(
      body.value,
      [
        "session_id": "session-1",
        "page_name": "p/demo",
        "page": ["id": 1],
      ])
  }

  func testRegisterClientRequestEncodesMissingSessionAsNull() {
    let body = RufletRegisterClientRequestBody(
      sessionID: nil,
      pageName: "",
      page: [:])
    XCTAssertEqual(body.value["session_id"], .null)
  }

  func testRegisterClientResponseParsesPinnedFields() throws {
    let body = try RufletRegisterClientResponseBody(
      value: [
        "session_id": "session-2",
        "page_patch": ["id": 1, "type": "Page"],
        "error": nil,
      ])
    XCTAssertEqual(body.sessionID, "session-2")
    XCTAssertEqual(body.pagePatch, ["id": 1, "type": "Page"])
    XCTAssertNil(body.error)
    XCTAssertThrowsError(try RufletRegisterClientResponseBody(
      value: ["session_id": 7, "page_patch": [:], "error": nil])) {
      XCTAssertEqual($0 as? RufletProtocolError, .invalidField("session_id"))
    }
    XCTAssertThrowsError(try RufletRegisterClientResponseBody(
      value: ["session_id": nil, "page_patch": [:], "error": false])) {
      XCTAssertEqual($0 as? RufletProtocolError, .invalidField("error"))
    }
  }

  func testPatchControlRequestRequiresIDAndPatch() throws {
    let body = try RufletPatchControlRequestBody(
      value: [
        "id": 9,
        "patch": [
          ["op": "replace", "path": "/value", "value": "Swift"],
        ],
      ])
    XCTAssertEqual(body.id, 9)
    XCTAssertEqual(body.patch.count, 1)
    XCTAssertThrowsError(try RufletPatchControlRequestBody(value: ["id": 9]))
  }

  func testInvokeMethodRequestDefaultsTimeoutToTenSeconds() throws {
    let body = try RufletInvokeMethodRequestBody(
      value: [
        "control_id": 3,
        "call_id": "call-1",
        "name": "focus",
        "args": ["select_all": true],
      ])
    XCTAssertEqual(body.controlID, 3)
    XCTAssertEqual(body.callID, "call-1")
    XCTAssertEqual(body.name, "focus")
    XCTAssertEqual(body.arguments, ["select_all": true])
    let timeout: TimeInterval = body.timeoutSeconds
    XCTAssertEqual(timeout, 10)
    XCTAssertEqual(body.timeoutNanoseconds, 10_000_000_000)
    XCTAssertThrowsError(try RufletInvokeMethodRequestBody(
      value: [
        "control_id": 3,
        "call_id": "call-1",
        "name": "focus",
        "args": nil,
        "timeout": nil,
      ])) {
      XCTAssertEqual($0 as? RufletProtocolError, .invalidField("timeout"))
    }
  }

  func testInvokeMethodResponseUsesPinnedKeysAndNullError() {
    let body = RufletInvokeMethodResponseBody(
      controlID: 4,
      callID: "call-2",
      result: ["value": "ok"])
    XCTAssertEqual(
      body.value,
      [
        "control_id": 4,
        "call_id": "call-2",
        "result": ["value": "ok"],
        "error": nil,
      ])
  }

  func testSessionCrashRequiresMessage() throws {
    XCTAssertEqual(
      try RufletSessionCrashedBody(value: ["message": "boom"]).message,
      "boom")
    XCTAssertThrowsError(try RufletSessionCrashedBody(value: [:]))
  }

  func testPageMediaDataUsesPinnedKeysAndOrientationNames() {
    let body = RufletPageMediaData(
      padding: .init(top: 1, right: 2, bottom: 3, left: 4),
      viewPadding: .zero,
      viewInsets: .init(top: 0, right: 0, bottom: 320, left: 0),
      devicePixelRatio: 3,
      orientation: .portrait,
      alwaysUse24HourFormat: false)

    XCTAssertEqual(body.value["padding"], ["top": 1.0, "right": 2.0, "bottom": 3.0, "left": 4.0])
    XCTAssertEqual(body.value["view_padding"], ["top": 0.0, "right": 0.0, "bottom": 0.0, "left": 0.0])
    XCTAssertEqual(body.value["view_insets"], ["top": 0.0, "right": 0.0, "bottom": 320.0, "left": 0.0])
    XCTAssertEqual(body.value["device_pixel_ratio"], 3.0)
    XCTAssertEqual(body.value["orientation"], "portrait")
    XCTAssertEqual(body.value["always_use_24_hour_format"], false)
  }
}
