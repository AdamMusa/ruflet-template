import CoreGraphics
import RufletEngine
@testable import RufletUI
import XCTest

final class DraggableDragTargetResidualParityTests: XCTestCase {
  func testAxisAffinityAndUnlimitedMaximumMatchPinnedDraggable() {
    XCTAssertEqual(RufletDraggableSemantics.axis("horizontal"), .horizontal)
    XCTAssertEqual(RufletDraggableSemantics.axis("VERTICAL"), .vertical)
    XCTAssertNil(RufletDraggableSemantics.axis(nil))
    XCTAssertNil(RufletDraggableSemantics.axis("diagonal"))

    let unlimited = ControlNode(id: 1, type: "Draggable")
    XCTAssertNil(RufletDraggableSemantics.maximumDrags(unlimited))
    XCTAssertTrue(RufletDraggableSemantics.allowsAnotherDrag(maximum: nil, active: 50))
    XCTAssertTrue(RufletDraggableSemantics.allowsAnotherDrag(maximum: 2, active: 1))
    XCTAssertFalse(RufletDraggableSemantics.allowsAnotherDrag(maximum: 2, active: 2))
    XCTAssertFalse(RufletDraggableSemantics.allowsAnotherDrag(maximum: 0, active: 0))
  }

  func testAffinityCompetesOnTheConfiguredAxis() {
    XCTAssertTrue(RufletDraggableSemantics.affinityMatches(
      nil, translation: CGSize(width: 0, height: 20)))
    XCTAssertTrue(RufletDraggableSemantics.affinityMatches(
      "horizontal", translation: CGSize(width: 20, height: 5)))
    XCTAssertFalse(RufletDraggableSemantics.affinityMatches(
      "horizontal", translation: CGSize(width: 5, height: 20)))
    XCTAssertTrue(RufletDraggableSemantics.affinityMatches(
      "vertical", translation: CGSize(width: 5, height: 20)))
  }

  func testNegativeMaximumUsesPinnedValidationMessage() {
    let node = ControlNode(
      id: 1, type: "Draggable",
      props: ["max_simultaneous_drags": .int(-2)])
    XCTAssertEqual(
      RufletDraggableSemantics.validationError(
        node: node, contentID: 2,
        content: ControlNode(id: 2, type: "Container")),
      "max_simultaneous_drags must be greater than or equal to 0, got -2")
  }

  func testTargetGroupPolicyIncludesRejectedCandidates() {
    XCTAssertTrue(RufletDragTargetSemantics.accepts(
      sourceGroup: "default", targetGroup: nil))
    XCTAssertTrue(RufletDragTargetSemantics.accepts(
      sourceGroup: "cards", targetGroup: "cards"))
    XCTAssertFalse(RufletDragTargetSemantics.accepts(
      sourceGroup: "cards", targetGroup: "lists"))
  }

  @MainActor
  func testAxisConstrainedGlobalCoordinatesAndEndAreStable() {
    var endings: [Bool] = []
    let horizontal = RufletDragSession.Active(
      token: "one", sourceID: 4, group: "cards", axis: .horizontal,
      ended: { endings.append($0) })

    XCTAssertEqual(horizontal.globalLocation(CGPoint(x: 10, y: 20)), CGPoint(x: 10, y: 20))
    XCTAssertEqual(horizontal.globalLocation(CGPoint(x: 30, y: 90)), CGPoint(x: 30, y: 20))
    horizontal.finish(accepted: false)
    horizontal.finish(accepted: true)
    XCTAssertEqual(endings, [false])

    let vertical = RufletDragSession.Active(
      token: "two", sourceID: 5, group: "cards", axis: .vertical,
      ended: { _ in })
    XCTAssertEqual(vertical.globalLocation(CGPoint(x: 8, y: 12)), CGPoint(x: 8, y: 12))
    XCTAssertEqual(vertical.globalLocation(CGPoint(x: 80, y: 40)), CGPoint(x: 8, y: 40))
  }
}
