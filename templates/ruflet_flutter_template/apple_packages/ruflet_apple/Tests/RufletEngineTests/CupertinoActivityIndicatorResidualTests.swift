import XCTest
@testable import RufletUI
import RufletEngine
import RufletProtocol

final class CupertinoActivityIndicatorResidualTests: XCTestCase {
  func testPinnedCupertinoTickColorsAndAlphaTrail() {
    XCTAssertEqual(RufletCupertinoActivityIndicatorDefaults.lightTickRGB, 0x3C3C44)
    XCTAssertEqual(RufletCupertinoActivityIndicatorDefaults.darkTickRGB, 0xEBEBF5)
    XCTAssertEqual(
      RufletCupertinoActivityIndicatorMetrics.tickAlphaValues,
      [47, 47, 47, 47, 72, 97, 122, 147])

    for index in 0..<RufletCupertinoActivityIndicatorMetrics.tickCount {
      XCTAssertEqual(
        RufletCupertinoActivityIndicatorMetrics.tickOpacity(index: index, progress: 0.875),
        147.0 / 255.0,
        accuracy: 0.000_001)
      XCTAssertEqual(
        RufletCupertinoActivityIndicatorMetrics.tickOpacity(index: index, progress: 1),
        Double(RufletCupertinoActivityIndicatorMetrics.tickAlphaValues[index]) / 255,
        accuracy: 0.000_001)
    }
  }

  func testLivePropertiesRecomputeModeColorAndAnimatingPrecedence() {
    let running = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoActivityIndicator",
        props: ["color": .string("red")]))
    XCTAssertEqual(running.colorToken, "red")
    XCTAssertEqual(running.mode, .indeterminate(animating: true))
    XCTAssertNil(running.validationError)

    let stopped = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoActivityIndicator",
        props: [
          "color": .string("blue"),
          "animating": .bool(false),
        ]))
    XCTAssertEqual(stopped.colorToken, "blue")
    XCTAssertEqual(stopped.mode, .indeterminate(animating: false))

    let revealed = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoActivityIndicator",
        props: [
          "animating": .bool(true),
          "progress": .double(0.25),
        ]))
    XCTAssertEqual(revealed.mode, .partiallyRevealed(progress: 0.25))
  }

  func testPinnedConstructorBoundsAreValidatedBeforeNativeRendering() {
    let zeroRadius = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoActivityIndicator",
        props: ["radius": .double(0)]))
    XCTAssertEqual(
      zeroRadius.validationError,
      "CupertinoActivityIndicator.radius must be greater than 0")

    let nonFiniteRadius = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoActivityIndicator",
        props: ["radius": .double(.infinity)]))
    XCTAssertEqual(
      nonFiniteRadius.validationError,
      "CupertinoActivityIndicator.radius must be greater than 0")

    for progress in [-0.01, 1.01, Double.infinity] {
      let presentation = RufletCupertinoActivityIndicatorPresentation(
        node: ControlNode(
          id: 1, type: "CupertinoActivityIndicator",
          props: ["progress": .double(progress)]))
      XCTAssertEqual(
        presentation.validationError,
        "CupertinoActivityIndicator.progress must be between 0 and 1")
    }

    for progress in [0.0, 1.0] {
      let presentation = RufletCupertinoActivityIndicatorPresentation(
        node: ControlNode(
          id: 1, type: "CupertinoActivityIndicator",
          props: ["progress": .double(progress)]))
      XCTAssertNil(presentation.validationError)
    }
  }
}
