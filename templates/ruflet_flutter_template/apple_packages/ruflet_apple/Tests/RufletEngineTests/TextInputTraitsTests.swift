import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class TextInputTraitsTests: XCTestCase {
  private func node(_ props: [String: RufletValue]) -> ControlNode {
    ControlNode(id: 1, type: "TextField", props: props)
  }

  func testMaxLengthCountsExtendedGraphemeClustersLikeFlutterFormatter() {
    var traits = RufletTextInputTraits()
    traits.maxLength = 5
    XCTAssertEqual(traits.limited("abc"), "abc")
    XCTAssertEqual(traits.limited("abcdefgh"), "abcde")
  }

  func testMaxLengthNeverSplitsAUnicodeGraphemeCluster() {
    var traits = RufletTextInputTraits()
    // LengthLimitingTextInputFormatter uses characters, while selection and
    // counter offsets use UTF-16. Emoji therefore occupy one length slot.
    traits.maxLength = 3
    XCTAssertEqual(traits.limited("ab😀c"), "ab😀")
    traits.maxLength = 1
    XCTAssertEqual(traits.limited("👍🏽x"), "👍🏽")
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

    let readOnly = RufletTextInputTraits(node: node(["read_only": .bool(true)]))
    XCTAssertFalse(readOnly.showCursor)
    XCTAssertTrue(readOnly.enableInteractiveSelection)
    let protected = RufletTextInputTraits(node: node([
      "read_only": .bool(true), "password": .bool(true),
    ]))
    XCTAssertFalse(protected.enableInteractiveSelection)
    XCTAssertTrue(RufletTextInputTraits(node: node([
      "read_only": .bool(true), "show_cursor": .bool(true),
    ])).showCursor)
  }

  private func filter(_ map: [String: RufletValue]) -> RufletTextInputTraits {
    RufletTextInputTraits(node: node(["input_filter": .map(map)]))
  }

  func testPinnedFletFilterAcceptsTheWholeEditWhenRegexMatches() {
    let traits = filter(["regex_string": .string("[0-9]")])
    XCTAssertEqual(
      traits.inputFilter?.apply(oldValue: "12", newValue: "a1b2c3"), "a1b2c3")
    XCTAssertEqual(traits.inputFilter?.apply(oldValue: "12", newValue: "abc"), "12")
  }

  func testPinnedFletOverrideParsesButDoesNotApplyAllowOrReplacement() {
    let traits = filter(["regex_string": .string("[0-9]"), "allow": .bool(false)])
    XCTAssertEqual(traits.inputFilter?.apply(oldValue: "x", newValue: "a1b2c3"), "a1b2c3")
  }

  func testCaseSensitivityFollowsTheFlag() {
    let sensitive = filter(["regex_string": .string("[a-z]")])
    XCTAssertEqual(sensitive.inputFilter?.apply(oldValue: "old", newValue: "aBcD"), "aBcD")
    let insensitive = filter([
      "regex_string": .string("[a-z]"), "case_sensitive": .bool(false),
    ])
    XCTAssertEqual(insensitive.inputFilter?.apply(oldValue: "old", newValue: "aBcD"), "aBcD")
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
    XCTAssertEqual(traits.formatted(oldValue: "", newValue: "a1b2c3"), "a1")
  }

  func testLengthLimitCanWaitUntilMarkedTextCompositionEnds() {
    var traits = RufletTextInputTraits()
    traits.maxLength = 2
    XCTAssertEqual(
      traits.formatted(oldValue: "", newValue: "かなa", enforceLength: false),
      "かなa")
    XCTAssertEqual(
      traits.formatted(oldValue: "", newValue: "かなa", enforceLength: true),
      "かな")
  }

  func testSmartSubstitutionOnlyTurnsOffOnTheDisabledEnum() {
    XCTAssertFalse(
      RufletTextInputTraits(node: node(["smart_dashes_type": .string("disabled")])).smartDashes)
    XCTAssertTrue(
      RufletTextInputTraits(node: node(["smart_quotes_type": .string("enabled")])).smartQuotes)
  }

  func testCapitalizationFormatterMatchesPinnedFletUtility() {
    XCTAssertEqual(
      RufletTextInputTraits(node: node(["capitalization": .string("characters")]))
        .capitalized("Ruflet native"),
      "RUFLET NATIVE")
    XCTAssertEqual(
      RufletTextInputTraits(node: node(["capitalization": .string("words")]))
        .capitalized("rUFLET   nATIVE"),
      "RUFLET NATIVE")
    XCTAssertEqual(
      RufletTextInputTraits(node: node(["capitalization": .string("sentences")]))
        .capitalized("hELLO. nATIVE WORLD"),
      "HELLO. NATIVE WORLD")
  }

  func testBooleanAndLegacyEnumSmartSubstitutionFormsAreAccepted() {
    XCTAssertFalse(
      RufletTextInputTraits(node: node(["smart_dashes_type": .bool(false)])).smartDashes)
    XCTAssertTrue(
      RufletTextInputTraits(node: node(["smart_quotes_type": .bool(true)])).smartQuotes)
  }
}
