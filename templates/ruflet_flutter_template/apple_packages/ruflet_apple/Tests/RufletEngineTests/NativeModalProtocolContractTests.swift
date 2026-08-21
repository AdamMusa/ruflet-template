import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class NativeModalProtocolContractTests: XCTestCase {
  func testProtocolDrivenSheetContentNeedsNoAlternateRenderer() {
    let sheet = control(properties: [
      "content": controlValue(
        id: 2,
        type: "Column",
        properties: [
          "controls": .array([
            controlValue(
              id: 3,
              type: "Text",
              properties: ["value": "Content from the wire"])
          ])
        ])
    ])

    XCTAssertNil(
      rufletNativeBottomSheetProtocolError(
        for: sheet,
        kind: .standard))
  }

  func testUnsupportedSheetChromeProducesAPropertySpecificProtocolError() {
    let unsupported: [(String, RufletValue)] = [
      ("barrier_color", "#55000000"),
      ("elevation", 8),
      ("animation_style", .map(["duration": 200])),
      ("clip_behavior", "hardEdge"),
    ]

    for (property, value) in unsupported {
      let sheet = control(properties: [
        "content": controlValue(
          id: 2,
          type: "Text",
          properties: ["value": "Content"]),
        property: value,
      ])
      let error = rufletNativeBottomSheetProtocolError(for: sheet, kind: .standard)
      XCTAssertTrue(error?.contains(property) == true, "\(property) must fail explicitly")
    }
  }

  func testMalformedNativeSheetValuesAreNotSilentlyIgnored() {
    let invalidColor = control(properties: [
      "content": controlValue(
        id: 2,
        type: "Text",
        properties: ["value": "Content"]),
      "bgcolor": "not-a-color",
    ])
    XCTAssertEqual(
      rufletNativeBottomSheetProtocolError(for: invalidColor, kind: .standard),
      "bgcolor is not a valid protocol color")

    let asymmetricShape = control(properties: [
      "content": controlValue(
        id: 3,
        type: "Text",
        properties: ["value": "Content"]),
      "shape": .map([
        "radius": .map([
          "top_left": 8,
          "top_right": 12,
          "bottom_left": 8,
          "bottom_right": 8,
        ])
      ]),
    ])
    XCTAssertEqual(
      rufletNativeBottomSheetProtocolError(for: asymmetricShape, kind: .standard),
      "shape.radius must be uniform for a native Apple sheet")
  }

  func testPickerBarrierOverrideFailsInsteadOfSelectingCustomDialogChrome() {
    for type in ["DatePicker", "TimePicker", "DateRangePicker"] {
      let picker = control(
        type: type,
        properties: ["barrier_color": "#55000000"])
      XCTAssertEqual(
        rufletNativePickerProtocolError(for: picker),
        "barrier_color cannot be applied by the public Apple sheet API")
    }
  }

  private func control(
    type: String = "BottomSheet",
    properties: [String: RufletValue]
  ) -> RufletControl {
    RufletControl(
      id: 1,
      type: type,
      properties: properties,
      backend: NativeModalTestBackend())
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
private final class NativeModalTestBackend: RufletBackendProtocol {
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
