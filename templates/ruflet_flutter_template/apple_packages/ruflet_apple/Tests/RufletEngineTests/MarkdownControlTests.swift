import Foundation
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class MarkdownControlTests: XCTestCase {
  func testMissingExtensionSetUsesPinnedNoneDefault() {
    XCTAssertEqual(
      parseMarkdownExtensionSet(nil, RufletMarkdownExtensionSet.none),
      RufletMarkdownExtensionSet.none)
  }

  func testParserPortsCommonBlocksInlineTraitsLinksImagesAndCode() {
    let parser = RufletMarkdownParser(
      source: """
        # Title

        Hello **bold** *italic* [site](https://example.com) ![Alt](photo.png) and `code`.

        ```swift
        let answer = 42
        ```
        """,
      extensionSet: .gitHubFlavored)

    guard case .heading(1, let title) = parser.blocks[0] else {
      return XCTFail("Expected heading")
    }
    XCTAssertEqual(title, [.text("Title", [], nil)])

    guard case .paragraph(let paragraph) = parser.blocks[1] else {
      return XCTFail("Expected paragraph")
    }
    XCTAssertTrue(paragraph.contains(.text("bold", [.strong], nil)))
    XCTAssertTrue(paragraph.contains(.text("italic", [.emphasis], nil)))
    XCTAssertTrue(
      paragraph.contains(
        .text(
          "site", [], .init(destination: "https://example.com", title: ""))))
    XCTAssertTrue(paragraph.contains(.image("photo.png", "Alt", "")))
    XCTAssertTrue(paragraph.contains(.text("code", [.code], nil)))

    guard case .code("swift", "let answer = 42") = parser.blocks[2] else {
      return XCTFail("Expected highlighted Swift code block")
    }
  }

  func testGitHubExtensionsAndLatexAreRepresentedSemantically() {
    let parser = RufletMarkdownParser(
      source: """
        - [x] shipped
        - [ ] pending

        | Name | Value |
        | --- | --- |
        | Ruby | 3 |

        Inline $x^2$.

        $$
        \\frac{1}{2}
        $$
        """, extensionSet: .gitHubFlavored)

    guard case .list(false, 1, let items) = parser.blocks[0] else {
      return XCTFail("Expected task list")
    }
    XCTAssertEqual(items.map(\.checked), [true, false])
    guard case .table(let header, let rows) = parser.blocks[1] else {
      return XCTFail("Expected GFM table")
    }
    XCTAssertEqual(header.count, 2)
    XCTAssertEqual(rows.count, 1)
    guard case .paragraph(let inlineMath) = parser.blocks[2] else {
      return XCTFail("Expected inline math paragraph")
    }
    XCTAssertTrue(inlineMath.contains(.latex("x^2", [])))
    XCTAssertEqual(parser.blocks[3], .latex("\\frac{1}{2}"))
  }

  func testSelectionPayloadMatchesPinnedFletShape() {
    let payload = RufletMarkdownRenderer.selectionPayload(
      text: "Ruflet", range: NSRange(location: 1, length: 3))
    XCTAssertEqual(payload.map?["text"], .string("ufl"))
    XCTAssertEqual(payload.map?["cause"], .string("unknown"))
    let selection = payload.map?["selection"]?.map
    XCTAssertEqual(selection?["start"], .int(1))
    XCTAssertEqual(selection?["end"], .int(4))
    XCTAssertEqual(selection?["collapsed"], .bool(false))
    XCTAssertEqual(selection?["normalized"], .bool(true))
  }

  func testMarkdownControlAcceptsOnlyPinnedWireType() {
    let backend = MarkdownTestBackend()
    let control = RufletControl(
      id: 1, type: "Markdown", properties: ["value": "# Native"], backend: backend)
    XCTAssertNoThrow(_ = MarkdownControl(control: control))
  }
}

@MainActor
private final class MarkdownTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int, properties: [String: RufletValue], client: Bool, server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
