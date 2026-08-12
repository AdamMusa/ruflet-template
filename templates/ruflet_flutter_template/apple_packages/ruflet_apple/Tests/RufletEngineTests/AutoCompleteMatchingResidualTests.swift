@testable import RufletUI
import XCTest

final class AutoCompleteMatchingResidualTests: XCTestCase {
  func testAutoCompleteMatchesSelectionKeyInsteadOfDisplayValue() {
    let suggestion = RufletAutoCompleteSuggestion(key: "nyc", value: "New York")

    XCTAssertTrue(suggestion.matches("NY"))
    XCTAssertFalse(suggestion.matches("New"))
  }

  func testAutoCompleteUsesPinnedLowercaseContainsRatherThanCaseFolding() {
    let suggestion = RufletAutoCompleteSuggestion(key: "Straße", value: "Street")

    XCTAssertTrue(suggestion.matches("STRAẞE"))
    XCTAssertFalse(suggestion.matches("STRASSE"))
  }

  func testAutoCompleteReturnsNoOptionsForEmptyQuery() {
    let suggestion = RufletAutoCompleteSuggestion(key: "all", value: "All")

    XCTAssertFalse(suggestion.matches(""))
  }
}
