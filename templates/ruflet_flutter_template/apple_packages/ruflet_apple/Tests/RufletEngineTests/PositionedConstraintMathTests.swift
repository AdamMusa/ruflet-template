import XCTest
import SwiftUI
@testable import RufletUI

final class PositionedConstraintMathTests: XCTestCase {
  func testOpposingInsetsImposeTightWidthAndHeight() {
    let size = PositionedConstraintMath.childSize(
      container: CGSize(width: 300, height: 200),
      intrinsic: CGSize(width: 40, height: 30),
      left: 20, top: 10, right: 30, bottom: 15)

    XCTAssertEqual(size.width, 250)
    XCTAssertEqual(size.height, 175)
  }

  func testSingleInsetPreservesIntrinsicSizeAndPositionsChild() {
    let child = PositionedConstraintMath.childSize(
      container: CGSize(width: 300, height: 200),
      intrinsic: CGSize(width: 40, height: 30),
      left: nil, top: nil, right: 25, bottom: 12)
    let origin = PositionedConstraintMath.origin(
      container: CGSize(width: 300, height: 200), child: child,
      left: nil, top: nil, right: 25, bottom: 12,
      alignment: .topLeading)

    XCTAssertEqual(child, CGSize(width: 40, height: 30))
    XCTAssertEqual(origin, CGPoint(x: 235, y: 158))
  }

  func testPositionedChildUsesFiniteParentProposal() {
    let size = PositionedConstraintMath.containerSize(
      proposal: ProposedViewSize(width: 300, height: 200),
      intrinsic: CGSize(width: 40, height: 30),
      left: 20, top: 10, right: 30, bottom: 15)

    XCTAssertEqual(size, CGSize(width: 300, height: 200))
  }
}
