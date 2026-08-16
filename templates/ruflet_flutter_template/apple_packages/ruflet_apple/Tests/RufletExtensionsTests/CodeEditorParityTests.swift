import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletCodeEditor

@MainActor
final class CodeEditorParityTests: XCTestCase {
  func testDefaultCodeFieldUsesFlutterTitleMediumLineMetrics() {
    let style = RufletCodeEditorStyle(control: control(properties: [
      "code_theme": .string("atom-one-dark")
    ]))

    XCTAssertEqual(style.font.pointSize, 16, accuracy: 0.01)
    XCTAssertEqual(style.lineHeight, 24, accuracy: 0.01)
    XCTAssertEqual(style.gutter.background, style.background)
    XCTAssertEqual(style.padding.top, 0, accuracy: 0.01)
    XCTAssertEqual(style.padding.left, 0, accuracy: 0.01)
  }

  func testTrailingNewlineKeepsTheFinalFlutterGutterRow() {
    let controller = FletCodeController(text: "first\nsecond\n", language: "ruby")

    XCTAssertEqual(controller.lineNumbers(), [1, 2, 3])
  }

  func testFoldHandlesAreLimitedToIndentedBlocks() {
    let controller = FletCodeController(
      text: "root\n  child\nsibling\n    nested\nend\n",
      language: "ruby")

    XCTAssertEqual(controller.foldableLineNumbers(), [1, 3])
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "CodeEditor",
      properties: properties,
      backend: CodeEditorParityBackend())
  }
}

@MainActor
private final class CodeEditorParityBackend: RufletBackendProtocol {
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
