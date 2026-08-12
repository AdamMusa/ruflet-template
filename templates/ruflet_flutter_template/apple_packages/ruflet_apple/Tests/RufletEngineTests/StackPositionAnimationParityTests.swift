import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

/// Translated from Flet's `_positionedControl` / Flutter AnimatedPositioned
/// contract. These tests cover wire semantics without requiring a simulator.
final class StackPositionAnimationParityTests: XCTestCase {
  func testAnimatedPositionDefaultsToTopLeftWhenEveryInsetIsOmitted() {
    let semantics = RufletPositionAnimationSemantics(ControlNode(
      id: 1, type: "Container",
      props: ["animate_position": .int(250)]))

    XCTAssertEqual(
      semantics.position,
      RufletPositionState(left: 0, top: 0, right: nil, bottom: nil))
    XCTAssertEqual(semantics.duration, 0.25)
    XCTAssertNotNil(semantics.animation)
  }

  func testAnyExplicitInsetSuppressesAnimatedPositionTopLeftDefaults() {
    let semantics = RufletPositionAnimationSemantics(ControlNode(
      id: 2, type: "Container",
      props: [
        "animate_position": .map(["duration": .int(400), "curve": .string("easeIn")]),
        "right": .double(12), "bottom": .double(8),
      ]))

    XCTAssertEqual(
      semantics.position,
      RufletPositionState(left: nil, top: nil, right: 12, bottom: 8))
    XCTAssertEqual(semantics.duration, 0.4)
  }

  func testStaticPositionHasNoAnimationOrCompletionDuration() {
    let semantics = RufletPositionAnimationSemantics(ControlNode(
      id: 3, type: "Container", props: ["left": .double(7)]))

    XCTAssertEqual(
      semantics.position,
      RufletPositionState(left: 7, top: nil, right: nil, bottom: nil))
    XCTAssertNil(semantics.animation)
    XCTAssertNil(semantics.duration)
  }

  func testCompletionUsesPinnedAnimationEndPayloadAndHandlerGating() {
    var sent: [(Int, String, RufletValue)] = []
    let sink = RufletEventSink(send: { sent.append(($0, $1, $2)) })
    let listened = ControlNode(
      id: 4, type: "Container",
      props: ["on_animation_end": .bool(true)])
    let silent = ControlNode(id: 5, type: "Container")

    RufletPositionAnimationSemantics.reportCompletion(listened, to: sink)
    RufletPositionAnimationSemantics.reportCompletion(silent, to: sink)

    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent.first?.0, 4)
    XCTAssertEqual(sent.first?.1, "animation_end")
    XCTAssertEqual(sent.first?.2, .string("position"))
  }
}
