import XCTest
import RufletEngine
import RufletProtocol
@testable import RufletUI

final class ChipPressElevationParityTests: XCTestCase {
  func testPressedElevationOverridesRestingElevationOnlyDuringEnabledPress() {
    let node = ControlNode(
      id: 1, type: "Chip",
      props: [
        "elevation": .double(2),
        "elevation_on_click": .double(7),
        "shadow_color": .string("black"),
      ])

    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        node, selected: false, pressed: false, enabled: true),
      ChipShadowPresentation(elevation: 2, colorToken: "black"))
    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        node, selected: false, pressed: true, enabled: true),
      ChipShadowPresentation(elevation: 7, colorToken: "black"))
  }

  func testDisabledChipNeverAppliesPressElevation() {
    let node = ControlNode(
      id: 2, type: "Chip",
      props: ["elevation": .double(3), "elevation_on_click": .double(9)])

    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        node, selected: false, pressed: true, enabled: false).elevation,
      3)
  }

  func testMissingPressElevationKeepsNormalNativeShadow() {
    let node = ControlNode(
      id: 3, type: "Chip", props: ["elevation": .double(4)])

    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        node, selected: false, pressed: true, enabled: true).elevation,
      4)
  }

  func testPressOnlyElevationDoesNotCreateARestingShadow() {
    let node = ControlNode(
      id: 7, type: "Chip", props: ["elevation_on_click": .double(6)])

    XCTAssertNil(
      ChipPresentation.shadowPresentation(
        node, selected: false, pressed: false, enabled: true).elevation)
    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        node, selected: false, pressed: true, enabled: true).elevation,
      6)
  }

  func testSelectedShadowOverridesNormalShadowWithFletFallback() {
    let explicit = ControlNode(
      id: 4, type: "Chip",
      props: [
        "shadow_color": .string("grey"),
        "selected_shadow_color": .string("purple"),
      ])
    let fallback = ControlNode(
      id: 5, type: "Chip", props: ["shadow_color": .string("grey")])

    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        explicit, selected: true, pressed: false, enabled: true).colorToken,
      "purple")
    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        fallback, selected: true, pressed: false, enabled: true).colorToken,
      "grey")
  }

  func testStylelessChipDoesNotInventAShadow() {
    let node = ControlNode(id: 6, type: "Chip")
    XCTAssertEqual(
      ChipPresentation.shadowPresentation(
        node, selected: false, pressed: true, enabled: true),
      ChipShadowPresentation(elevation: nil, colorToken: nil))
  }
}
