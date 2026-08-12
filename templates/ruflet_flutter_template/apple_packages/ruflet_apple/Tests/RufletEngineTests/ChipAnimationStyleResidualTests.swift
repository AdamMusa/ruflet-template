import RufletEngine
@testable import RufletUI
import XCTest

final class ChipAnimationStyleResidualTests: XCTestCase {
  func testEveryChipAnimationPhaseConsumesForwardAndReverseStyle() throws {
    let properties: [(ChipAnimationPhase, String)] = [
      (.enable, "enable_animation_style"),
      (.select, "select_animation_style"),
      (.leadingDrawer, "leading_drawer_animation_style"),
      (.deleteDrawer, "delete_drawer_animation_style"),
    ]

    for (phase, property) in properties {
      let node = ControlNode(id: 1, type: "Chip", props: [
        property: .map([
          "duration": .double(120),
          "curve": .string("easeIn"),
          "reverse_duration": .double(75),
          "reverse_curve": .string("easeOut"),
        ]),
      ])

      XCTAssertEqual(
        ChipPresentation.animationTiming(node, phase: phase, forward: true),
        ChipAnimationTiming(durationMilliseconds: 120, curveToken: "easeIn"),
        property)
      XCTAssertEqual(
        ChipPresentation.animationTiming(node, phase: phase, forward: false),
        ChipAnimationTiming(durationMilliseconds: 75, curveToken: "easeOut"),
        property)
    }
  }

  func testReverseChipAnimationFallsBackToForwardFields() {
    let node = ControlNode(id: 1, type: "Chip", props: [
      "select_animation_style": .map([
        "duration": .double(180), "curve": .string("linear"),
      ]),
    ])

    XCTAssertEqual(
      ChipPresentation.animationTiming(node, phase: .select, forward: false),
      ChipAnimationTiming(durationMilliseconds: 180, curveToken: "linear"))
  }

  func testZeroDurationPreservesNoAnimationStyle() {
    let node = ControlNode(id: 1, type: "Chip", props: [
      "enable_animation_style": .map([
        "duration": .double(0), "reverse_duration": .double(0),
      ]),
    ])

    XCTAssertEqual(
      ChipPresentation.animationTiming(node, phase: .enable, forward: true)?.durationMilliseconds,
      0)
    XCTAssertEqual(
      ChipPresentation.animationTiming(node, phase: .enable, forward: false)?.durationMilliseconds,
      0)
  }

  func testSelectedShadowStillOverridesAndFallsBackToOrdinaryShadow() {
    let override = ControlNode(id: 1, type: "Chip", props: [
      "shadow_color": .string("grey"),
      "selected_shadow_color": .string("red"),
    ])
    let fallback = ControlNode(id: 2, type: "Chip", props: [
      "shadow_color": .string("grey"),
    ])

    XCTAssertEqual(ChipPresentation.shadowColorToken(override, selected: true), "red")
    XCTAssertEqual(ChipPresentation.shadowColorToken(fallback, selected: true), "grey")
    XCTAssertEqual(ChipPresentation.shadowColorToken(override, selected: false), "grey")
  }
}
