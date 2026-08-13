import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

@MainActor
final class RadioPropertyConsumptionTests: XCTestCase {
  func testStandardRadioConsumesPinnedStateAppearanceAndInteractionProperties() {
    let control = makeControl(
      type: "Radio",
      properties: [
        "autofocus": true,
        "active_color": "red",
        "focus_color": "blue",
        "hover_color": "green",
        "fill_color": ["selected": "purple", "disabled": "grey"],
        "overlay_color": ["focused": "yellow", "pressed": "orange"],
        "splash_radius": 24.0,
        "visual_density": "compact",
        "mouse_cursor": "click",
        "label_position": "left",
        "label_style": ["size": 17.0, "weight": "w600"],
      ])

    let presentation = RufletRadioPresentation(control: control)
    let states = presentation.states(
      selected: true,
      focused: true,
      hovered: true,
      pressed: false,
      disabled: false)

    XCTAssertTrue(presentation.autofocus)
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertNotNil(presentation.hoverColor)
    XCTAssertEqual(presentation.splashRadius, 24)
    XCTAssertEqual(presentation.visualDensity, .compact)
    XCTAssertEqual(presentation.minimumInteractiveDimension, 40)
    XCTAssertEqual(presentation.mouseCursor, "click")
    XCTAssertEqual(presentation.labelPosition, .left)
    XCTAssertEqual(presentation.labelStyle?.size, 17)
    XCTAssertTrue(states.contains(.selected))
    XCTAssertTrue(states.contains(.focused))
    XCTAssertTrue(states.contains(.hovered))
    XCTAssertNotNil(presentation.fill(states))
    XCTAssertNotNil(presentation.overlay(states))
  }

  func testCupertinoRadioKeepsDirectInnerOuterAndFocusColorContract() {
    let control = makeControl(
      type: "CupertinoRadio",
      properties: [
        "autofocus": true,
        "use_checkmark_style": true,
        "fill_color": "white",
        "focus_color": "orange",
        "mouse_cursor": "click",
        "active_color": "blue",
        "inactive_color": "grey",
        "label_position": "left",
      ])

    let presentation = RufletCupertinoRadioPresentation(control: control)

    XCTAssertTrue(presentation.autofocus)
    XCTAssertTrue(presentation.useCheckmarkStyle)
    XCTAssertNotNil(presentation.fillColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.inactiveColor)
    XCTAssertEqual(presentation.mouseCursor, "click")
    XCTAssertEqual(presentation.labelPosition, .left)
  }

  func testRadioAndListTileSelectionTransitionsRemainDistinctAndSingleWrite() {
    var selection: String? = "two"
    var writes = 0
    let binding = Binding<String?>(
      get: { selection },
      set: {
        selection = $0
        writes += 1
      })

    rufletActivateRadio(
      selection: binding,
      selected: true,
      toggleable: true,
      value: "two")
    XCTAssertNil(selection)
    XCTAssertEqual(writes, 1)

    rufletSelectRadioFromListTile(selection: binding, value: "two")
    XCTAssertEqual(selection, "two")
    XCTAssertEqual(writes, 2)
  }

  private func makeControl(type: String, properties: [String: RufletValue]) -> RufletControl {
    RufletControl(id: 1, type: type, properties: properties, backend: RadioBackend())
  }
}

@MainActor
private final class RadioBackend: RufletBackendProtocol {
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
