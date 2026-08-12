import XCTest
@testable import RufletUI
import RufletEngine
import RufletProtocol

final class CupertinoControlParityTests: XCTestCase {
  func testActivityIndicatorUsesPinnedConstructorDefaultsAndNativeMode() {
    let presentation = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(id: 1, type: "CupertinoActivityIndicator"))

    XCTAssertEqual(presentation.radius, 10)
    XCTAssertEqual(presentation.diameter, 20)
    XCTAssertNil(presentation.colorToken)
    XCTAssertEqual(presentation.mode, .indeterminate(animating: true))
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.tickCount, 8)
  }

  func testPartiallyRevealedIndicatorClampsAndRoundsLikePinnedFlutter() {
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.clamped(-1), 0)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.clamped(2), 1)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: -1), 0)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: 0), 0)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: 0.01), 1)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: 0.5), 4)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: 1), 8)
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: 2), 8)
  }

  func testProgressSelectsStaticModeAndIgnoresAnimating() {
    let presentation = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoActivityIndicator",
        props: [
          "radius": .double(14),
          "color": .string("red"),
          "animating": .bool(true),
          "progress": .double(0.625),
        ]))

    XCTAssertEqual(presentation.radius, 14)
    XCTAssertEqual(presentation.diameter, 28)
    XCTAssertEqual(presentation.colorToken, "red")
    XCTAssertEqual(presentation.mode, .partiallyRevealed(progress: 0.625))
    XCTAssertEqual(RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: 0.625), 5)
  }

  func testAnimatingFalseKeepsNativeIndicatorMountedButStopped() {
    let presentation = RufletCupertinoActivityIndicatorPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoActivityIndicator",
        props: ["animating": .bool(false)]))
    XCTAssertEqual(presentation.mode, .indeterminate(animating: false))
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

    let configuration = RufletCupertinoTimerPickerConfiguration(
      node: ControlNode(id: 1, type: "CupertinoTimerPicker"))
    XCTAssertEqual(configuration.mode, "hms")
    XCTAssertEqual(configuration.minuteInterval, 1)
    XCTAssertEqual(configuration.secondInterval, 1)
    XCTAssertEqual(configuration.itemExtent, 32)
    XCTAssertEqual(configuration.alignment, .center)
    XCTAssertEqual(configuration.seconds, 0)
    XCTAssertFalse(configuration.disabled)
    XCTAssertNil(configuration.backgroundToken)
    XCTAssertNil(configuration.validationMessage)
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
      RufletCupertinoTimerModel.seconds(from: .extended(type: 3, string: "93784000000")),
      93_784)
    // Accept the pre-Flet-native Ruflet payload during session migration.
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
        seconds: 3_661, preserving: .extended(type: 3, string: "0")),
      .extended(type: 3, string: "3661000000"))
    XCTAssertEqual(
      RufletCupertinoTimerModel.wireValue(seconds: 61, preserving: .int(0)),
      .int(61))
    XCTAssertEqual(
      RufletCupertinoTimerModel.wireValue(
        seconds: 61, preserving: .map(["seconds": .int(0)])),
      .extended(type: 3, string: "61000000"))
  }

  func testTimerPickerValidatesIntervalsDurationAndItemExtent() {
    XCTAssertNotNil(RufletCupertinoTimerPickerConfiguration(node: ControlNode(
      id: 1, type: "CupertinoTimerPicker", props: ["value": .int(86_400)])).validationMessage)
    XCTAssertNotNil(RufletCupertinoTimerPickerConfiguration(node: ControlNode(
      id: 1, type: "CupertinoTimerPicker", props: ["minute_interval": .int(7)])).validationMessage)
    XCTAssertNotNil(RufletCupertinoTimerPickerConfiguration(node: ControlNode(
      id: 1, type: "CupertinoTimerPicker", props: ["second_interval": .int(7)])).validationMessage)
    XCTAssertNotNil(RufletCupertinoTimerPickerConfiguration(node: ControlNode(
      id: 1, type: "CupertinoTimerPicker", props: ["item_extent": .double(0)])).validationMessage)
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
    XCTAssertEqual(configuration.minimumYear, 1)
    XCTAssertNil(configuration.maximumYear)
    XCTAssertNil(configuration.firstDate)
    XCTAssertNil(configuration.lastDate)
    XCTAssertFalse(configuration.disabled)
    XCTAssertNil(configuration.backgroundToken)
    XCTAssertFalse(configuration.showsWeekday)
    XCTAssertNil(configuration.validationMessage(value: Date()))
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

  func testDatePickerUsesFletDateTimeExtensionAndUpdateBeforeChange() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = calendar.date(from: DateComponents(
      year: 2026, month: 8, day: 12, hour: 3, minute: 30, second: 45))!
    let wire = RufletCupertinoDateCodec.wireValue(date)
    guard case .extended(type: 1, let payload) = wire else {
      return XCTFail("expected Flet DateTime extension")
    }
    XCTAssertTrue(payload.hasSuffix("+00:00"))
    XCTAssertEqual(RufletCupertinoDateCodec.date(from: wire), date)

    let node = ControlNode(
      id: 5, type: "CupertinoDatePicker", props: ["on_change": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, data in
        if case .extended(let type, _) = data { calls.append("event:\(name):\(type)") }
      },
      setLocal: { _, key, _ in calls.append("local:\(key)") },
      update: { _, props in calls.append("update:\(props.keys.sorted().joined(separator: ","))") })
    RufletCupertinoDatePickerEvents.change(date, on: node, to: sink)
    XCTAssertEqual(calls, ["local:value", "update:value", "event:change:1"])
  }

  func testTimerPickerUsesFletDurationExtensionAndUpdateBeforeChange() {
    let node = ControlNode(
      id: 6, type: "CupertinoTimerPicker",
      props: [
        "value": .extended(type: 3, string: "0"),
        "on_change": .bool(true),
      ])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, data in
        if case .extended(let type, let payload) = data {
          calls.append("event:\(name):\(type):\(payload)")
        }
      },
      setLocal: { _, key, _ in calls.append("local:\(key)") },
      update: { _, props in calls.append("update:\(props.keys.sorted().joined(separator: ","))") })
    RufletCupertinoTimerPickerEvents.change(
      seconds: 61, preserving: node.props["value"], on: node, to: sink)
    XCTAssertEqual(calls, [
      "local:value", "update:value", "event:change:3:61000000",
    ])
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
    XCTAssertEqual(configuration.selectedIndex, 0)
    XCTAssertFalse(configuration.disabled)
    XCTAssertNil(configuration.backgroundToken)
    XCTAssertNil(configuration.defaultSelectionOverlayToken)
    XCTAssertNil(configuration.validationMessage)
    XCTAssertEqual(RufletCupertinoPickerDefaults.overlayHorizontalMargin, 9)
    XCTAssertEqual(RufletCupertinoPickerDefaults.overlayCornerRadius, 8)
  }

  func testCupertinoPickerPreservesGeometryColorAndDisabledSemantics() {
    let configuration = RufletCupertinoPickerConfiguration(
      node: ControlNode(
        id: 1, type: "CupertinoPicker",
        props: [
          "diameter_ratio": .double(2.4),
          "magnification": .double(1.2),
          "squeeze": .double(1.8),
          "off_axis_fraction": .double(-0.25),
          "item_extent": .double(44),
          "use_magnifier": .bool(true),
          "looping": .bool(true),
          "selected_index": .int(3),
          "disabled": .bool(true),
          "bgcolor": .string("blue"),
          "default_selection_overlay_bgcolor": .string("red"),
        ]))

    XCTAssertEqual(configuration.diameterRatio, 2.4)
    XCTAssertEqual(configuration.magnification, 1.2)
    XCTAssertEqual(configuration.squeeze, 1.8)
    XCTAssertEqual(configuration.offAxisFraction, -0.25)
    XCTAssertEqual(configuration.itemExtent, 44)
    XCTAssertTrue(configuration.useMagnifier)
    XCTAssertTrue(configuration.looping)
    XCTAssertEqual(configuration.selectedIndex, 3)
    XCTAssertTrue(configuration.disabled)
    XCTAssertEqual(configuration.backgroundToken, "blue")
    XCTAssertEqual(configuration.defaultSelectionOverlayToken, "red")
  }

  func testCupertinoPickerReportsPinnedPositiveValueValidation() {
    XCTAssertEqual(
      RufletCupertinoPickerConfiguration(node: ControlNode(
        id: 1, type: "CupertinoPicker", props: ["squeeze": .double(0)])).validationMessage,
      "squeeze must be strictly greater than 0.0, got 0.0")
    XCTAssertEqual(
      RufletCupertinoPickerConfiguration(node: ControlNode(
        id: 1, type: "CupertinoPicker", props: ["magnification": .double(-1)])).validationMessage,
      "magnification must be strictly greater than 0.0, got -1.0")
    XCTAssertEqual(
      RufletCupertinoPickerConfiguration(node: ControlNode(
        id: 1, type: "CupertinoPicker", props: ["item_extent": .double(0)])).validationMessage,
      "item_extent must be strictly greater than 0.0, got 0.0")
    XCTAssertNotNil(
      RufletCupertinoPickerConfiguration(node: ControlNode(
        id: 1, type: "CupertinoPicker", props: ["diameter_ratio": .double(0)])).validationMessage)
  }

  func testLoopingPickerStartsInMiddleCycleAndMapsBackToRealChild() {
    XCTAssertEqual(CupertinoPickerParity.itemCount(count: 4, looping: false), 4)
    XCTAssertEqual(CupertinoPickerParity.itemCount(count: 4, looping: true), 404)
    XCTAssertEqual(CupertinoPickerParity.initialIndex(selected: 2, count: 4, looping: true), 202)
    XCTAssertEqual(CupertinoPickerParity.initialIndex(selected: 6, count: 4, looping: false), 6)
    XCTAssertEqual(CupertinoPickerParity.realIndex(202, count: 4), 2)
    XCTAssertEqual(CupertinoPickerParity.realIndex(-1, count: 4), 3)
  }

  func testLoopingPickerRecentersOnlyNearFiniteDelegateEdges() {
    XCTAssertTrue(CupertinoPickerParity.shouldRecenter(3, count: 4))
    XCTAssertFalse(CupertinoPickerParity.shouldRecenter(202, count: 4))
    XCTAssertTrue(CupertinoPickerParity.shouldRecenter(400, count: 4))
    XCTAssertFalse(CupertinoPickerParity.shouldRecenter(0, count: 0))
  }

  func testCupertinoPickerChangeUpdatesWireBeforeEvent() {
    let node = ControlNode(
      id: 9, type: "CupertinoPicker", props: ["on_change": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, data in calls.append("event:\(name):\(data.intValue ?? -1)") },
      setLocal: { _, key, value in calls.append("local:\(key):\(value.intValue ?? -1)") },
      update: { _, props in
        calls.append("update:selected_index:\(props["selected_index"]?.intValue ?? -1)")
      })

    RufletValueControlEvents.commit(
      node, key: "selected_index", value: .int(2), payload: .value, to: sink)
    XCTAssertEqual(calls, [
      "local:selected_index:2",
      "update:selected_index:2",
      "event:change:2",
    ])
  }

  func testRegularSegmentedButtonPreservesNullableSelectionAndOptionalPadding() {
    let configuration = RufletCupertinoSegmentedConfiguration(
      node: ControlNode(id: 1, type: "CupertinoSegmentedButton"))

    XCTAssertEqual(configuration.kind, .regular)
    XCTAssertNil(configuration.selectedIndex)
    XCTAssertFalse(configuration.proportionalWidth)
    XCTAssertNil(configuration.padding)
    XCTAssertEqual(
      configuration.validationMessage(visibleCount: 1),
      "CupertinoSegmentedButton must have at minimum two visible controls")
    XCTAssertNil(configuration.validationMessage(visibleCount: 2))
  }

  func testSlidingSegmentedButtonUsesPinnedConstructorDefaults() {
    let configuration = RufletCupertinoSegmentedConfiguration(
      node: ControlNode(id: 1, type: "CupertinoSlidingSegmentedButton"))

    XCTAssertEqual(configuration.kind, .sliding)
    XCTAssertEqual(configuration.selectedIndex, 0)
    XCTAssertFalse(configuration.proportionalWidth)
    XCTAssertEqual(configuration.padding?.top, 2)
    XCTAssertEqual(configuration.padding?.leading, 3)
    XCTAssertEqual(configuration.padding?.bottom, 2)
    XCTAssertEqual(configuration.padding?.trailing, 3)
    XCTAssertEqual(
      configuration.validationMessage(visibleCount: 0),
      "CupertinoSlidingSegmentedButton must have at minimum two visible controls")
  }

  func testSegmentedButtonExplicitSelectionAndPaddingOverrideDefaults() {
    let configuration = RufletCupertinoSegmentedConfiguration(
      node: ControlNode(
        id: 1,
        type: "CupertinoSlidingSegmentedButton",
        props: [
          "selected_index": .int(3),
          "proportional_width": .bool(true),
          "padding": .map([
            "top": .double(4), "right": .double(5),
            "bottom": .double(6), "left": .double(7),
          ]),
        ]))

    XCTAssertEqual(configuration.selectedIndex, 3)
    XCTAssertTrue(configuration.proportionalWidth)
    XCTAssertEqual(configuration.padding?.top, 4)
    XCTAssertEqual(configuration.padding?.trailing, 5)
    XCTAssertEqual(configuration.padding?.bottom, 6)
    XCTAssertEqual(configuration.padding?.leading, 7)
  }

  func testCupertinoSliderPreservesPinnedDefaultsAndContinuousMode() {
    let presentation = CupertinoSliderPresentation(
      node: ControlNode(id: 1, type: "CupertinoSlider"))

    XCTAssertEqual(presentation.minimum, 0)
    XCTAssertEqual(presentation.maximum, 1)
    XCTAssertEqual(presentation.value, 0)
    XCTAssertNil(presentation.divisions)
    XCTAssertNil(presentation.step)
    XCTAssertEqual(presentation.thumbColorName, "white")
  }

  func testCupertinoSliderClampsValueAndConvertsDivisionsToNativeStep() {
    let presentation = CupertinoSliderPresentation(
      node: ControlNode(
        id: 2, type: "CupertinoSlider",
        props: [
          "min": .double(10), "max": .double(30),
          "value": .double(40), "divisions": .int(4),
          "thumb_color": .string("red"),
        ]))

    XCTAssertEqual(presentation.range, 10...30)
    XCTAssertEqual(presentation.value, 30)
    XCTAssertEqual(presentation.step, 5)
    XCTAssertEqual(presentation.thumbColorName, "red")
  }
}
