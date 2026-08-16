import CoreGraphics
@testable import RufletColorPickers
import RufletProtocol
import SwiftUI
import XCTest

final class ColorPickerPropertyTests: XCTestCase {
  func testSlidePickerCompoundDefaultsMatchPinnedFlutterColorPicker() {
    XCTAssertEqual(
      rufletSlidePickerSize(nil, default: CGSize(width: 280, height: 50)),
      CGSize(width: 280, height: 50))
    XCTAssertEqual(
      rufletSlidePickerSize(nil, default: CGSize(width: 260, height: 40)),
      CGSize(width: 260, height: 40))
    XCTAssertEqual(
      rufletSlidePickerAlignment(nil, defaultX: -1, defaultY: -3),
      UnitPoint(x: 0, y: -1))
    XCTAssertEqual(
      rufletSlidePickerAlignment(nil, defaultX: 1, defaultY: 3),
      UnitPoint(x: 1, y: 2))
  }

  func testSlidePickerUsesWireSizeAndAlignment() {
    let size: RufletValue = .map([
      "width": .double(320), "height": .double(44),
    ])
    XCTAssertEqual(
      rufletSlidePickerSize(size, default: .zero),
      CGSize(width: 320, height: 44))

    let alignment: RufletValue = .map([
      "x": .double(-0.5), "y": .double(0.5),
    ])
    XCTAssertEqual(
      rufletSlidePickerAlignment(alignment, defaultX: 0, defaultY: 0),
      UnitPoint(x: 0.25, y: 0.75))
  }
}
