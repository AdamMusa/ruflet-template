import XCTest
import RufletEngine
import RufletProtocol
@testable import RufletUI

final class CupertinoSliderNativeParityTests: XCTestCase {
  func testOmittedDivisionsRemainContinuous() {
    let presentation = CupertinoSliderPresentation(
      node: ControlNode(id: 1, type: "CupertinoSlider"))
    let configuration = CupertinoSliderNativeConfiguration(presentation)

    XCTAssertNil(configuration.divisions)
    XCTAssertNil(configuration.step)
    XCTAssertEqual(configuration.snapped(0.123456), 0.123456)
  }

  func testDivisionsSnapToFletCupertinoStopsRelativeToMinimum() {
    let presentation = CupertinoSliderPresentation(
      node: ControlNode(
        id: 2, type: "CupertinoSlider",
        props: [
          "min": .double(10), "max": .double(30),
          "divisions": .int(4),
        ]))
    let configuration = CupertinoSliderNativeConfiguration(presentation)

    XCTAssertEqual(configuration.step, 5)
    XCTAssertEqual(configuration.snapped(11), 10)
    XCTAssertEqual(configuration.snapped(13), 15)
    XCTAssertEqual(configuration.snapped(29), 30)
  }

  func testInvalidDivisionsRetainContinuousNativeSlider() {
    for divisions in [0, -1] {
      let presentation = CupertinoSliderPresentation(
        node: ControlNode(
          id: divisions, type: "CupertinoSlider",
          props: ["divisions": .int(Int64(divisions))]))
      XCTAssertNil(CupertinoSliderNativeConfiguration(presentation).step)
    }
  }

  func testNativeConfigurationClampsValuesAtBothEnds() {
    let presentation = CupertinoSliderPresentation(
      node: ControlNode(
        id: 3, type: "CupertinoSlider",
        props: ["min": .double(-2), "max": .double(2)]))
    let configuration = CupertinoSliderNativeConfiguration(presentation)

    XCTAssertEqual(configuration.snapped(-20), -2)
    XCTAssertEqual(configuration.snapped(20), 2)
  }

  func testEqualFletRangeDisablesInteractionWithoutChangingItsValue() {
    let presentation = CupertinoSliderPresentation(
      node: ControlNode(
        id: 6, type: "CupertinoSlider",
        props: ["min": .double(4), "max": .double(4), "value": .double(4)]))
    let configuration = CupertinoSliderNativeConfiguration(presentation)

    XCTAssertFalse(presentation.hasSelectableRange)
    XCTAssertEqual(presentation.maximum, 4)
    XCTAssertEqual(presentation.value, 4)
    XCTAssertEqual(configuration.minimum, 4)
    XCTAssertEqual(configuration.maximum, 4)
  }

  func testCupertinoThumbColorKeepsWhiteDefaultAndExplicitWireValue() {
    XCTAssertEqual(
      CupertinoSliderPresentation(
        node: ControlNode(id: 4, type: "CupertinoSlider")).thumbColorName,
      "white")
    XCTAssertEqual(
      CupertinoSliderPresentation(
        node: ControlNode(
          id: 5, type: "CupertinoSlider",
          props: ["thumb_color": .string("red")])).thumbColorName,
      "red")
  }
}
