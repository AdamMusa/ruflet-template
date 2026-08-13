import SwiftUI
import XCTest

@testable import RufletEngine

@MainActor
final class SearchBarPropertyConsumptionTests: XCTestCase {
  func testBarWidgetStatePropertiesResolveForNativeAppleStates() {
    let background = RufletWidgetStateProperty<Color>(
      [
        "default": "#112233",
        "focused": "#445566",
      ],
      converter: { raw in
        guard let text = raw as? String else { return nil }
        return parseColor(text)
      })

    XCTAssertNotNil(background.resolve([]))
    XCTAssertNotNil(background.resolve([.focused]))

    let padding = RufletWidgetStateProperty<EdgeInsets>(
      ["default": 6, "focused": 12],
      converter: { parsePadding($0) })
    XCTAssertEqual(padding.resolve([])?.leading, 6)
    XCTAssertEqual(padding.resolve([.focused])?.leading, 12)
  }

  func testSearchBarCapitalizationMatchesPinnedControllerTransaction() {
    XCTAssertEqual(
      applySearchBarCapitalization("native APPLE", .words),
      "Native Apple")
    XCTAssertEqual(
      applySearchBarCapitalization("hello SWIFT. native APPLE", .sentences),
      "Hello swift. Native apple")
    XCTAssertEqual(
      applySearchBarCapitalization("native apple", .characters),
      "NATIVE APPLE")
  }
}
