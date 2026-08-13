import RufletProtocol
import SwiftUI
import XCTest
@testable import RufletEngine

@MainActor
final class DropdownPropertyConsumptionTests: XCTestCase {
  private let backend = DropdownTestBackend()

  func testDropdownPresentationConsumesPinnedMenuAndDensityFields() {
    let presentation = RufletDropdownPresentation(
      control: control(type: "Dropdown", properties: [
        "bgcolor": ["default": "#ff102030", "focused": "#ff405060"],
        "dense": true,
        "elevation": ["default": 3, "focused": 7],
        "menu_height": 240,
        "menu_style": [
          "padding": 6,
          "min_size": ["width": 120, "height": 44],
          "side": ["width": 2, "color": "#ffabcdef"],
        ],
        "menu_width": 280,
      ]),
      focused: true)

    XCTAssertTrue(presentation.dense)
    XCTAssertEqual(presentation.menuHeight, 240)
    XCTAssertEqual(presentation.menuWidth, 280)
    XCTAssertEqual(presentation.resolvedElevation, 7)
    XCTAssertEqual(presentation.resolvedPadding.top, 6)
    XCTAssertEqual(presentation.resolvedMinimumSize?.width, 120)
    XCTAssertEqual(presentation.resolvedMinimumSize?.height, 44)
    XCTAssertEqual(presentation.resolvedSide?.width, 2)
    XCTAssertNotNil(presentation.resolvedBackgroundColor)
  }

  func testDropdownM2PresentationConsumesPinnedDecorationAndMenuFields() {
    let presentation = RufletDropdownM2Presentation(
      control: control(type: "DropdownM2", properties: [
        "align_label_with_hint": true,
        "bgcolor": "#ff101112",
        "border": "underline",
        "collapsed": false,
        "counter": "{value_length}/{max_length}/{symbols_left}",
        "dense": true,
        "elevation": 11,
        "enable_feedback": false,
        "error_max_lines": 2,
        "fill_color": "#ff202122",
        "filled": true,
        "focus_color": "#ff303132",
        "focused_bgcolor": "#ff404142",
        "helper_max_lines": 3,
        "hint_fade_duration": ["milliseconds": 350],
        "hint_max_lines": 4,
        "hint_style": ["size": 15, "italic": true],
        "hover_color": "#ff505152",
        "max_menu_height": 260,
        "prefix_icon_constraints": ["min_width": 20, "max_height": 30],
        "size_constraints": ["min_width": 140, "max_width": 420, "min_height": 36],
        "suffix_icon_constraints": ["max_width": 24, "min_height": 18],
      ]),
      focused: true,
      hovered: false)

    XCTAssertTrue(presentation.alignLabelWithHint)
    XCTAssertEqual(presentation.border, .underline)
    XCTAssertFalse(presentation.collapsed)
    XCTAssertTrue(presentation.dense)
    XCTAssertEqual(presentation.elevation, 11)
    XCTAssertFalse(presentation.enableFeedback)
    XCTAssertEqual(presentation.errorMaxLines, 2)
    XCTAssertTrue(presentation.filled)
    XCTAssertNotNil(presentation.fillColor)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertNotNil(presentation.focusedBackgroundColor)
    XCTAssertEqual(presentation.helperMaxLines, 3)
    XCTAssertEqual(presentation.hintFadeDuration, 0.35, accuracy: 0.0001)
    XCTAssertEqual(presentation.hintMaxLines, 4)
    XCTAssertEqual(presentation.hintStyle?.size, 15)
    XCTAssertTrue(presentation.hintStyle?.italic == true)
    XCTAssertNotNil(presentation.hoverColor)
    XCTAssertEqual(presentation.maxMenuHeight, 260)
    XCTAssertEqual(presentation.prefixIconConstraints.minWidth, 20)
    XCTAssertEqual(presentation.prefixIconConstraints.maxHeight, 30)
    XCTAssertEqual(presentation.sizeConstraints.minWidth, 140)
    XCTAssertEqual(presentation.sizeConstraints.maxWidth, 420)
    XCTAssertEqual(presentation.sizeConstraints.minHeight, 36)
    XCTAssertEqual(presentation.suffixIconConstraints.maxWidth, 24)
    XCTAssertEqual(presentation.suffixIconConstraints.minHeight, 18)
    XCTAssertEqual(presentation.counterText, "null/None/None")
  }

  func testDropdownM2CollapsedAndDensePaddingMatchPinnedDecorationCompaction() {
    let collapsed = RufletDropdownM2Presentation(
      control: control(type: "DropdownM2", properties: ["collapsed": true]))
    XCTAssertEqual(collapsed.contentPadding.top, 0)
    XCTAssertEqual(collapsed.contentPadding.leading, 0)

    let dense = RufletDropdownM2Presentation(
      control: control(type: "DropdownM2", properties: ["dense": true]))
    XCTAssertEqual(dense.contentPadding.top, 4)
    XCTAssertEqual(dense.contentPadding.leading, 7)
    XCTAssertTrue(dense.enableFeedback)
  }

  private func control(type: String, properties: [String: RufletValue]) -> RufletControl {
    RufletControl(id: 1, type: type, properties: properties, backend: backend)
  }
}

@MainActor
private final class DropdownTestBackend: RufletBackendProtocol {
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
