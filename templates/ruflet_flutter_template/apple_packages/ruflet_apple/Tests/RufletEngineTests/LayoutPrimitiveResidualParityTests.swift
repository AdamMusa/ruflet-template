import SwiftUI
import XCTest
import RufletProtocol
@testable import RufletUI

final class LayoutPrimitiveResidualParityTests: XCTestCase {
  func testContinuousStackAlignmentUsesFlutterCoordinateSpace() {
    let origin = PositionedConstraintMath.origin(
      container: CGSize(width: 300, height: 200),
      child: CGSize(width: 40, height: 20),
      left: nil, top: nil, right: nil, bottom: nil,
      alignment: RufletAlignment(x: 0.5, y: -0.5))

    XCTAssertEqual(origin.x, 195, accuracy: 0.001)
    XCTAssertEqual(origin.y, 45, accuracy: 0.001)
  }

  func testSafeAreaMinimumIsAMaximumPerEdgeNotAdditivePadding() {
    let resolved = SafeAreaInsetMath.resolved(
      safeArea: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
      minimum: EdgeInsets(top: 12, leading: 20, bottom: 48, trailing: 8),
      left: true, top: true, right: false, bottom: true)

    XCTAssertEqual(resolved.top, 59)
    XCTAssertEqual(resolved.leading, 20)
    XCTAssertEqual(resolved.bottom, 48)
    XCTAssertEqual(resolved.trailing, 8)
  }

  func testDividerOmittedThicknessIsOnePointAndExplicitZeroIsAHairline() {
    XCTAssertEqual(DividerGeometry.thickness(nil, displayScale: 3), 1, accuracy: 0.001)
    XCTAssertEqual(DividerGeometry.thickness(0, displayScale: 2), 0.5, accuracy: 0.001)
    XCTAssertEqual(DividerGeometry.thickness(2, displayScale: 3), 2)
  }

  func testResponsiveBreakpointWidthCanDifferFromLocalGridWidth() {
    let responsive: RufletValue = .map(["xs": .int(12), "md": .int(4)])
    let span = ResponsiveGridMath.value(
      responsive, default: 12, width: 900,
      breakpoints: ResponsiveGridMath.defaultBreakpoints)
    let localWidth = ResponsiveGridMath.itemWidth(
      span: span, columns: 12, total: 360, spacing: 10)

    XCTAssertEqual(span, 4)
    XCTAssertEqual(localWidth, 113.333, accuracy: 0.001)
  }
}
