import XCTest
import RufletEngine
import RufletProtocol
import SwiftUI
@testable import RufletCodeEditor
@testable import RufletUI

@MainActor
final class CodeEditorParityTests: XCTestCase {
  func testFoldProjectionPreservesSourceAndCanBeRemovedLosslessly() {
    let source = "def greet\n  puts 'hello'\nend\ngreet"
    let region = CodeFoldProjection.blockRegion(in: source, startingAt: 0)

    XCTAssertEqual(region, CodeFoldRegion(startLine: 0, endLine: 2))
    XCTAssertEqual(
      CodeFoldProjection.project(source, folding: [region!]),
      "def greet  …\ngreet")
    XCTAssertEqual(CodeFoldProjection.project(source, folding: []), source)
  }

  func testImportFoldingGroupsConsecutiveImports() {
    let source = "require 'json'\nrequire 'date'\n\nputs Date.today"
    XCTAssertEqual(
      CodeFoldProjection.importRegions(in: source),
      [CodeFoldRegion(startLine: 0, endLine: 1)])
  }

  func testLeadingCommentFoldMatchesFletCommandScope() {
    let source = "# frozen_string_literal: true\n# Copyright Ruflet\n\nrequire 'ruflet'"
    XCTAssertEqual(
      CodeFoldProjection.leadingCommentRegion(in: source),
      CodeFoldRegion(startLine: 0, endLine: 1))
  }

  func testConfigurationUsesFletEditorAndGutterDefaults() {
    let value = CodeEditorConfiguration(node: ControlNode(id: 1, type: "CodeEditor"))
    XCTAssertEqual(value.language, "")
    XCTAssertEqual(value.padding, EdgeInsets())
    XCTAssertEqual(value.gutter.width, 80)
    XCTAssertEqual(value.gutter.margin, 10)
    XCTAssertTrue(value.gutter.showErrors)
    XCTAssertTrue(value.gutter.showFoldingHandles)
    XCTAssertTrue(value.gutter.showLineNumbers)
    XCTAssertFalse(value.autocomplete)
    XCTAssertFalse(value.readOnly)
    XCTAssertFalse(value.autofocus)
  }

  func testConfigurationConsumesEveryPluginSpecificProperty() {
    let node = ControlNode(id: 1, type: "CodeEditor", props: [
      "language": .string("SWIFT"),
      "code_theme": .map([
        "name": .string("atom-one-dark"),
        "styles": .map(["keyword": .map(["color": .string("#ff00ff")])]),
      ]),
      "text_style": .map(["size": .double(18), "font_family": .string("Menlo")]),
      "padding": .map(["left": .double(4), "top": .double(5), "right": .double(6), "bottom": .double(7)]),
      "gutter_style": .map([
        "width": .double(44), "margin": .double(3),
        "show_errors": .bool(false), "show_folding_handles": .bool(false),
        "show_line_numbers": .bool(true), "background_color": .string("#101010"),
      ]),
      "autocomplete": .bool(true),
      "autocomplete_words": .array([.string("RufletApp"), .string("ControlNode")]),
      "read_only": .bool(true), "autofocus": .bool(true), "disabled": .bool(true),
    ])
    let value = CodeEditorConfiguration(node: node)
    XCTAssertEqual(value.language, "swift")
    XCTAssertEqual(value.themeName, "atom-one-dark")
    XCTAssertTrue(value.dark)
    XCTAssertEqual(value.fontSize, 18)
    XCTAssertEqual(value.fontFamily, "Menlo")
    XCTAssertEqual(value.gutter.width, 44)
    XCTAssertEqual(value.gutter.margin, 3)
    XCTAssertFalse(value.gutter.showErrors)
    XCTAssertFalse(value.gutter.showFoldingHandles)
    XCTAssertEqual(value.autocompleteWords, ["RufletApp", "ControlNode"])
    XCTAssertTrue(value.autocomplete)
    XCTAssertTrue(value.readOnly)
    XCTAssertTrue(value.autofocus)
    XCTAssertTrue(value.disabled)
  }

  func testGutterMarginMapAndAutocompleteUsePinnedDartConversions() {
    let configuration = CodeEditorConfiguration(node: ControlNode(
      id: 1, type: "CodeEditor", props: [
        "gutter_style": .map([
          "margin": .map(["left": .double(4), "right": .double(8)])
        ]),
        "autocomplete_words": .array([
          .string("Ruflet"), .int(42), .bool(true), .null,
        ]),
      ]))
    XCTAssertEqual(configuration.gutter.margin, 6)
    XCTAssertEqual(configuration.autocompleteWords, ["Ruflet", "42", "true", "null"])
  }

  func testValueChangesUpdateControlBeforeOptionalChangeEvent() {
    var trace: [String] = []
    let sink = RufletEventSink(
      send: { _, name, value in trace.append("event:\(name):\(value.stringValue ?? "")") },
      setLocal: { _, key, value in trace.append("local:\(key):\(value.stringValue ?? "")") },
      update: { _, props in trace.append("update:\(props["value"]?.stringValue ?? "")") })
    CodeEditorValueEvents.commit(
      ControlNode(
        id: 1, type: "CodeEditor", props: ["on_change": .bool(true)]),
      value: "puts :native", to: sink)
    XCTAssertEqual(trace, [
      "local:value:puts :native",
      "update:puts :native",
      "event:change:puts :native",
    ])

    trace = []
    CodeEditorValueEvents.commit(
      ControlNode(id: 2, type: "CodeEditor"), value: "silent", to: sink)
    XCTAssertEqual(trace, ["local:value:silent", "update:silent"])
  }

  func testSelectionClampsAndUsesFletUtf16Payload() {
    let reversed: RufletValue = .map([
      "base_offset": .int(7), "extent_offset": .int(1),
    ])
    XCTAssertEqual(
      CodeEditorSelection.range(from: reversed, text: "Ruflet!"),
      NSRange(location: 1, length: 6))
    guard case .map(let event) = CodeEditorSelection.event(
      NSRange(location: 1, length: 3), text: "Ruflet"),
      case .string(let selected) = event["selected_text"],
      case .map(let selection) = event["selection"]
    else { return XCTFail("expected selection event") }
    XCTAssertEqual(selected, "ufl")
    XCTAssertEqual(selection["base_offset"]?.intValue, 1)
    XCTAssertEqual(selection["extent_offset"]?.intValue, 4)
  }

  func testLanguageDefinitionsAreSelectedFromLanguageProperty() {
    XCTAssertTrue(CodeLanguageSyntax.resolve("python").keywords.contains("lambda"))
    XCTAssertTrue(CodeLanguageSyntax.resolve("swift").keywords.contains("protocol"))
    XCTAssertTrue(CodeLanguageSyntax.resolve("ruby").keywords.contains("module"))
    XCTAssertFalse(CodeLanguageSyntax.resolve("xml").commentPatterns.isEmpty)
  }

  func testRegistryExposesOnlyFletCodeEditorMethods() {
    RufletCodeEditor.register(in: ServiceRegistry())
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "CodeEditor")?.supportedMethods,
      ["focus", "fold_at", "fold_comment_at_line_zero", "fold_imports"])
  }

  func testAutocompleteUsesConfiguredWordsAndCurrentCaretPrefix() {
    XCTAssertEqual(
      CodeEditorCompletion.current(
        in: "Ruf", selection: NSRange(location: 3, length: 0),
        words: ["RufletApp", "Ruby", "ControlNode"]),
      CodeEditorCompletion(
        range: NSRange(location: 0, length: 3), suggestions: ["RufletApp"]))
    XCTAssertNil(CodeEditorCompletion.current(
      in: "Ruf", selection: NSRange(location: 0, length: 2), words: ["RufletApp"]))
  }

  func testGutterDiagnosticsReportUnmatchedDelimiterLines() {
    XCTAssertEqual(CodeEditorDiagnostics.lines(in: "call(\nvalue\n"), [0])
    XCTAssertEqual(CodeEditorDiagnostics.lines(in: "call(\nvalue)\n"), [])
    XCTAssertEqual(CodeEditorDiagnostics.lines(in: "value)"), [0])
  }
}
