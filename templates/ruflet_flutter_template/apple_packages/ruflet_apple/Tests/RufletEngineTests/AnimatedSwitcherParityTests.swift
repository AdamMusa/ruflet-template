import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class AnimatedSwitcherParityTests: XCTestCase {
  func testPinnedDefaultsAndTransitions() {
    let defaults = AnimatedSwitcherPresentation(
      node: ControlNode(id: 1, type: "AnimatedSwitcher"))
    XCTAssertEqual(defaults.duration, 1)
    XCTAssertEqual(defaults.reverseDuration, 1)
    XCTAssertEqual(defaults.switchInCurve, "linear")
    XCTAssertEqual(defaults.switchOutCurve, "linear")
    XCTAssertEqual(defaults.transition, "fade")

    for (wire, expected) in [
      ("fade", "fade"), ("rotation", "rotation"), ("scale", "scale"),
      ("unknown", "fade"),
    ] {
      let presentation = AnimatedSwitcherPresentation(node: ControlNode(
        id: 2, type: "AnimatedSwitcher", props: ["transition": .string(wire)]))
      XCTAssertEqual(presentation.transition, expected)
    }
  }

  func testDurationParserMatchesFletIntegerSemantics() {
    XCTAssertEqual(
      AnimatedSwitcherPresentation.fletDurationSeconds(nil, default: 1),
      1)
    XCTAssertEqual(
      AnimatedSwitcherPresentation.fletDurationSeconds(.int(250), default: 1),
      0.25)
    XCTAssertEqual(
      AnimatedSwitcherPresentation.fletDurationSeconds(.string("750"), default: 1),
      0.75)
    XCTAssertEqual(
      AnimatedSwitcherPresentation.fletDurationSeconds(.double(2.5), default: 1),
      0)
    XCTAssertEqual(
      AnimatedSwitcherPresentation.fletDurationSeconds(
        .extended(type: 3, string: "1250000"), default: 1),
      1.25)
    XCTAssertEqual(
      AnimatedSwitcherPresentation.fletDurationSeconds(.map([
        "seconds": .int(1), "milliseconds": .int(250),
        "microseconds": .int(500), "minutes": .double(2.5),
      ]), default: 1),
      1.2505)

    let rendered = AnimatedSwitcherPresentation(node: ControlNode(
      id: 8, type: "AnimatedSwitcher", props: [
        "duration": .double(250), "reverse_duration": .double(500),
      ]))
    XCTAssertEqual(rendered.effectiveDuration, 0)
    XCTAssertEqual(rendered.effectiveReverseDuration, 0)
  }

  func testUnknownCurvesUsePinnedLinearFallback() {
    XCTAssertEqual(AnimatedSwitcherPresentation.fletCurve(nil), "linear")
    XCTAssertEqual(AnimatedSwitcherPresentation.fletCurve("easeIn"), "easeIn")
    XCTAssertEqual(AnimatedSwitcherPresentation.fletCurve("BOUNCEOUT"), "BOUNCEOUT")
    XCTAssertEqual(AnimatedSwitcherPresentation.fletCurve("unknown"), "linear")
    // Flutter's parser lowercases tokens but does not remove separators.
    XCTAssertEqual(AnimatedSwitcherPresentation.fletCurve("ease_in"), "linear")
  }

  func testContentMustExistAndRemainVisible() {
    let missing = AnimatedSwitcherPresentation(
      node: ControlNode(id: 3, type: "AnimatedSwitcher"))
    XCTAssertEqual(
      missing.validationError(content: nil),
      "AnimatedSwitcher.content must be provided and visible")

    let presentation = AnimatedSwitcherPresentation(node: ControlNode(
      id: 4, type: "AnimatedSwitcher", props: ["content": .controlRef(8)]))
    XCTAssertEqual(
      presentation.validationError(content: ControlNode(
        id: 8, type: "Text", props: ["visible": .bool(false)])),
      AnimatedSwitcherPresentation.missingContentError)
    XCTAssertNil(presentation.validationError(content: ControlNode(id: 8, type: "Text")))
  }

  func testIdentityTracksContentAndEveryParentRevision() {
    XCTAssertNotEqual(
      AnimatedSwitcherIdentity(controlID: 8, revision: 1),
      AnimatedSwitcherIdentity(controlID: 8, revision: 2))
    XCTAssertNotEqual(
      AnimatedSwitcherIdentity(controlID: 8, revision: 1),
      AnimatedSwitcherIdentity(controlID: 9, revision: 1))
  }
}
