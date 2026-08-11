import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

/// The Material value controls — Switch, Slider, RangeSlider, Checkbox and
/// Radio — against the widgets Flet builds.
final class ValueControlParityTests: XCTestCase {
  private func node(_ type: String, _ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: type, props: props)
  }

  // MARK: - Widget state properties

  /// A bare value is the default state, not an error: Flet accepts both
  /// `thumb_color: "red"` and `thumb_color: {selected: "red"}`.
  func testPlainValueResolvesInEveryState() {
    let plain = RufletValue.string("red")
    XCTAssertEqual(RufletWidgetStateProperty.resolve(plain, in: []), plain)
    XCTAssertEqual(RufletWidgetStateProperty.resolve(plain, in: [.selected, .disabled]), plain)
  }

  func testStateTableResolvesTheNamedStateAndFallsBackToDefault() {
    let table = RufletValue.map([
      "default": .string("grey"),
      "selected": .string("blue"),
    ])
    XCTAssertEqual(RufletWidgetStateProperty.resolve(table, in: [.selected]), .string("blue"))
    XCTAssertEqual(RufletWidgetStateProperty.resolve(table, in: []), .string("grey"))
    XCTAssertEqual(RufletWidgetStateProperty.resolve(table, in: [.hovered]), .string("grey"))
  }

  /// `""` is Flet's deprecated spelling of `default`.
  func testEmptyKeyIsAcceptedAsTheDefaultState() {
    let table = RufletValue.map(["": .string("grey"), "pressed": .string("blue")])
    XCTAssertEqual(RufletWidgetStateProperty.resolve(table, in: []), .string("grey"))
    XCTAssertEqual(RufletWidgetStateProperty.resolve(table, in: [.pressed]), .string("blue"))
  }

  /// The rule that keeps a `BorderSide` from being read as a state table.
  func testMapWhoseKeysAreNotStatesIsItselfTheValue() {
    let side = RufletValue.map(["width": .double(2), "color": .string("red")])
    XCTAssertEqual(RufletWidgetStateProperty.resolve(side, in: [.selected]), side)
  }

  /// Flet resolves in the order the keys were written; a Swift dictionary has
  /// no order, so the resolver uses a fixed precedence instead.
  func testMostSpecificStateWinsWhenSeveralApply() {
    let table = RufletValue.map([
      "default": .string("grey"),
      "hovered": .string("blue"),
      "disabled": .string("faded"),
    ])
    XCTAssertEqual(
      RufletWidgetStateProperty.resolve(table, in: [.hovered, .disabled]), .string("faded"))
    XCTAssertEqual(RufletWidgetStateProperty.resolve(table, in: [.hovered]), .string("blue"))
  }

  func testControlReportsItsOwnDisabledAndSelectedStates() {
    let off = node("Switch", ["value": .bool(false)])
    XCTAssertFalse(off.widgetStates().contains(.selected))

    let on = node("Switch", ["value": .bool(true), "disabled": .bool(true)])
    XCTAssertEqual(on.widgetStates(), [.selected, .disabled])

    let errored = node("Checkbox", ["error": .bool(true)])
    XCTAssertTrue(errored.widgetStates().contains(.error))
  }

  func testStatefulBorderSideCarriesItsWidthAndDefaultsToOne() {
    let explicit = ControlProps.statefulBorderSide(
      .map(["width": .double(3), "color": .string("red")]), in: [])
    XCTAssertEqual(explicit?.width, 3)
    XCTAssertNotNil(explicit?.color)

    let widthless = ControlProps.statefulBorderSide(.map(["color": .string("red")]), in: [])
    XCTAssertEqual(widthless?.width, 1)
    XCTAssertNil(ControlProps.statefulBorderSide(nil, in: []))
  }

  // MARK: - Switch

  /// `active_color` is Flutter's `activeThumbColor`. Naming it `primary`, the
  /// track's own role, would have painted the thumb the colour it sits on.
  func testSwitchThumbAndTrackResolveToDifferentMaterialRoles() {
    let omitted = node("Switch")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "active_color"), "onprimary")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "active_track_color"),
      "primary")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "inactive_thumb_color"),
      "outline")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "inactive_track_color"),
      "surfacecontainerhighest")
  }

  func testSwitchTrackIsMaterialsFiftyTwoByThirtyTwo() {
    XCTAssertEqual(RufletThemeDefaults.switchTrackWidth, 52)
    XCTAssertEqual(RufletThemeDefaults.switchTrackHeight, 32)
    XCTAssertEqual(RufletThemeDefaults.switchThumbSize, 16)
    XCTAssertEqual(RufletThemeDefaults.switchSelectedThumbSize, 24)
  }

  // MARK: - Slider geometry

  /// The regression this arithmetic was extracted for: the range slider used
  /// to divide a drag by the touch's *starting* x rather than by the track
  /// width, so a thumb did not land where the finger was.
  func testValueUnderAPointIsMeasuredAgainstTheTrackNotTheTouch() {
    // A 120pt track with a 20pt thumb leaves 100pt of travel, starting 10pt in.
    let scale = RufletSliderScale(
      minimum: 0, maximum: 1, divisions: nil, width: 120, thumbWidth: 20)
    XCTAssertEqual(scale.travel, 100)
    XCTAssertEqual(scale.value(at: 10), 0, accuracy: 0.0001)
    XCTAssertEqual(scale.value(at: 60), 0.5, accuracy: 0.0001)
    XCTAssertEqual(scale.value(at: 110), 1, accuracy: 0.0001)
  }

  func testPositionAndValueAreInverses() {
    let scale = RufletSliderScale(
      minimum: -50, maximum: 50, divisions: nil, width: 220, thumbWidth: 20)
    for value in stride(from: -50.0, through: 50.0, by: 12.5) {
      XCTAssertEqual(scale.value(at: scale.position(of: value)), value, accuracy: 0.0001)
    }
  }

  func testPointsOutsideTheTrackClampToTheEnds() {
    let scale = RufletSliderScale(
      minimum: 0, maximum: 10, divisions: nil, width: 120, thumbWidth: 20)
    XCTAssertEqual(scale.value(at: -400), 0)
    XCTAssertEqual(scale.value(at: 4000), 10)
  }

  func testDivisionsSnapToTheNearestStep() {
    let scale = RufletSliderScale(
      minimum: 0, maximum: 10, divisions: 5, width: 120, thumbWidth: 20)
    // Five divisions over 0…10 is a step of 2.
    XCTAssertEqual(scale.value(at: scale.position(of: 4.9)), 4, accuracy: 0.0001)
    XCTAssertEqual(scale.value(at: scale.position(of: 5.1)), 6, accuracy: 0.0001)
  }

  func testZeroOrNegativeDivisionsAreTreatedAsContinuous() {
    let scale = RufletSliderScale(
      minimum: 0, maximum: 1, divisions: 0, width: 120, thumbWidth: 20)
    XCTAssertNil(scale.divisions)
    XCTAssertEqual(scale.value(at: 35), 0.25, accuracy: 0.0001)
  }

  /// A degenerate range must not divide by zero.
  func testCollapsedRangeStillResolves() {
    let scale = RufletSliderScale(
      minimum: 5, maximum: 5, divisions: nil, width: 120, thumbWidth: 20)
    XCTAssertEqual(scale.position(of: 5), 10)
    XCTAssertTrue(scale.value(at: 60).isFinite)
  }

  // MARK: - Slider shape and interaction

  /// Flet leaves `year_2023` unset, so an unconfigured slider gets Flutter's
  /// own default — the original Material 3 shape.
  func testSliderKeepsTheTwentyTwentyThreeShapeUnlessAskedOtherwise() {
    let legacy = RufletThemeDefaults.sliderMetrics(year2023: nil)
    XCTAssertEqual(legacy, RufletThemeDefaults.sliderMetrics(year2023: true))
    XCTAssertEqual(legacy.trackHeight, 4)
    XCTAssertEqual(legacy.thumbWidth, 20)

    let revised = RufletThemeDefaults.sliderMetrics(year2023: false)
    XCTAssertEqual(revised.trackHeight, 16)
    XCTAssertEqual(revised.thumbWidth, 4)
    XCTAssertEqual(revised.thumbHeight, 44)
  }

  func testInteractionModesParseAndGovernWhatMayMoveAThumb() {
    XCTAssertEqual(RufletSliderInteraction(wire: nil), .tapAndSlide)
    XCTAssertEqual(RufletSliderInteraction(wire: "tapOnly"), .tapOnly)
    XCTAssertEqual(RufletSliderInteraction(wire: "slide_only"), .slideOnly)
    XCTAssertEqual(RufletSliderInteraction(wire: "slideThumb"), .slideThumb)

    XCTAssertFalse(RufletSliderInteraction.slideThumb.acceptsTrackGestures)
    XCTAssertTrue(RufletSliderInteraction.tapAndSlide.acceptsTrackGestures)
    XCTAssertFalse(RufletSliderInteraction.tapOnly.acceptsSlide)
  }

  func testRangeSliderBuildsOneFletTemplateLabelPerThumb() {
    XCTAssertEqual(
      RufletRangeSliderLabels.resolve(
        template: "Value: {value}", start: 1.25, end: 8.75, digits: 1),
      ["Value: 1.2", "Value: 8.8"])
    XCTAssertEqual(
      RufletRangeSliderLabels.resolve(template: "", start: 1, end: 2, digits: 0),
      [nil, nil])
  }

  // MARK: - Checkbox

  /// Flutter's checkbox value is `bool?`, and Flet defaults it to nil when the
  /// box is tristate — absence and `false` are different resting states.
  func testTristateCheckboxRestsIndeterminateAndPlainOneRestsUnchecked() {
    XCTAssertEqual(RufletCheckboxState.resting(node("Checkbox")), false)
    XCTAssertNil(RufletCheckboxState.resting(node("Checkbox", ["tristate": .bool(true)])))
    XCTAssertEqual(
      RufletCheckboxState.resting(node("Checkbox", ["value": .bool(true)])), true)
    XCTAssertNil(
      RufletCheckboxState.resting(
        node("Checkbox", ["tristate": .bool(true), "value": .null])))
  }

  func testTristateCycleGoesIndeterminateUncheckedCheckedAndBack() {
    XCTAssertEqual(RufletCheckboxState.next(after: nil, tristate: true), .bool(false))
    XCTAssertEqual(RufletCheckboxState.next(after: false, tristate: true), .bool(true))
    XCTAssertEqual(RufletCheckboxState.next(after: true, tristate: true), .null)
  }

  func testPlainCheckboxJustFlips() {
    XCTAssertEqual(RufletCheckboxState.next(after: false, tristate: false), .bool(true))
    XCTAssertEqual(RufletCheckboxState.next(after: true, tristate: false), .bool(false))
    XCTAssertEqual(RufletCheckboxState.next(after: nil, tristate: false), .bool(true))
  }

  // MARK: - Contract

  /// Flet gives each of these a FocusNode and reports focus/blur from it, so
  /// the descriptor has to advertise the pair — `FocusReporter` only mounts
  /// for controls that declare it.
  func testSelectionControlsAdvertiseTheFocusPairFletReports() {
    for type in ["Switch", "Checkbox", "Radio"] {
      XCTAssertEqual(
        ControlRegistry.descriptor(for: type)?.supportedEvents,
        ["blur", "change", "focus"], type)
    }
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Slider")?.supportedEvents,
      ["blur", "change", "change_end", "change_start", "focus"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "RangeSlider")?.supportedEvents,
      ["change", "change_end", "change_start"])
    XCTAssertEqual(ControlRegistry.descriptor(for: "RadioGroup")?.supportedEvents, ["change"])
  }

  func testSelectionControlsRequireNativeFocus() {
    for type in ["Switch", "Checkbox", "Radio", "Slider"] {
      let control = ControlNode(id: 1, type: type, props: ["on_focus": .bool(true)])
      XCTAssertTrue(RufletFocusContract.requiresNativeFocus(for: control), type)
    }
  }
}
