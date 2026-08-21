import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class SwitchPropertyConsumptionTests: XCTestCase {
  func testStandardSwitchResolvesPinnedDirectAndWidgetStateAppearance() {
    let fixture = makeControl(
      type: "Switch",
      properties: [
        "active_color": "red",
        "active_track_color": "green",
        "inactive_thumb_color": "grey",
        "inactive_track_color": "black",
        "thumb_color": ["selected": "purple", "default": "white"],
        "track_color": ["selected": "orange", "default": "blue"],
        "overlay_color": ["hovered": "yellow"],
        "track_outline_color": ["focused": "pink"],
        "track_outline_width": ["focused": 3.0, "default": 1.0],
        "focus_color": "cyan",
        "hover_color": "teal",
        "splash_radius": 19.0,
      ])
    let control = fixture.control
    let states: Set<RufletWidgetState> = [.selected, .focused, .hovered]
    let presentation = RufletStandardSwitchPresentation(control: control, states: states)

    XCTAssertNotNil(presentation.activeThumbColor)
    XCTAssertNotNil(presentation.activeTrackColor)
    XCTAssertNotNil(presentation.inactiveThumbColor)
    XCTAssertNotNil(presentation.inactiveTrackColor)
    XCTAssertNotNil(presentation.thumbColor)
    XCTAssertNotNil(presentation.trackColor)
    XCTAssertNotNil(presentation.overlayColor)
    XCTAssertNotNil(presentation.trackOutlineColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertNotNil(presentation.hoverColor)
    XCTAssertEqual(presentation.trackOutlineWidth, 3)
    XCTAssertEqual(presentation.splashRadius, 19)
  }

  func testCupertinoSwitchConsumesOnlyPinnedImageSourcesAndEmptyStateThumbColor() {
    let fixture = makeControl(
      type: "CupertinoSwitch",
      properties: [
        "active_track_color": "green",
        "inactive_track_color": "grey",
        "inactive_thumb_color": "black",
        "thumb_color": ["selected": "red", "default": "white"],
        "track_outline_color": ["selected": "blue"],
        "track_outline_width": ["selected": 2.5],
        "active_thumb_image_src": "data:image/png;base64,AA==",
        "inactive_thumb_image_src": "data:image/png;base64,AQ==",
        "focusColor": "orange",
        "on_label_color": "white",
        "off_label_color": "black",
      ])
    let control = fixture.control
    let selected: Set<RufletWidgetState> = [.selected, .focused]
    let presentation = RufletCupertinoSwitchPresentation(control: control, states: selected)

    XCTAssertNotNil(presentation.activeTrackColor)
    XCTAssertNotNil(presentation.inactiveTrackColor)
    XCTAssertNotNil(presentation.inactiveThumbColor)
    XCTAssertNotNil(presentation.thumbColor)
    XCTAssertNotNil(presentation.trackColor)
    XCTAssertNotNil(presentation.trackOutlineColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertNotNil(presentation.onLabelColor)
    XCTAssertNotNil(presentation.offLabelColor)
    XCTAssertEqual(presentation.trackOutlineWidth, 2.5)
    XCTAssertNotNil(presentation.activeThumbImageSource)
    XCTAssertNotNil(presentation.inactiveThumbImageSource)
    XCTAssertEqual(presentation.thumbImageSource, presentation.activeThumbImageSource)
  }

  func testPinnedChangePayloadDifferenceAndSingleMutationPathArePreserved() {
    let standardBackend = SwitchBackend()
    let standard = RufletControl(
      id: 2,
      type: "Switch",
      properties: ["value": false],
      backend: standardBackend)
    SwitchControl(control: standard).activate()

    XCTAssertEqual(standardBackend.updates.count, 1)
    XCTAssertEqual(standardBackend.updates[0].properties, ["value": true])
    XCTAssertTrue(standardBackend.updates[0].notify)
    XCTAssertEqual(standardBackend.events, [SwitchBackend.Event(name: "change", data: true)])

    let cupertinoBackend = SwitchBackend()
    let cupertino = RufletControl(
      id: 3,
      type: "CupertinoSwitch",
      properties: ["value": false],
      backend: cupertinoBackend)
    CupertinoSwitchControl(control: cupertino).activate()

    XCTAssertEqual(cupertinoBackend.updates.count, 1)
    XCTAssertEqual(cupertinoBackend.events, [SwitchBackend.Event(name: "change", data: .null)])
  }

  func testNativeSwitchLabelsShareTheGuardedSingleMutationPath() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let standard = try String(
      contentsOf: root.appendingPathComponent("Sources/RufletEngine/Controls/switch.swift"),
      encoding: .utf8)
    let cupertino = try String(
      contentsOf: root.appendingPathComponent(
        "Sources/RufletEngine/Controls/cupertino_switch.swift"),
      encoding: .utf8)

    XCTAssertTrue(standard.contains(".onTapGesture(perform: activate)"))
    XCTAssertTrue(cupertino.contains(".onTapGesture(perform: activate)"))
    XCTAssertEqual(
      standard.components(separatedBy: "control.updateProperties([\"value\"").count - 1, 1)
    XCTAssertEqual(
      cupertino.components(separatedBy: "control.updateProperties([\"value\"").count - 1, 1)
  }

  func testNativeSwitchPreservesNativeInteractionMotionAndAnimatesModelChanges() {
    XCTAssertEqual(
      rufletNativeSwitchValueUpdate(
        current: false,
        requested: false,
        hasAppliedInitialValue: false),
      .none)
    XCTAssertEqual(
      rufletNativeSwitchValueUpdate(
        current: false,
        requested: true,
        hasAppliedInitialValue: false),
      .immediate(true))
    XCTAssertEqual(
      rufletNativeSwitchValueUpdate(
        current: true,
        requested: false,
        hasAppliedInitialValue: true),
      .animated(false))
    XCTAssertEqual(
      rufletNativeSwitchValueUpdate(
        current: true,
        requested: true,
        hasAppliedInitialValue: true),
      .none)
  }

  func testNativeSwitchRefreshDoesNotForceUIKitRelayoutOrSnapValue() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let native = try String(
      contentsOf: root.appendingPathComponent("Sources/RufletEngine/Widgets/native_switch.swift"),
      encoding: .utf8)

    XCTAssertFalse(native.contains("control.setOn(value, animated: false)"))
    XCTAssertFalse(native.contains("control.setNeedsLayout()"))
    XCTAssertTrue(
      native.contains("case .animated(let next):")
        || native.contains("case let .animated(next):"))
    XCTAssertTrue(native.contains("control.setOn(next, animated: true)"))
    XCTAssertTrue(native.contains("DispatchQueue.main.async { [weak self] in"))
  }

  private func makeControl(
    type: String,
    properties: [String: RufletValue]
  ) -> (control: RufletControl, backend: SwitchBackend) {
    let backend = SwitchBackend()
    return (
      RufletControl(id: 1, type: type, properties: properties, backend: backend),
      backend
    )
  }
}

@MainActor
private final class SwitchBackend: RufletBackendProtocol {
  struct Update: Equatable {
    let properties: [String: RufletValue]
    let notify: Bool
  }

  struct Event: Equatable {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var updates: [Update] = []
  var events: [Event] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    updates.append(Update(properties: properties, notify: notify))
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
