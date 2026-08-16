import RufletProtocol
import SwiftUI
import XCTest
@testable import RufletEngine

@MainActor
final class IconButtonPropertyConsumptionTests: XCTestCase {
  func testAllPinnedVariantsAndInteractivePropertiesAreParsed() throws {
    let backend = IconButtonBackend()
    let properties: [String: RufletValue] = [
      "adaptive": true,
      "selected": true,
      "icon_color": "red",
      "selected_icon_color": "green",
      "disabled_color": "gray",
      "highlight_color": "yellow",
      "hover_color": "blue",
      "splash_color": "purple",
      "focus_color": "orange",
      "icon_size": 31,
      "splash_radius": 27,
      "padding": 12,
      "alignment": ["x": 1, "y": -1],
      "mouse_cursor": "click",
      "size_constraints": [
        "min_width": 48, "max_width": 80, "min_height": 46, "max_height": 78,
      ],
      "enable_feedback": false,
      "style": [
        "animation_duration": 220,
        "visual_density": "compact",
        "enable_feedback": true,
        "fixed_size": ["width": 50, "height": 52],
        "minimum_size": ["width": 40, "height": 42],
        "maximum_size": ["width": 70, "height": 72],
        "alignment": ["x": -1, "y": 1],
        "mouse_cursor": ["hovered": "grab", "default": "click"],
        "icon_size": ["selected": 34, "default": 30],
        "padding": ["pressed": 6, "default": 9],
        "elevation": ["focused": 5, "default": 1],
        "shape": [
          "_type": "roundedRectangle",
          "radius": 11,
          "side": ["width": 2, "color": "cyan"],
        ],
      ],
    ]

    for type in ["IconButton", "FilledIconButton", "FilledTonalIconButton", "OutlinedIconButton"] {
      let control = RufletControl(id: type.hashValue, type: type, properties: properties, backend: backend)
      let presentation = RufletIconButtonPresentation(control: control)
      let states = presentation.states(focused: true, hovered: false, pressed: false, disabled: false)

      XCTAssertTrue(presentation.adaptive, type)
      XCTAssertTrue(presentation.selected, type)
      XCTAssertFalse(presentation.enableFeedback, type)
      XCTAssertEqual(presentation.iconSize, 31, type)
      XCTAssertEqual(presentation.splashRadius, 27, type)
      XCTAssertEqual(presentation.sizeConstraints.minWidth, 48, type)
      XCTAssertEqual(presentation.sizeConstraints.maxHeight, 78, type)
      XCTAssertEqual(presentation.styleIconSize.resolve(states), 34.0, type)
      XCTAssertEqual(presentation.styleElevation.resolve(states), 5.0, type)
      XCTAssertEqual(presentation.animationDuration, 0.22, accuracy: 0.0001, type)
      XCTAssertEqual(presentation.resolvedShape(states).kind, .roundedRectangle, type)
      XCTAssertEqual(presentation.resolvedShape(states).radius.uniform, 11, type)
      XCTAssertEqual(presentation.styleFixedSize.resolve(states), CGSize(width: 50, height: 52), type)
      XCTAssertEqual(presentation.styleMinimumSize.resolve(states), CGSize(width: 40, height: 42), type)
      XCTAssertEqual(presentation.styleMaximumSize.resolve(states), CGSize(width: 70, height: 72), type)
      XCTAssertEqual(presentation.styleMouseCursor(focused: false, hovered: true, disabled: false), "grab", type)
      XCTAssertEqual(presentation.densityMinimum, 44, "adaptive Apple button keeps native hit target")
    }

    XCTAssertEqual(RufletIconButtonVariant("IconButton"), .plain)
    XCTAssertEqual(RufletIconButtonVariant("FilledIconButton"), .filled)
    XCTAssertEqual(RufletIconButtonVariant("FilledTonalIconButton"), .tonal)
    XCTAssertEqual(RufletIconButtonVariant("OutlinedIconButton"), .outlined)
  }

  func testSelectedAndDisabledStatesResolvePinnedDirectAndStylePrecedence() {
    let backend = IconButtonBackend()
    let control = RufletControl(
      id: 2,
      type: "FilledIconButton",
      properties: [
        "selected": true,
        "icon_color": "red",
        "selected_icon_color": "green",
        "disabled_color": "gray",
        "style": [
          "icon_color": ["disabled": "black", "selected": "blue", "default": "white"],
          "bgcolor": ["selected": "yellow", "default": "purple"],
          "overlay_color": ["pressed": "orange", "hovered": "cyan"],
        ],
      ],
      backend: backend)
    let presentation = RufletIconButtonPresentation(control: control)
    let selected = presentation.states(focused: false, hovered: false, pressed: false, disabled: false)
    let disabled = presentation.states(focused: false, hovered: false, pressed: false, disabled: true)

    XCTAssertNotNil(presentation.foreground(selected))
    XCTAssertNotNil(presentation.background(selected))
    XCTAssertNotNil(presentation.foreground(disabled))
    XCTAssertTrue(selected.contains(.selected))
    XCTAssertTrue(disabled.contains(.disabled))
    XCTAssertEqual(presentation.resolvedIconSize(selected), 24)
  }

  func testActivationHasExactlyOneClickPathAndDisabledActivationIsSilent() {
    let backend = IconButtonBackend()
    let enabled = RufletControl(
      id: 3,
      type: "IconButton",
      properties: ["on_click": true],
      backend: backend)
    let disabled = RufletControl(
      id: 4,
      type: "IconButton",
      properties: ["disabled": true, "on_click": true],
      backend: backend)

    rufletActivateIconButton(enabled)
    rufletActivateIconButton(disabled)

    XCTAssertEqual(backend.events.count, 1)
    XCTAssertEqual(backend.events.first?.controlID, enabled.id)
    XCTAssertEqual(backend.events.first?.name, "click")
  }

  func testAppBarLeadingIconButtonClaimsTheCompleteNavigationHitSlot() throws {
    let backend = IconButtonBackend()
    let appBar = RufletControl(
      id: 10,
      type: "AppBar",
      properties: [
        "leading_width": .double(60),
        "toolbar_height": .double(52),
        "leading": .map([
          "_i": .int(11),
          "_c": .string("IconButton"),
          "icon": .int(65_898),
          "on_click": .bool(true),
        ]),
      ],
      backend: backend)
    let leading = try XCTUnwrap(appBar.child("leading"))

    XCTAssertEqual(
      RufletIconButtonPresentation(control: leading).appBarLeadingMinimumSize,
      CGSize(width: 60, height: 52))
    XCTAssertFalse(rufletButtonLongPressEnabled(leading))
  }
}

@MainActor
private final class IconButtonBackend: RufletBackendProtocol {
  struct Event: Equatable {
    let controlID: Int
    let name: String
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var events: [Event] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(controlID: control.id, name: name))
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(controlID: controlID, name: name))
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
