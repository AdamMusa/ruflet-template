import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

final class TextPropertyConsumptionTests: XCTestCase {
  @MainActor
  func testTextOnlyInstallsTapRecognitionWhenRubySubscribed() {
    let backend = TextPropertyTestBackend()
    let passive = RufletControl(id: 1, type: "Text", properties: [:], backend: backend)
    let interactive = RufletControl(
      id: 2, type: "Text", properties: ["on_tap": true], backend: backend)

    XCTAssertFalse(RufletTextInteractionContract(control: passive).handlesTap)
    XCTAssertTrue(RufletTextInteractionContract(control: interactive).handlesTap)
  }

  @MainActor
  func testTextUsesTheHorizontalBoxOnlyWhenFletSuppliesATightWidth() {
    let backend = TextPropertyTestBackend()
    let intrinsic = RufletControl(id: 1, type: "Text", properties: [:], backend: backend)
    let explicit = RufletControl(
      id: 2, type: "Text", properties: ["width": .double(240)], backend: backend)
    let row = RufletControl(
      id: 3,
      type: "Row",
      properties: ["_internals": .map(["host_expanded": .bool(true)])],
      backend: backend)
    let expanded = RufletControl(
      id: 4,
      type: "Text",
      properties: ["expand": .bool(true)],
      backend: backend,
      parent: row)

    XCTAssertFalse(
      rufletTextFillsHorizontalBox(control: intrinsic, crossAxisStretchAxis: nil))
    XCTAssertTrue(
      rufletTextFillsHorizontalBox(control: intrinsic, crossAxisStretchAxis: .vertical))
    XCTAssertTrue(
      rufletTextFillsHorizontalBox(control: explicit, crossAxisStretchAxis: nil))
    XCTAssertTrue(
      rufletTextFillsHorizontalBox(control: expanded, crossAxisStretchAxis: nil))
  }

  func testExplicitStyleOverridesThemeStyleWithoutDiscardingThemeFields() {
    let themed = RufletTextStyle(
      size: 18,
      weight: .medium,
      italic: false,
      fontFamily: "ThemeFont",
      height: 1.3,
      decoration: 0,
      decorationColor: nil,
      decorationThickness: nil,
      color: nil,
      backgroundColor: nil,
      letterSpacing: 1,
      wordSpacing: 2,
      overflow: .ellipsis)
    let explicit = RufletTextStyle(
      size: 22,
      weight: nil,
      italic: true,
      fontFamily: nil,
      height: nil,
      decoration: 0,
      decorationColor: nil,
      decorationThickness: nil,
      color: nil,
      backgroundColor: nil,
      letterSpacing: nil,
      wordSpacing: nil,
      overflow: nil)

    let merged = mergeTextStyles(themed, explicit)
    XCTAssertEqual(merged?.size, 22)
    XCTAssertEqual(merged?.fontFamily, "ThemeFont")
    XCTAssertEqual(merged?.letterSpacing, 1)
    XCTAssertTrue(merged?.italic == true)
    XCTAssertEqual(merged?.overflow, .ellipsis)
  }

  func testTextSourceConsumesNativeSelectionAndFallbackContract() throws {
    let source = try String(
      contentsOf: packageRoot.appendingPathComponent("Sources/RufletEngine/Controls/text.swift"),
      encoding: .utf8)
    for property in [
      "enable_interactive_selection", "font_family_fallback", "selection_cursor_color",
      "selection_cursor_height", "selection_cursor_width", "selection_change",
      "show_selection_cursor", "theme_style",
    ] {
      XCTAssertTrue(source.contains("\"\(property)\""), property)
    }
    XCTAssertTrue(source.contains("view.font = style.rufletUIFont"))
    XCTAssertTrue(source.contains("view.font = style.rufletNSFont"))
    XCTAssertFalse(source.contains("RufletTextSelectionModifier"))
  }

  func testSelectionEventMatchesPinnedCompactMap() {
    XCTAssertEqual(
      rufletTextSelectionEventData(
        text: "Ruflet", selection: RufletTextSelection(baseOffset: 2, extentOffset: 5)),
      .map([
        "selected_text": .string("Ruflet"),
        "cause": .string("unknown"),
        "selection": .map([
          "base_offset": .int(2),
          "extent_offset": .int(5),
          "affinity": .string("downstream"),
          "directional": .bool(false),
        ]),
      ]))
  }

  private var packageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }
}

@MainActor
private final class TextPropertyTestBackend: RufletBackendProtocol {
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
