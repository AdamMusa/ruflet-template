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

  func testTimerPickerPreservesFletDurationWireRepresentation() {
    XCTAssertEqual(RufletCupertinoTimerModel.seconds(from: .int(3_661)), 3_661)
    XCTAssertEqual(
      RufletCupertinoTimerModel.seconds(from: .extended(type: 3, string: "P1DT2H3M4S")),
      93_784)
    XCTAssertEqual(
      RufletCupertinoTimerModel.seconds(from: .map([
        "hours": .int(1), "minutes": .int(2), "seconds": .int(3)
      ])),
      3_723)

    XCTAssertEqual(
      RufletCupertinoTimerModel.wireValue(
        seconds: 3_661, preserving: .extended(type: 3, string: "PT0S")),
      .extended(type: 3, string: "PT1H1M1S"))
    XCTAssertEqual(
      RufletCupertinoTimerModel.wireValue(seconds: 61, preserving: .int(0)),
      .int(61))
    XCTAssertEqual(
      RufletCupertinoTimerModel.wireValue(
        seconds: 61, preserving: .map(["seconds": .int(0)])),
      .extended(type: 3, string: "PT0H1M1S"))
  }

  func testDatePickerUsesPinnedFletCupertinoDefaults() {
    let configuration = RufletCupertinoDatePickerConfiguration(
      node: ControlNode(id: 1, type: "CupertinoDatePicker"))

    XCTAssertEqual(configuration.mode, .dateAndTime)
    XCTAssertNil(configuration.order)
    XCTAssertFalse(configuration.showDayOfWeek)
    XCTAssertFalse(configuration.use24HourFormat)
    XCTAssertEqual(configuration.itemExtent, 32)
    XCTAssertEqual(configuration.minuteInterval, 1)
    XCTAssertFalse(configuration.showsWeekday)
  }

  func testDatePickerConsumesDateOrderWeekdayAnd24HourOverrides() {
    let configuration = RufletCupertinoDatePickerConfiguration(
      node: ControlNode(
        id: 1, type: "CupertinoDatePicker",
        props: [
          "date_picker_mode": .string("date"),
          "date_order": .string("dmy"),
          "show_day_of_week": .bool(true),
          "use_24h_format": .bool(true),
          "item_extent": .double(40),
          "minute_interval": .int(15),
          "locale": .string("fr_FR"),
        ]))

    XCTAssertEqual(configuration.mode, .date)
    XCTAssertEqual(configuration.order, .dmy)
    XCTAssertTrue(configuration.showsWeekday)
    XCTAssertTrue(configuration.use24HourFormat)
    XCTAssertEqual(configuration.itemExtent, 40)
    XCTAssertEqual(configuration.minuteInterval, 15)
    XCTAssertTrue(configuration.locale.identifier.contains("en_GB"))
    XCTAssertTrue(configuration.locale.identifier.contains("hours=h23"))

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = calendar.date(from: DateComponents(
      year: 2026, month: 8, day: 11, hour: 10, minute: 43))!
    XCTAssertEqual(calendar.component(.minute, from: configuration.snapped(date, calendar: calendar)), 30)
  }

  func testCupertinoPickerUsesFlutterConstructorDefaults() {
    let configuration = RufletCupertinoPickerConfiguration(
      node: ControlNode(id: 1, type: "CupertinoPicker"))

    XCTAssertEqual(configuration.diameterRatio, 1.07)
    XCTAssertEqual(configuration.magnification, 1)
    XCTAssertEqual(configuration.squeeze, 1.45)
    XCTAssertEqual(configuration.offAxisFraction, 0)
    XCTAssertEqual(configuration.itemExtent, 32)
    XCTAssertFalse(configuration.useMagnifier)
    XCTAssertFalse(configuration.looping)
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
