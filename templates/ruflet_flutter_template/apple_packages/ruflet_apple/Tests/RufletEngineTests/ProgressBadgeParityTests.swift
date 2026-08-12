@testable import RufletUI
import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

/// Translated contracts from Flet 0.80.5's `utils/badge.dart`,
/// `progress_bar.dart`, and `progress_ring.dart`, plus the pinned Flutter
/// widgets those files instantiate.
final class ProgressBadgeParityTests: XCTestCase {
  func testUnstyledProgressControlsUseNativeAppleAppearance() {
    let linear = ControlNode(
      id: 1, type: "ProgressBar",
      props: ["value": .double(0.5), "semantics_label": .string("Loading")])
    let circular = ControlNode(id: 2, type: "ProgressRing")
    XCTAssertTrue(RufletProgressAppearance.usesNativeLinear(linear))
    XCTAssertTrue(RufletProgressAppearance.usesNativeCircular(circular))

    XCTAssertFalse(RufletProgressAppearance.usesNativeLinear(ControlNode(
      id: 3, type: "ProgressBar", props: ["bar_height": .double(8)])))
    XCTAssertFalse(RufletProgressAppearance.usesNativeCircular(ControlNode(
      id: 4, type: "ProgressRing", props: ["stroke_width": .double(8)])))

    XCTAssertTrue(RufletProgressAppearance.usesNativeLinear(ControlNode(
      id: 5, type: "ProgressBar", props: ["bar_height": .null])))
    XCTAssertTrue(RufletProgressAppearance.usesNativeCircular(ControlNode(
      id: 6, type: "ProgressRing", props: ["padding": .null])))
  }

  func testCircleAvatarContentAcceptsFletScalarOrControlProviders() {
    XCTAssertEqual(
      RufletCircleAvatarContent(node: ControlNode(
        id: 1, type: "CircleAvatar", props: ["content": .string("AM")])),
      .text("AM"))
    XCTAssertEqual(
      RufletCircleAvatarContent(node: ControlNode(
        id: 2, type: "CircleAvatar", props: ["content": .int(42)])),
      .text("42"))
    XCTAssertEqual(
      RufletCircleAvatarContent(node: ControlNode(
        id: 3, type: "CircleAvatar", props: ["content": .controlRef(9)])),
      .control(9))
    XCTAssertEqual(
      RufletCircleAvatarContent(node: ControlNode(id: 4, type: "CircleAvatar")),
      .empty)
  }

  func testNativeProgressControlsKeepFletThemeTokens() {
    for type in ["ProgressBar", "ProgressRing"] {
      let node = ControlNode(id: 1, type: type)
      XCTAssertEqual(
        RufletThemeDefaults.resolvedColorToken(for: node, property: "color"),
        "primary", type)
      XCTAssertEqual(
        RufletThemeDefaults.resolvedColorToken(for: node, property: "bgcolor"),
        "secondarycontainer", type)
    }
  }

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

  func testBadgeDefaultsUsePinnedFlutterThemeRoles() {
    let defaults = ControlNode(id: 1, type: "Badge")
    XCTAssertEqual(RufletBadgeSemantics.backgroundColor(defaults), "error")
    XCTAssertEqual(RufletBadgeSemantics.textColor(defaults), "onerror")

    let explicit = ControlNode(
      id: 2, type: "Badge",
      props: ["bgcolor": .string("blue"), "text_color": .string("yellow")])
    XCTAssertEqual(RufletBadgeSemantics.backgroundColor(explicit), "blue")
    XCTAssertEqual(RufletBadgeSemantics.textColor(explicit), "yellow")

    let blanks = ControlNode(
      id: 3, type: "Badge",
      props: ["bgcolor": .string("  "), "text_color": .string("")])
    XCTAssertEqual(RufletBadgeSemantics.backgroundColor(blanks), "error")
    XCTAssertEqual(RufletBadgeSemantics.textColor(blanks), "onerror")
  }

  func testBadgeDefaultOffsetFollowsFlutterTextDirection() {
    let badge = ControlNode(id: 1, type: "Badge", props: ["label": .string("1")])
    XCTAssertEqual(
      RufletBadgeSemantics.markerOffset(badge, layoutDirection: .leftToRight),
      CGSize(width: 4, height: -4))
    XCTAssertEqual(
      RufletBadgeSemantics.markerOffset(badge, layoutDirection: .rightToLeft),
      CGSize(width: -4, height: -4))

    let explicit = ControlNode(
      id: 2, type: "Badge",
      props: [
        "label": .string("1"),
        "offset": .map(["x": .double(7), "y": .double(3)])
      ])
    XCTAssertEqual(
      RufletBadgeSemantics.markerOffset(explicit, layoutDirection: .rightToLeft),
      CGSize(width: 7, height: 3))
  }

  func testDotBadgeIgnoresLabelOffsets() {
    let dot = ControlNode(
      id: 1, type: "Badge",
      props: ["offset": .map(["x": .double(7), "y": .double(3)])])
    XCTAssertEqual(
      RufletBadgeSemantics.markerOffset(dot, layoutDirection: .leftToRight),
      .zero)
    XCTAssertEqual(
      RufletBadgeSemantics.markerOffset(dot, layoutDirection: .rightToLeft),
      .zero)
  }

  func testProgressRingAcceptsRubyAndSerializedFletWireKeys() {
    let fletKey = RufletCircularProgressMetrics(node: ControlNode(
      id: 1, type: "ProgressRing", props: ["year2023": .bool(false)]))
    let rubyKey = RufletCircularProgressMetrics(node: ControlNode(
      id: 2, type: "ProgressRing", props: ["year_2023": .bool(false)]))

    XCTAssertEqual(fletKey.strokeAlign, -1)
    XCTAssertEqual(fletKey.width, 40)
    XCTAssertEqual(rubyKey.strokeAlign, -1)
    XCTAssertEqual(rubyKey.width, 40)

    let precedence = RufletCircularProgressMetrics(node: ControlNode(
      id: 3, type: "ProgressRing",
      props: ["year_2023": .bool(true), "year2023": .bool(false)]))
    XCTAssertEqual(precedence.strokeAlign, 0)
    XCTAssertEqual(precedence.width, 36)
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

  func testLinearProgressGapRampsInAcrossTheFirstPercent() {
    func metrics(_ value: Double) -> RufletLinearProgressMetrics {
      RufletLinearProgressMetrics(node: ControlNode(
        id: 1, type: "ProgressBar",
        props: ["value": .double(value), "year_2023": .bool(false)]))
    }

    XCTAssertEqual(metrics(0).effectiveTrackGap, 0)
    XCTAssertEqual(metrics(0.005).effectiveTrackGap, 2, accuracy: 0.0001)
    XCTAssertEqual(metrics(0.01).effectiveTrackGap, 4, accuracy: 0.0001)
    XCTAssertEqual(metrics(1).trackOrigin(in: 100), 100)
  }
}
