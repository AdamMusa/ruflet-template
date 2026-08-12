import XCTest

/// Pins the Apple renderer to the vendored Flet 0.80.5 Semantics contract.
/// Ruflet's older Ruby spellings remain compatibility aliases, but canonical
/// Flet names must always be preferred when both arrive on the wire.
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

  func testRendererReadsCanonicalFletProperties() throws {
    let source = try semanticsSource()
    for key in [
      "label", "expanded", "hidden", "selected", "checked", "button", "slider",
      "value", "text_field", "image", "link", "header", "increased_value",
      "decreased_value", "hint", "on_tap_hint", "on_long_press_hint", "container",
      "live_region", "obscured", "multiline", "focused", "read_only", "focusable",
      "tooltip", "toggled", "max_value_length", "current_value_length",
      "heading_level", "exclude_semantics", "mixed", "disabled",
    ] {
      XCTAssertTrue(
        source.contains("\"\(key)\""), "Semantics never reads canonical Flet key \(key)")
    }
  }

  func testHistoricalRufletSpellingsAreCompatibilityAliasesOnly() throws {
    let source = try semanticsSource()
    XCTAssertTrue(source.contains("string(\"hint\", compatibility: \"hint_text\")"))
    XCTAssertTrue(source.contains("bool(\"text_field\", compatibility: \"textfield\")"))
    XCTAssertTrue(source.contains("bool(\"focused\", compatibility: \"focus\")"))
    XCTAssertTrue(
      source.contains(
        "string(\"on_tap_hint\", compatibility: \"on_tap_hint_text\")"))
    XCTAssertTrue(
      source.contains(
        "string(\"on_long_press_hint\", compatibility: \"on_long_press_hint_text\")"))
  }

  func testDefaultActionReportsCanonicalClickWithLegacyTapFallback() throws {
    let source = try semanticsSource()
    XCTAssertTrue(source.contains("handledEvent(\"click\", compatibility: \"tap\")"))
  }
}
