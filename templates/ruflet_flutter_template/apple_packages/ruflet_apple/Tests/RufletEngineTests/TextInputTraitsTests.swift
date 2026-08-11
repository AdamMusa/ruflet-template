import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class TextInputTraitsTests: XCTestCase {
  private func node(_ props: [String: RufletValue]) -> ControlNode {
    ControlNode(id: 1, type: "TextField", props: props)
  }

  func testMaxLengthCountsUTF16TheWayFlutterDoes() {
    var traits = RufletTextInputTraits()
    traits.maxLength = 5
    XCTAssertEqual(traits.limited("abc"), "abc")
    XCTAssertEqual(traits.limited("abcdefgh"), "abcde")
  }

  func testMaxLengthNeverSplitsASurrogatePair() {
    var traits = RufletTextInputTraits()
    // An emoji is two UTF-16 units, so a limit of 3 lands inside the second
    // one; Flutter keeps the character whole rather than emitting half of it.
    traits.maxLength = 3
    XCTAssertEqual(traits.limited("ab😀"), "ab")
    traits.maxLength = 4
    XCTAssertEqual(traits.limited("ab😀c"), "ab😀")
  }

  func testAbsentMaxLengthLeavesTextAlone() {
    let traits = RufletTextInputTraits()
    XCTAssertNil(traits.maxLength)
    XCTAssertEqual(traits.limited("anything at all"), "anything at all")
  }

  func testNonPositiveMaxLengthMeansNoLimit() {
    XCTAssertNil(RufletTextInputTraits(node: node(["max_length": .int(0)])).maxLength)
    XCTAssertNil(RufletTextInputTraits(node: node(["max_length": .int(-1)])).maxLength)
    XCTAssertEqual(RufletTextInputTraits(node: node(["max_length": .int(4)])).maxLength, 4)
  }

  func testDefaultsMatchFletWhenThePropertiesAreAbsent() {
    let traits = RufletTextInputTraits(node: node([:]))
    XCTAssertTrue(traits.autocorrect)
    XCTAssertTrue(traits.enableSuggestions)
    XCTAssertTrue(traits.showCursor)
    XCTAssertTrue(traits.enableInteractiveSelection)
    XCTAssertFalse(traits.readOnly)
  }

  private func filter(_ map: [String: RufletValue]) -> RufletTextInputTraits {
    RufletTextInputTraits(node: node(["input_filter": .map(map)]))
  }

  func testAllowingKeepsOnlyTheMatchingRuns() {
    let traits = filter(["regex_string": .string("[0-9]")])
    XCTAssertEqual(traits.inputFilter?.apply(to: "a1b2c3"), "123")
    XCTAssertEqual(traits.inputFilter?.apply(to: "abc"), "")
  }

  func testDenyingDropsTheMatchingRuns() {
    let traits = filter(["regex_string": .string("[0-9]"), "allow": .bool(false)])
    XCTAssertEqual(traits.inputFilter?.apply(to: "a1b2c3"), "abc")
  }

  func testReplacementStringStandsInForRejectedText() {
    let allow = filter([
      "regex_string": .string("[0-9]+"), "replacement_string": .string("-"),
    ])
    XCTAssertEqual(allow.inputFilter?.apply(to: "ab12cd34"), "-12-34")
    let deny = filter([
      "regex_string": .string("[0-9]+"), "allow": .bool(false),
      "replacement_string": .string("#"),
    ])
    XCTAssertEqual(deny.inputFilter?.apply(to: "ab12cd34"), "ab#cd#")
  }

  func testCaseSensitivityFollowsTheFlag() {
    let sensitive = filter(["regex_string": .string("[a-z]")])
    XCTAssertEqual(sensitive.inputFilter?.apply(to: "aBcD"), "ac")
    let insensitive = filter([
      "regex_string": .string("[a-z]"), "case_sensitive": .bool(false),
    ])
    XCTAssertEqual(insensitive.inputFilter?.apply(to: "aBcD"), "aBcD")
  }

  func testAnInvalidOrAbsentPatternLeavesNoFilter() {
    XCTAssertNil(RufletTextInputTraits(node: node([:])).inputFilter)
    XCTAssertNil(filter(["regex_string": .string("")]).inputFilter)
    XCTAssertNil(filter(["regex_string": .string("[unterminated")]).inputFilter)
  }

  func testFilterRunsBeforeTheLengthLimit() {
    var traits = filter(["regex_string": .string("[0-9]")])
    traits.maxLength = 2
    // Flutter orders its formatters the same way: filtering first, so the
    // limit counts what survived rather than what was typed.
    XCTAssertEqual(traits.formatted("a1b2c3"), "12")
  }

  func testSmartSubstitutionOnlyTurnsOffOnTheDisabledEnum() {
    XCTAssertFalse(
      RufletTextInputTraits(node: node(["smart_dashes_type": .string("disabled")])).smartDashes)
    XCTAssertTrue(
      RufletTextInputTraits(node: node(["smart_quotes_type": .string("enabled")])).smartQuotes)
  }
}
