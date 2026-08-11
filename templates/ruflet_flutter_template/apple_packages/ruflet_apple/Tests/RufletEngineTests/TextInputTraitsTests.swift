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

  func testSmartSubstitutionOnlyTurnsOffOnTheDisabledEnum() {
    XCTAssertFalse(
      RufletTextInputTraits(node: node(["smart_dashes_type": .string("disabled")])).smartDashes)
    XCTAssertTrue(
      RufletTextInputTraits(node: node(["smart_quotes_type": .string("enabled")])).smartQuotes)
  }
}
