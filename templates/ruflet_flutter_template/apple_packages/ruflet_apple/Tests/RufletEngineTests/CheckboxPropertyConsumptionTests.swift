import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class CheckboxPropertyConsumptionTests: XCTestCase {
  func testStandardCheckboxConsumesPinnedInteractiveAppearanceProperties() {
    let control = makeControl(
      type: "Checkbox",
      properties: [
        "autofocus": true,
        "active_color": "red",
        "check_color": "white",
        "focus_color": "blue",
        "hover_color": "green",
        "fill_color": ["selected": "purple", "disabled": "grey"],
        "overlay_color": ["focused": "yellow", "pressed": "orange"],
        "border_side": [
          "focused": ["width": 3.0, "color": "blue"],
          "default": ["width": 1.0, "color": "grey"],
        ],
        "shape": [
          "_type": "circle",
          "eccentricity": 0.25,
          "radius": 7.0,
          "side": ["width": 4.0, "color": "pink"],
        ],
        "splash_radius": 24.0,
        "visual_density": "compact",
        "mouse_cursor": "click",
        "label_position": "left",
        "label_style": ["size": 17.0, "weight": "w600"],
        "semantics_label": "Pinned checkbox",
        "error": true,
      ])

    let presentation = RufletCheckboxPresentation(control: control, kind: .standard)
    let focused = presentation.states(
      value: true,
      focused: true,
      hovered: false,
      pressed: false,
      disabled: false)

    XCTAssertTrue(presentation.autofocus)
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.directCheckColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertNotNil(presentation.hoverColor)
    XCTAssertEqual(presentation.kind, .standard)
    XCTAssertEqual(presentation.shape.kind, .circle)
    XCTAssertEqual(presentation.shape.eccentricity, 0.25)
    XCTAssertEqual(presentation.shape.radius.topLeft, 7)
    XCTAssertEqual(presentation.shape.side?.width, 4)
    XCTAssertEqual(presentation.splashRadius, 24)
    XCTAssertEqual(presentation.visualDensity, .compact)
    XCTAssertEqual(presentation.tapTargetSize, 40)
    XCTAssertEqual(presentation.mouseCursor, "click")
    XCTAssertEqual(presentation.labelPosition, .left)
    XCTAssertEqual(presentation.labelStyle?.size, 17)
    XCTAssertEqual(presentation.semanticsLabel, "Pinned checkbox")
    XCTAssertTrue(focused.contains(.selected))
    XCTAssertTrue(focused.contains(.focused))
    XCTAssertTrue(focused.contains(.error))
    XCTAssertEqual(presentation.borderSide(focused).width, 3)
    XCTAssertNotNil(presentation.fill(focused))
    XCTAssertNotNil(presentation.overlay(focused))
  }

  func testCupertinoCheckboxConsumesPinnedSpacingAndSharedAppearance() {
    let control = makeControl(
      type: "CupertinoCheckbox",
      properties: [
        "autofocus": true,
        "active_color": "green",
        "check_color": "black",
        "focus_color": "blue",
        "fill_color": ["selected": "orange"],
        "border_side": ["width": 2.5, "color": "purple"],
        "shape": ["_type": "stadium"],
        "mouse_cursor": "click",
        "semantics_label": "Cupertino selection",
        "spacing": 13.0,
      ])

    let presentation = RufletCheckboxPresentation(control: control, kind: .cupertino)
    let selected = presentation.states(
      value: true,
      focused: false,
      hovered: false,
      pressed: false,
      disabled: false)

    XCTAssertTrue(presentation.autofocus)
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.directCheckColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertEqual(presentation.kind, .cupertino)
    XCTAssertEqual(presentation.spacing, 13)
    XCTAssertEqual(presentation.tapTargetSize, 20)
    XCTAssertEqual(presentation.shape.kind, .stadium)
    XCTAssertEqual(presentation.mouseCursor, "click")
    XCTAssertEqual(presentation.semanticsLabel, "Cupertino selection")
    XCTAssertEqual(presentation.borderSide(selected).width, 2.5)
    XCTAssertNotNil(presentation.fill(selected))
  }

  func testStandardCheckboxKeepsFlutterMaterialTapTargetAroundItsLabel() {
    let standard = RufletCheckboxPresentation(
      control: makeControl(type: "Checkbox", properties: [:]),
      kind: .standard)
    let comfortable = RufletCheckboxPresentation(
      control: makeControl(type: "Checkbox", properties: ["visual_density": "comfortable"]),
      kind: .standard)

    XCTAssertEqual(standard.controlSize, 18)
    XCTAssertEqual(standard.tapTargetSize, 48)
    XCTAssertEqual(comfortable.tapTargetSize, 44)
  }

  func testPinnedValueAndActivationContractsRemainExact() {
    let backend = CheckboxBackend()
    let control = RufletControl(
      id: 2,
      type: "CupertinoCheckbox",
      properties: ["value": .null, "tristate": true],
      backend: backend)

    XCTAssertNil(rufletCheckboxValue(control: control))
    rufletActivateCheckbox(control: control, current: nil, tristate: true)

    XCTAssertEqual(backend.updates.count, 1)
    XCTAssertEqual(backend.updates[0].properties, ["value": false])
    XCTAssertTrue(backend.updates[0].notify)
    XCTAssertEqual(backend.events.count, 1)
    XCTAssertEqual(backend.events[0].name, "change")
    XCTAssertEqual(backend.events[0].data, false)
  }

  private func makeControl(type: String, properties: [String: RufletValue]) -> RufletControl {
    RufletControl(id: 1, type: type, properties: properties, backend: CheckboxBackend())
  }
}

@MainActor
private final class CheckboxBackend: RufletBackendProtocol {
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
