import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class LayoutFamilyParityTests: XCTestCase {
  func testWrapDistributionMatchesFlutterAlignments() {
    let between = RufletWrapMath.distribution(.spaceBetween, freeSpace: 60, count: 3)
    XCTAssertEqual(between.leading, 0)
    XCTAssertEqual(between.between, 30)

    let around = RufletWrapMath.distribution(.spaceAround, freeSpace: 60, count: 3)
    XCTAssertEqual(around.leading, 10)
    XCTAssertEqual(around.between, 20)

    let evenly = RufletWrapMath.distribution(.spaceEvenly, freeSpace: 60, count: 3)
    XCTAssertEqual(evenly.leading, 15)
    XCTAssertEqual(evenly.between, 15)
  }

  func testWrapCrossAlignmentOffsetsChildrenWithinRun() {
    XCTAssertEqual(
      RufletWrapMath.crossOffset(.start, runExtent: 40, childExtent: 10), 0)
    XCTAssertEqual(
      RufletWrapMath.crossOffset(.center, runExtent: 40, childExtent: 10), 15)
    XCTAssertEqual(
      RufletWrapMath.crossOffset(.end, runExtent: 40, childExtent: 10), 30)
    XCTAssertEqual(RufletWrapMath.crossAlignment("center", default: .start), .center)
    XCTAssertEqual(RufletWrapMath.crossAlignment("stretch", default: .center), .center)
  }

  func testFlexStretchUsesTightCrossAxisExtent() {
    XCTAssertEqual(
      RufletFlexMath.stretching(
        CGSize(width: 25, height: 10), axis: .horizontal, crossExtent: 80),
      CGSize(width: 25, height: 80))
    XCTAssertEqual(
      RufletFlexMath.stretching(
        CGSize(width: 25, height: 10), axis: .vertical, crossExtent: 80),
      CGSize(width: 80, height: 10))
  }

  func testRotatedBoxQuarterTurnsSwapLayoutAxes() {
    XCTAssertEqual(RotatedQuarterTurnMath.normalized(-1), 3)
    XCTAssertTrue(RotatedQuarterTurnMath.swapsAxes(1))
    XCTAssertFalse(RotatedQuarterTurnMath.swapsAxes(2))
    XCTAssertEqual(
      RotatedQuarterTurnMath.outputSize(
        CGSize(width: 120, height: 40), quarterTurns: 1),
      CGSize(width: 40, height: 120))
  }

  func testPinnedLayoutDefaultsAreNotScreenSpecific() {
    let row = ControlNode(id: 1, type: "Row")
    XCTAssertEqual(row.rufletDouble("spacing"), 10)
    XCTAssertEqual(row.rufletDouble("run_spacing"), 10)
    XCTAssertEqual(row.rufletString("vertical_alignment"), "center")

    let placeholder = ControlNode(id: 2, type: "Placeholder")
    XCTAssertEqual(placeholder.rufletDouble("fallback_width"), 400)
    XCTAssertEqual(placeholder.rufletDouble("fallback_height"), 400)

    let stack = ControlNode(id: 3, type: "Stack")
    XCTAssertEqual(stack.rufletString("clip_behavior"), "hardEdge")
  }
}
