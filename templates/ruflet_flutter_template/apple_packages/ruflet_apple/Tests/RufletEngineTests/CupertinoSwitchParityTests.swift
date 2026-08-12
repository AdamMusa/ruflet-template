import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CupertinoSwitchParityTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "CupertinoSwitch", props: props)
  }

  func testPinnedFletDefaultsAndLabelPlacement() {
    let defaults = CupertinoSwitchPresentation(node: node())
    XCTAssertFalse(defaults.value)
    XCTAssertFalse(defaults.disabled)
    XCTAssertFalse(defaults.autofocus)
    XCTAssertNil(defaults.label)
    XCTAssertEqual(defaults.labelPosition, .right)
    XCTAssertEqual(defaults.thumbColorToken, "white")

    let explicit = CupertinoSwitchPresentation(node: node([
      "value": .bool(true),
      "autofocus": .bool(true),
      "label": .string("Airplane mode"),
      "label_position": .string("left"),
    ]))
    XCTAssertTrue(explicit.value)
    XCTAssertTrue(explicit.autofocus)
    XCTAssertEqual(explicit.label, "Airplane mode")
    XCTAssertEqual(explicit.labelPosition, .left)
  }

  func testTrackAndThumbColorsFollowCurrentValue() {
    let control = node([
      "active_track_color": .string("green"),
      "inactive_track_color": .string("grey"),
      "thumb_color": .string("white"),
      "inactive_thumb_color": .string("black"),
      "on_label_color": .string("blue"),
      "off_label_color": .string("orange"),
    ])
    let on = CupertinoSwitchPresentation(node: control, value: true)
    let off = CupertinoSwitchPresentation(node: control, value: false)

    XCTAssertEqual(on.trackColorToken, "green")
    XCTAssertEqual(off.trackColorToken, "grey")
    XCTAssertEqual(on.thumbColorToken, "white")
    XCTAssertEqual(off.thumbColorToken, "black")
    XCTAssertEqual(on.onLabelColorToken, "blue")
    XCTAssertEqual(off.offLabelColorToken, "orange")
    XCTAssertNotNil(on.activeLabelColor)
    XCTAssertNotNil(off.activeLabelColor)
  }

  func testOutlineAndThumbIconResolveWidgetStates() {
    let control = node([
      "track_outline_color": .map([
        "selected": .string("green"),
        "focused": .string("blue"),
        "default": .string("grey"),
      ]),
      "track_outline_width": .map([
        "disabled": .double(4),
        "selected": .double(3),
        "default": .double(1),
      ]),
      "thumb_icon": .map([
        "selected": .string("check"),
        "default": .string("close"),
      ]),
    ])

    let selected = CupertinoSwitchPresentation(node: control, value: true)
    XCTAssertTrue(selected.states.contains(.selected))
    XCTAssertEqual(selected.trackOutlineColorToken, "green")
    XCTAssertEqual(selected.trackOutlineWidth, 3)
    XCTAssertEqual(selected.thumbIcon, .string("check"))

    let focused = CupertinoSwitchPresentation(
      node: control, value: false, focused: true)
    XCTAssertTrue(focused.states.contains(.focused))
    XCTAssertEqual(focused.trackOutlineColorToken, "blue")
    XCTAssertEqual(focused.trackOutlineWidth, 1)
    XCTAssertEqual(focused.thumbIcon, .string("close"))

    let disabled = CupertinoSwitchPresentation(node: node([
      "disabled": .bool(true),
      "value": .bool(true),
      "track_outline_width": .map([
        "disabled": .double(4), "selected": .double(3),
      ]),
    ]))
    XCTAssertTrue(disabled.states.contains(.disabled))
    XCTAssertEqual(disabled.trackOutlineWidth, 4)
  }

  func testFocusColorAcceptsCurrentAndHistoricalWireSpellings() {
    XCTAssertEqual(
      CupertinoSwitchPresentation(node: node(["focus_color": .string("blue")]))
        .focusColorToken,
      "blue")
    XCTAssertEqual(
      CupertinoSwitchPresentation(node: node(["focusColor": .string("orange")]))
        .focusColorToken,
      "orange")
  }

  func testActiveAndInactiveThumbImagesSelectWithoutLosingBinaryData() {
    let bytes: RufletValue = .binary([0x89, 0x50, 0x4E, 0x47])
    let control = node([
      "active_thumb_image_src": bytes,
      "inactive_thumb_image_src": .string("https://example.com/off.png"),
    ])

    XCTAssertEqual(
      CupertinoSwitchPresentation(node: control, value: true).thumbImageSource,
      .binary(Data([0x89, 0x50, 0x4E, 0x47])))
    XCTAssertEqual(
      CupertinoSwitchPresentation(node: control, value: false).thumbImageSource,
      .remote(URL(string: "https://example.com/off.png")!))
  }

  func testLegacyImageAliasesRemainConsumable() {
    let control = node([
      "active_thumb_image": .string("on.png"),
      "inactive_thumb_image": .string("off.png"),
    ])
    XCTAssertEqual(
      CupertinoSwitchPresentation(node: control, value: true).thumbImageSource,
      .asset("on.png"))
    XCTAssertEqual(
      CupertinoSwitchPresentation(node: control, value: false).thumbImageSource,
      .asset("off.png"))
  }

  func testChangeUpdatesValueBeforeSendingDataLessEvent() {
    var operations: [String] = []
    let control = node(["on_change": .bool(true)])
    let sink = RufletEventSink(
      send: { _, name, data in operations.append("event:\(name):\(data)") },
      setLocal: { _, key, value in operations.append("local:\(key):\(value)") },
      update: { _, props in operations.append("update:\(props["value"]!)") })

    RufletValueControlEvents.commit(
      control, value: .bool(true), payload: .none, to: sink)

    XCTAssertEqual(
      operations,
      ["local:value:true", "update:true", "event:change:null"])
  }

  func testRegistryAdvertisesEveryFletSwitchEventAndNoMethods() {
    let descriptor = ControlRegistry.descriptor(for: "CupertinoSwitch")
    XCTAssertEqual(
      descriptor?.supportedEvents,
      ["blur", "change", "focus", "image_error"])
    XCTAssertEqual(descriptor?.supportedMethods, [])
  }
}
