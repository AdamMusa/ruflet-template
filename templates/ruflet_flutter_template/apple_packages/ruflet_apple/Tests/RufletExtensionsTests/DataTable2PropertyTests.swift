@testable import RufletDataTable2
import RufletProtocol
import SwiftUI
import XCTest

final class DataTable2PropertyTests: XCTestCase {
  func testCheckboxThemeConsumesPinnedFillCheckBorderAndShape() {
    let theme: RufletValue = .map([
      "fill_color": .map([
        "selected": .string("#112233"),
        "default": .string("#445566"),
      ]),
      "check_color": .string("#ffffff"),
      "border_side": .map([
        "color": .string("#abcdef"), "width": .double(3),
      ]),
      "shape": .map([
        "_type": .string("RoundedRectangleBorder"), "radius": .double(6),
      ]),
    ])

    let selected = RufletDataTable2CheckboxStyle(
      theme: theme, state: .checked, enabled: true)
    let unselected = RufletDataTable2CheckboxStyle(
      theme: theme, state: .unchecked, enabled: true)
    XCTAssertEqual(selected.borderWidth, 3)
    XCTAssertEqual(selected.cornerRadius, 6)
    XCTAssertNotEqual(String(describing: selected.fill), String(describing: unselected.fill))
  }

  func testCheckboxCircleShapeAndDurationDefaultsMatchPinnedDataTable2() {
    let theme: RufletValue = .map([
      "shape": .map(["_type": .string("CircleBorder")]),
    ])
    XCTAssertEqual(
      RufletDataTable2CheckboxStyle(
        theme: theme, state: .mixed, enabled: true).cornerRadius,
      9)
    XCTAssertEqual(rufletDataTable2Duration(nil), 0.000_150, accuracy: 0.000_000_1)
    XCTAssertEqual(
      rufletDataTable2Duration(.int(250)), 0.25, accuracy: 0.000_000_1)
  }
}
