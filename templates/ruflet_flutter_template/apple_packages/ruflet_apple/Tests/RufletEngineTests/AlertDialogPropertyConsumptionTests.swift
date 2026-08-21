import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class AlertDialogPropertyConsumptionTests: XCTestCase {
  func testButtonsInsideIOSDialogsAlwaysUseAppleDialogActions() {
    XCTAssertTrue(rufletUsesAppleDialogAction(parentType: "AlertDialog", isIOS: true))
    XCTAssertTrue(rufletUsesAppleDialogAction(parentType: "CupertinoAlertDialog", isIOS: true))
    XCTAssertFalse(rufletUsesAppleDialogAction(parentType: "AlertDialog", isIOS: false))
    XCTAssertFalse(rufletUsesAppleDialogAction(parentType: "Column", isIOS: true))
  }

  func testNativeAlertConsumesProtocolTextActionsAndSemanticLabel() throws {
    let dialog = control(properties: [
      "title": .string("Session expired"),
      "content": .string("Sign in again."),
      "semantics_label": .string("Session expired dialog"),
      "actions": .array([
        controlValue(
          id: 2,
          type: "TextButton",
          properties: [
            "on_click": true,
            "content": controlValue(
              id: 3,
              type: "Text",
              properties: ["value": "Close"]),
          ])
      ]),
    ])

    let descriptor = try XCTUnwrap(rufletNativeAlertDescriptor(for: dialog))
    XCTAssertEqual(descriptor.title, "Session expired")
    XCTAssertEqual(descriptor.message, "Sign in again.")
    XCTAssertEqual(descriptor.semanticsLabel, "Session expired dialog")
    XCTAssertEqual(descriptor.actions.map(\.title), ["Close"])
    XCTAssertEqual(descriptor.actions.map(\.subscribed), [true])
  }

  func testPropertiesUnavailableInPublicAppleAlertAPIProduceProtocolErrors() {
    let properties = [
      "title_padding", "content_padding", "actions_padding", "actions_alignment",
      "shape", "inset_padding", "icon_padding", "bgcolor", "action_button_padding",
      "shadow_color", "elevation", "clip_behavior", "icon_color", "scrollable",
      "actions_overflow_button_spacing", "alignment", "content_text_style",
      "title_text_style", "barrier_color",
    ]

    for property in properties {
      let dialog = control(properties: [
        "content": .string("Message"),
        property: .string("explicit"),
      ])
      guard case .protocolError(let reason) = rufletNativeAlertResolution(for: dialog) else {
        return XCTFail("\(property) must fail loudly instead of selecting another renderer")
      }
      XCTAssertTrue(reason.contains(property))
    }
  }

  func testProtocolLayoutContentCanBecomeANativeAlertWithoutScreenRules() throws {
    let backend = AlertDialogTestBackend()
    let dialog = RufletControl(
      id: 1,
      type: "AlertDialog",
      properties: [
        "modal": true,
        "content": controlValue(
          id: 2,
          type: "Column",
          properties: [
            "controls": .array([
              controlValue(
                id: 3,
                type: "Text",
                properties: ["value": "Message from the wire"]),
              controlValue(
                id: 4,
                type: "TextButton",
                properties: [
                  "on_click": true,
                  "content": controlValue(
                    id: 5,
                    type: "Text",
                    properties: ["value": "Close"]),
                ]),
            ])
          ]),
      ],
      backend: backend)

    let descriptor = try XCTUnwrap(rufletNativeAlertDescriptor(for: dialog))
    XCTAssertNil(descriptor.title)
    XCTAssertEqual(descriptor.message, "Message from the wire")
    XCTAssertEqual(descriptor.actions.map(\.id), [4])
    XCTAssertEqual(descriptor.actions.map(\.title), ["Close"])
    XCTAssertEqual(descriptor.actions.map(\.subscribed), [true])
  }

  func testUnsupportedRichDialogContentProducesAnExplicitProtocolError() {
    let dialog = RufletControl(
      id: 1,
      type: "AlertDialog",
      properties: [
        "content": controlValue(
          id: 2,
          type: "Image",
          properties: ["src": "artwork.png"])
      ],
      backend: AlertDialogTestBackend())

    guard case .protocolError(let reason) = rufletNativeAlertResolution(for: dialog) else {
      return XCTFail("Rich content must not select an alternate visual renderer")
    }
    XCTAssertTrue(reason.contains("Image#2"))
    XCTAssertNil(rufletNativeAlertDescriptor(for: dialog))
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "AlertDialog",
      properties: properties,
      backend: AlertDialogTestBackend())
  }

  private func controlValue(
    id: Int,
    type: String,
    properties: [String: RufletValue]
  ) -> RufletValue {
    .map(
      properties.merging([
        "_c": .string(type),
        "_i": .int(Int64(id)),
      ]) { current, _ in current })
  }
}

@MainActor
private final class AlertDialogTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
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
