import RufletProtocol
import SwiftUI
import XCTest
@testable import RufletEngine

@MainActor
final class TextFieldPropertyConsumptionTests: XCTestCase {
  private let backend = TextFieldTestBackend()

  func testFormPresentationConsumesPinnedInputDecorationAndCursorFields() {
    let presentation = RufletTextFieldPresentation(
      control: control(type: "TextField", properties: [
        "align_label_with_hint": true,
        "animate_cursor_opacity": false,
        "clip_behavior": "none",
        "collapsed": false,
        "content_padding": ["top": 1, "left": 2, "bottom": 3, "right": 4],
        "cursor_error_color": "#ff010203",
        "cursor_height": 19,
        "cursor_radius": 4,
        "cursor_width": 3,
        "dense": true,
        "enable_stylus_handwriting": false,
        "error": "invalid",
        "error_max_lines": 2,
        "filled": true,
        "focus_color": "#ff112233",
        "helper_max_lines": 3,
        "hint_fade_duration": ["milliseconds": 350],
        "hint_max_lines": 4,
        "hint_style": ["size": 15, "italic": true],
        "hover_color": "#ff445566",
        "mouse_cursor": "text",
        "prefix_icon_size_constraints": ["min_width": 20, "max_height": 30],
        "scroll_padding": ["top": 5, "left": 6, "bottom": 7, "right": 8],
        "size_constraints": ["min_width": 120, "max_width": 420, "min_height": 32],
        "strut_style": ["size": 10, "height": 1.5, "leading": 2, "force_strut_height": true],
        "suffix_icon_size_constraints": ["max_width": 22, "min_height": 18],
        "text_vertical_align": -1,
      ]),
      style: .form)

    XCTAssertTrue(presentation.alignLabelWithHint)
    XCTAssertFalse(presentation.animateCursorOpacity)
    XCTAssertEqual(presentation.clipBehavior, "none")
    XCTAssertEqual(presentation.contentPadding.top, 1)
    XCTAssertEqual(presentation.contentPadding.leading, 2)
    XCTAssertEqual(presentation.contentPadding.bottom, 3)
    XCTAssertEqual(presentation.contentPadding.trailing, 4)
    XCTAssertEqual(presentation.cursorHeight, 19)
    XCTAssertEqual(presentation.cursorWidth, 3)
    XCTAssertEqual(presentation.cursorRadius, 4)
    XCTAssertFalse(presentation.enableStylusHandwriting)
    XCTAssertEqual(presentation.errorMaxLines, 2)
    XCTAssertTrue(presentation.filled)
    XCTAssertNotNil(presentation.focusColor)
    XCTAssertEqual(presentation.helperMaxLines, 3)
    XCTAssertEqual(presentation.hintFadeDuration, 0.35, accuracy: 0.0001)
    XCTAssertEqual(presentation.hintMaxLines, 4)
    XCTAssertEqual(presentation.placeholderStyle?.size, 15)
    XCTAssertTrue(presentation.placeholderStyle?.italic == true)
    XCTAssertNotNil(presentation.hoverColor)
    XCTAssertEqual(presentation.mouseCursor, "text")
    XCTAssertEqual(presentation.prefixIconConstraints.minWidth, 20)
    XCTAssertEqual(presentation.prefixIconConstraints.maxHeight, 30)
    XCTAssertEqual(presentation.scrollPadding.top, 5)
    XCTAssertEqual(presentation.scrollPadding.trailing, 8)
    XCTAssertEqual(presentation.sizeConstraints.minWidth, 120)
    XCTAssertEqual(presentation.sizeConstraints.maxWidth, 420)
    XCTAssertEqual(presentation.sizeConstraints.minHeight, 32)
    XCTAssertEqual(presentation.strutStyle?.lineHeight, 17)
    XCTAssertEqual(presentation.suffixIconConstraints.maxWidth, 22)
    XCTAssertEqual(presentation.suffixIconConstraints.minHeight, 18)
    XCTAssertEqual(presentation.textVerticalAlignment, .top)
    XCTAssertTrue(presentation.hasError)
  }

  func testCollapsedAndDenseDefaultsMatchPinnedDecorationCompaction() {
    let collapsed = RufletTextFieldPresentation(
      control: control(type: "TextField", properties: ["collapsed": true]), style: .form)
    XCTAssertEqual(collapsed.contentPadding.top, 0)
    XCTAssertEqual(collapsed.contentPadding.leading, 0)

    let dense = RufletTextFieldPresentation(
      control: control(type: "TextField", properties: ["dense": true]), style: .form)
    XCTAssertEqual(dense.contentPadding.top, 4)
    XCTAssertEqual(dense.contentPadding.leading, 7)
  }

  func testAdaptiveTextFieldSelectsCupertinoOnlyWhenPinnedFlagIsTrue() {
    let native = AdaptiveTextFieldControl(
      control: control(type: "TextField", properties: ["adaptive": true]))
    let form = AdaptiveTextFieldControl(
      control: control(type: "TextField", properties: ["adaptive": false]))

    XCTAssertTrue(native.usesCupertinoStyle)
    XCTAssertFalse(form.usesCupertinoStyle)
  }

  func testCupertinoPresentationConsumesDecorationImageShadowAndVisibilityFields() {
    let presentation = RufletTextFieldPresentation(
      control: control(type: "CupertinoTextField", properties: [
        "blend_mode": "multiply",
        "clear_button_semantics_label": "Clear query",
        "image": [
          "src": "https://example.com/field.png",
          "fit": "cover",
          "repeat": "repeatX",
          "filter_quality": "high",
          "alignment": ["x": 1, "y": -1],
          "scale": 1.5,
          "opacity": 0.4,
          "anti_alias": true,
          "invert_colors": true,
          "match_text_direction": true,
          "color_filter": ["color": "#ffabcdef", "blend_mode": "screen"],
        ],
        "placeholder_style": ["size": 13, "color": "#ff123456"],
        "prefix_visibility_mode": "editing",
        "shadows": [[
          "color": "#80000000", "blur_radius": 6,
          "offset": ["x": 2, "y": 3],
        ]],
        "suffix_visibility_mode": "notEditing",
      ]),
      style: .cupertino)

    XCTAssertEqual(presentation.clearButtonSemanticsLabel, "Clear query")
    XCTAssertEqual(presentation.placeholderStyle?.size, 13)
    XCTAssertFalse(presentation.isVisible(presentation.prefixVisibilityMode, focused: false))
    XCTAssertTrue(presentation.isVisible(presentation.prefixVisibilityMode, focused: true))
    XCTAssertTrue(presentation.isVisible(presentation.suffixVisibilityMode, focused: false))
    XCTAssertFalse(presentation.isVisible(presentation.suffixVisibilityMode, focused: true))
    XCTAssertEqual(presentation.shadows.count, 1)
    XCTAssertEqual(presentation.shadows[0].radius, 6)
    XCTAssertEqual(presentation.shadows[0].x, 2)
    XCTAssertEqual(presentation.shadows[0].y, 3)
    let image = presentation.decorationImage
    XCTAssertNotNil(image)
    XCTAssertEqual(image?.fit, .cover)
    XCTAssertEqual(image?.repeatMode, .repeatX)
    XCTAssertEqual(image?.quality, .high)
    XCTAssertEqual(image?.scale, 1.5)
    XCTAssertEqual(image?.opacity, 0.4)
    XCTAssertTrue(image?.antiAlias == true)
    XCTAssertTrue(image?.invertColors == true)
    XCTAssertTrue(image?.matchTextDirection == true)
    XCTAssertNotNil(image?.tint)
  }

  private func control(type: String, properties: [String: RufletValue]) -> RufletControl {
    RufletControl(id: 1, type: type, properties: properties, backend: backend)
  }
}

@MainActor
private final class TextFieldTestBackend: RufletBackendProtocol {
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
