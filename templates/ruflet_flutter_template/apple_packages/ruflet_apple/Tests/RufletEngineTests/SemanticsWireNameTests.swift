import XCTest

/// Semantics is the one control where Ruflet's Ruby keywords and Flutter's
/// Dart parameter names disagree, and the renderer has to follow Ruby: those
/// are the keys that actually arrive on the wire.
///
/// The renderer read Flutter's spelling here once already, which silently
/// dropped every one of these properties, so the names are pinned.
final class SemanticsWireNameTests: XCTestCase {
  private func semanticsSource() throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletUI/Controls/WrapperControls.swift")
    let source = try String(contentsOf: url)
    let start = try XCTUnwrap(source.range(of: "struct SemanticsControlView"))
    let end = try XCTUnwrap(
      source.range(of: "/// `MergeSemantics`", range: start.upperBound..<source.endIndex))
    return String(source[start.lowerBound..<end.lowerBound])
  }

  func testRendererReadsTheKeysRubySends() throws {
    let source = try semanticsSource()
    for key in [
      "hint_text", "textfield", "focus", "focusable", "heading_level",
      "exclude_semantics", "live_region", "obscured", "read_only", "multiline",
      "checked", "mixed", "toggled", "expanded", "slider",
      "increased_value", "decreased_value",
      "current_value_length", "max_value_length",
      "on_tap_hint_text", "on_long_press_hint_text",
    ] {
      XCTAssertTrue(
        source.contains("\"\(key)\""), "Semantics never reads \(key), which Ruby sends")
    }
  }

  func testRendererDoesNotReadFlutterOnlySpellings() throws {
    let source = try semanticsSource()
    // Ruby has no keyword for any of these; reading them can only ever miss.
    for key in ["\"hint\"", "\"text_field\"", "\"focused\"", "\"on_tap_hint\""] {
      XCTAssertFalse(
        source.contains(key), "Semantics reads \(key), which Ruby never sends")
    }
  }

  func testDefaultActionReportsTapRatherThanClick() throws {
    let source = try semanticsSource()
    XCTAssertTrue(source.contains("handlesEvent(\"tap\")"))
    XCTAssertFalse(
      source.contains("\"click\""), "Ruby declares on_tap, so the event back is tap")
  }
}
