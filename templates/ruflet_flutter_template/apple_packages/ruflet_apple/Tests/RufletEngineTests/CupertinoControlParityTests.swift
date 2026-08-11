import XCTest
@testable import RufletUI
import RufletEngine
import RufletProtocol

final class CupertinoControlParityTests: XCTestCase {
  func testActivityIndicatorUsesCupertinoTwelveSpokeModel() {
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.spokeCount, 12)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: nil), 12)
  }

  func testPartiallyRevealedIndicatorClampsAndRoundsLikeFlet() {
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: -1), 0)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 0), 0)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 0.01), 1)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 0.5), 6)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 1), 12)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: 2), 12)
  }

  func testAppBarUsesPinnedCupertinoConstructorDefaults() {
    let configuration = RufletCupertinoAppBarConfiguration(
      node: ControlNode(id: 1, type: "CupertinoAppBar"))

    XCTAssertFalse(configuration.large)
    XCTAssertTrue(configuration.automaticallyImplyLeading)
    XCTAssertTrue(configuration.automaticallyImplyTitle)
    XCTAssertTrue(configuration.transitionBetweenRoutes)
    XCTAssertTrue(configuration.automaticBackgroundVisibility)
    XCTAssertTrue(configuration.backgroundFilterBlur)
    XCTAssertNil(configuration.previousPageTitle)
    XCTAssertEqual(configuration.height, 44)
  }

  func testLargeAppBarAndExplicitNavigationPropertiesArePreserved() {
    let configuration = RufletCupertinoAppBarConfiguration(
      node: ControlNode(
        id: 1, type: "CupertinoAppBar",
        props: [
          "large": .bool(true),
          "automatically_imply_leading": .bool(false),
          "automatically_imply_title": .bool(false),
          "transition_between_routes": .bool(false),
          "automatic_background_visibility": .bool(false),
          "background_filter_blur": .bool(false),
          "previous_page_title": .string("Gallery"),
        ]))

    XCTAssertTrue(configuration.large)
    XCTAssertFalse(configuration.automaticallyImplyLeading)
    XCTAssertFalse(configuration.automaticallyImplyTitle)
    XCTAssertFalse(configuration.transitionBetweenRoutes)
    XCTAssertFalse(configuration.automaticBackgroundVisibility)
    XCTAssertFalse(configuration.backgroundFilterBlur)
    XCTAssertEqual(configuration.previousPageTitle, "Gallery")
    XCTAssertEqual(configuration.height, 88)
  }

  func testTimerPickerDefaultsToHourMinuteSecondColumns() {
    let columns = RufletCupertinoTimerModel.columns(mode: nil)
    XCTAssertTrue(columns.hours)
    XCTAssertTrue(columns.minutes)
    XCTAssertTrue(columns.seconds)
  }

  func testTimerPickerModesAndIntervalsMatchCupertinoConstructor() {
    let hourMinute = RufletCupertinoTimerModel.columns(mode: "hour_minute")
    XCTAssertTrue(hourMinute.hours)
    XCTAssertTrue(hourMinute.minutes)
    XCTAssertFalse(hourMinute.seconds)

    let minuteSecond = RufletCupertinoTimerModel.columns(mode: "minute_seconds")
    XCTAssertFalse(minuteSecond.hours)
    XCTAssertTrue(minuteSecond.minutes)
    XCTAssertTrue(minuteSecond.seconds)

    XCTAssertEqual(RufletCupertinoTimerModel.values(interval: 15), [0, 15, 30, 45])
    XCTAssertEqual(RufletCupertinoTimerModel.snap(43, interval: 15), 30)
  }

  func testLoopingPickerStartsInMiddleCycleAndMapsBackToRealChild() {
    XCTAssertEqual(CupertinoPickerParity.itemCount(count: 4, looping: false), 4)
    XCTAssertEqual(CupertinoPickerParity.itemCount(count: 4, looping: true), 404)
    XCTAssertEqual(CupertinoPickerParity.initialIndex(selected: 2, count: 4, looping: true), 202)
    XCTAssertEqual(CupertinoPickerParity.realIndex(202, count: 4), 2)
    XCTAssertEqual(CupertinoPickerParity.realIndex(-1, count: 4), 3)
  }

  func testLoopingPickerRecentersOnlyNearFiniteDelegateEdges() {
    XCTAssertTrue(CupertinoPickerParity.shouldRecenter(3, count: 4))
    XCTAssertFalse(CupertinoPickerParity.shouldRecenter(202, count: 4))
    XCTAssertTrue(CupertinoPickerParity.shouldRecenter(400, count: 4))
    XCTAssertFalse(CupertinoPickerParity.shouldRecenter(0, count: 0))
  }
}
