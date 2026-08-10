import XCTest
@testable import RufletUI
import RufletProtocol

final class ResponsiveGridMathTests: XCTestCase {
  private let breakpoints = ResponsiveGridMath.defaultBreakpoints
  private let span: RufletValue = .map([
    "xs": .int(12), "sm": .int(6), "md": .int(4),
  ])

  func testFletBreakpointSelectionUsesGreatestMatchingThreshold() {
    XCTAssertEqual(ResponsiveGridMath.value(
      span, default: 12, width: 390, breakpoints: breakpoints), 12)
    XCTAssertEqual(ResponsiveGridMath.value(
      span, default: 12, width: 700, breakpoints: breakpoints), 6)
    XCTAssertEqual(ResponsiveGridMath.value(
      span, default: 12, width: 900, breakpoints: breakpoints), 4)
  }

  func testPhoneSpansProduceOneFullWidthCellPerLine() {
    let spans = Array(repeating: 12.0, count: 6)
    XCTAssertEqual(
      ResponsiveGridMath.lines(spans: spans, columns: 12),
      [[0], [1], [2], [3], [4], [5]])
    XCTAssertEqual(
      ResponsiveGridMath.itemWidth(span: 12, columns: 12, total: 350, spacing: 12),
      350, accuracy: 0.001)

    let constrained = ResponsiveGridMath.constrainedItemSize(
      width: 350, measured: CGSize(width: 124, height: 48))
    XCTAssertEqual(constrained.width, 350)
    XCTAssertEqual(constrained.height, 48)
  }

  func testExplicitWidthMatchesFletTightParentConstraints() {
    XCTAssertEqual(FletConstraintMath.width(requested: 320, proposed: 390), 320)
    XCTAssertEqual(FletConstraintMath.width(requested: 560, proposed: 390), 390)
    XCTAssertEqual(FletConstraintMath.width(requested: 320, proposed: nil), 320)
  }

  func testTabletAndDesktopSpansShareRows() {
    XCTAssertEqual(
      ResponsiveGridMath.lines(spans: Array(repeating: 6.0, count: 5), columns: 12),
      [[0, 1], [2, 3], [4]])
    XCTAssertEqual(
      ResponsiveGridMath.lines(spans: Array(repeating: 4.0, count: 5), columns: 12),
      [[0, 1, 2], [3, 4]])
  }

  func testPartialRowsKeepTheSameGridColumnWidth() {
    let fullRowWidth = ResponsiveGridMath.itemWidth(
      span: 6, columns: 12, total: 600, spacing: 12)
    let partialRowWidth = ResponsiveGridMath.itemWidth(
      span: 6, columns: 12, total: 600, spacing: 12)
    XCTAssertEqual(fullRowWidth, partialRowWidth, accuracy: 0.001)
    XCTAssertEqual(fullRowWidth, 294, accuracy: 0.001)
  }
}
