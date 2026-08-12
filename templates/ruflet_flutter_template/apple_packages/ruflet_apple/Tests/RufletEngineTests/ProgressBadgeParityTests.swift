@testable import RufletUI
import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

/// Translated contracts from Flet 0.80.5's `utils/badge.dart`,
/// `progress_bar.dart`, and `progress_ring.dart`, plus the pinned Flutter
/// widgets those files instantiate.
final class ProgressBadgeParityTests: XCTestCase {
  func testBadgeVisibilityAndMissingLabelAreDifferentStates() {
    let hidden = ControlNode(
      id: 1, type: "Badge", props: ["label_visible": .bool(false)])
    let dot = ControlNode(id: 2, type: "Badge")
    let labelled = ControlNode(
      id: 3, type: "Badge", props: ["label": .controlRef(9)])
    let nullLabel = ControlNode(
      id: 4, type: "Badge", props: ["label": .null])

    XCTAssertFalse(RufletBadgeSemantics.isVisible(hidden))
    XCTAssertTrue(RufletBadgeSemantics.isVisible(dot))
    XCTAssertFalse(RufletBadgeSemantics.hasLabel(dot))
    XCTAssertTrue(RufletBadgeSemantics.hasLabel(labelled))
    XCTAssertFalse(RufletBadgeSemantics.hasLabel(nullLabel))
  }

  func testBadgeDefaultsUseFlutterMaterialColorRoles() {
    let defaults = ControlNode(id: 1, type: "Badge")
    XCTAssertEqual(RufletBadgeSemantics.backgroundColor(defaults), "error")
    XCTAssertEqual(RufletBadgeSemantics.textColor(defaults), "onerror")

    let explicit = ControlNode(
      id: 2, type: "Badge",
      props: ["bgcolor": .string("blue"), "text_color": .string("yellow")])
    XCTAssertEqual(RufletBadgeSemantics.backgroundColor(explicit), "blue")
    XCTAssertEqual(RufletBadgeSemantics.textColor(explicit), "yellow")
  }

  func testBadgeDefaultOffsetFollowsFlutterTextDirection() {
    let badge = ControlNode(id: 1, type: "Badge")
    XCTAssertEqual(
      RufletBadgeSemantics.offset(badge, layoutDirection: .leftToRight),
      CGSize(width: 4, height: -4))
    XCTAssertEqual(
      RufletBadgeSemantics.offset(badge, layoutDirection: .rightToLeft),
      CGSize(width: -4, height: -4))

    let explicit = ControlNode(
      id: 2, type: "Badge",
      props: ["offset": .map(["x": .double(7), "y": .double(3)])])
    XCTAssertEqual(
      RufletBadgeSemantics.offset(explicit, layoutDirection: .rightToLeft),
      CGSize(width: 7, height: 3))
  }

  func testProgressRingUsesTheExactFletWireKey() {
    let fletKey = RufletCircularProgressMetrics(node: ControlNode(
      id: 1, type: "ProgressRing", props: ["year2023": .bool(false)]))
    let progressBarKey = RufletCircularProgressMetrics(node: ControlNode(
      id: 2, type: "ProgressRing", props: ["year_2023": .bool(false)]))

    XCTAssertEqual(fletKey.strokeAlign, -1)
    XCTAssertEqual(fletKey.width, 40)
    XCTAssertEqual(progressBarKey.strokeAlign, 0)
    XCTAssertEqual(progressBarKey.width, 36)
  }

  func testCircularIndicatorPreservesIndependentBoxConstraintAxes() {
    let metrics = RufletCircularProgressMetrics(node: ControlNode(
      id: 1, type: "ProgressRing",
      props: [
        "size_constraints": .map([
          "min_width": .double(64), "min_height": .double(48)
        ])
      ]))

    XCTAssertEqual(metrics.width, 64)
    XCTAssertEqual(metrics.height, 48)
    XCTAssertEqual(metrics.diameter, 48)
  }

  func testProgressSemanticsMatchesFlutterStrings() {
    let node = ControlNode(
      id: 1, type: "ProgressBar",
      props: [
        "value": .double(0.256),
        "semantics_label": .string("Uploading")
      ])
    XCTAssertEqual(RufletProgressSemantics.label(node), "Uploading")
    XCTAssertEqual(RufletProgressSemantics.spokenValue(node), "26")

    let clamped = ControlNode(
      id: 2, type: "ProgressBar", props: ["value": .double(5)])
    XCTAssertEqual(RufletProgressSemantics.spokenValue(clamped), "100")
  }
}
