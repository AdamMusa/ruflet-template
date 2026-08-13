import SwiftUI
import XCTest
@testable import RufletEngine

final class HighlightViewTests: XCTestCase {
  func testTabsAreExpandedExactlyLikePinnedHighlightView() {
    let regular = HighlightView("a\tb", tabSize: 4)
    let zero = HighlightView("a\tb", tabSize: 0)

    XCTAssertEqual(regular.source, "a    b")
    XCTAssertEqual(zero.source, "ab")
    XCTAssertFalse(regular.selectable)
  }

  func testSwiftTokensPreserveSourceAndPinnedHighlightClassNames() {
    let source = "let value: String = \"let 7\"\n// return 9\nvalue.count + 42"
    let tokens = RufletHighlightParser(source: source, language: "swift").parse()

    XCTAssertEqual(tokens.map(\.text).joined(), source)
    XCTAssertTrue(tokens.contains(.init(text: "let", className: "keyword")))
    XCTAssertTrue(tokens.contains(.init(text: "String", className: "built_in")))
    XCTAssertTrue(tokens.contains(.init(text: "\"let 7\"", className: "string")))
    XCTAssertTrue(tokens.contains(.init(text: "// return 9", className: "comment")))
    XCTAssertTrue(tokens.contains(.init(text: "42", className: "number")))
  }

  func testStringsAndCommentsTakePrecedenceOverNestedKeywordsAndNumbers() {
    let source = "const text = 'return 123'; /* if 456 */ return 789"
    let tokens = RufletHighlightParser(source: source, language: "javascript").parse()

    XCTAssertEqual(
      tokens.filter { $0.className == "string" }.map(\.text), ["'return 123'"])
    XCTAssertEqual(
      tokens.filter { $0.className == "comment" }.map(\.text), ["/* if 456 */"])
    XCTAssertEqual(tokens.filter { $0.className == "number" }.map(\.text), ["789"])
    XCTAssertEqual(
      tokens.filter { $0.className == "keyword" }.map(\.text), ["const", "return"])
  }

  func testLanguageAliasesAndAutomaticDetectionUseTheSameTokenGrammar() {
    let ruby = "def greet(name)\n  puts name\nend"
    let explicit = RufletHighlightParser(source: ruby, language: "rb").parse()
    let detected = RufletHighlightParser(source: ruby, language: nil).parse()

    XCTAssertEqual(explicit, detected)
    XCTAssertTrue(explicit.contains(.init(text: "def", className: "keyword")))
    XCTAssertTrue(explicit.contains(.init(text: "greet", className: "title")))
  }

  func testMarkupAndUnknownLanguageNeverMutateOrDropSource() {
    let markup = "<section id=\"main\">Hello</section>"
    let markupTokens = RufletHighlightParser(source: markup, language: "html").parse()
    let unknown = "alpha + beta"
    let unknownTokens = RufletHighlightParser(source: unknown, language: "custom").parse()

    XCTAssertEqual(markupTokens.map(\.text).joined(), markup)
    XCTAssertEqual(markupTokens.filter { $0.className == "tag" }.map(\.text), [
      "<section id=\"main\">", "</section>",
    ])
    XCTAssertEqual(unknownTokens, [.init(text: unknown, className: nil)])
  }

  func testSelectableThemePaddingAndDecorationRemainPublicViewInputs() {
    let theme = [
      "root": parseTextStyle(["color": "#112233", "bgcolor": "#f0f0f0"])!,
      "keyword": parseTextStyle(["weight": "bold"])!,
    ]
    let view = HighlightView(
      "let answer = 42", language: "swift", theme: theme,
      padding: EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4),
      decoration: .init(borderRadius: parseBorderRadius(6)),
      textStyle: parseTextStyle(["size": 15]), selectable: true)

    XCTAssertTrue(view.selectable)
    XCTAssertEqual(view.padding?.leading, 2)
    XCTAssertEqual(view.decoration?.borderRadius?.uniform, 6)
    XCTAssertEqual(view.textStyle?.size, 15)
    XCTAssertEqual(view.highlightedTokens.map(\.text).joined(), view.source)
  }
}
