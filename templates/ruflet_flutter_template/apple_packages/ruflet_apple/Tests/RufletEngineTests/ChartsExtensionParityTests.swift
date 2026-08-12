@testable import RufletCharts
@testable import RufletUI
import RufletEngine
import RufletProtocol
import XCTest

@MainActor
final class ChartsExtensionParityTests: XCTestCase {
  private let chartTypes = [
    "LineChart", "BarChart", "PieChart", "ScatterChart", "RadarChart",
    "CandlestickChart",
  ]

  func testEveryFletChartKeepsItsOptionalProductBoundaryInCore() {
    for wireType in chartTypes {
      let descriptor = ControlRegistry.builtInDescriptor(for: wireType)
      XCTAssertEqual(descriptor?.classification, .visible)
      XCTAssertEqual(descriptor?.rendering, .optionalBundle("RufletCharts"))
      XCTAssertEqual(descriptor?.implementation, "RufletCharts.ChartControlView")
      XCTAssertEqual(descriptor?.supportedEvents, ["event"])
    }
  }

  func testRegisteringChartsInstallsAllSixNativePainters() {
    let services = ServiceRegistry()
    services.register(extension: RufletCharts.self)

    XCTAssertTrue(services.hasExtension("RufletCharts"))
    for wireType in chartTypes {
      let descriptor = ControlRegistry.descriptor(for: wireType)
      XCTAssertEqual(descriptor?.rendering, .nativeView)
      XCTAssertEqual(descriptor?.implementation, "RufletCharts.ChartControlView")
      XCTAssertNotNil(
        ControlRegistry.build(
          node: ControlNode(id: 1, type: wireType, props: [:]), axis: .none))
    }
  }

  func testManifestMarksFletChartsAvailable() {
    let charts = RufletExtensionManifest.packages.first { $0.fletPackage == "flet_charts" }
    XCTAssertEqual(charts?.swiftProduct, "RufletCharts")
    XCTAssertEqual(charts?.status, .available)
  }

  func testInteractionPayloadsMatchPinnedFletChartEventMaps() {
    XCTAssertEqual(
      ChartEventSemantics.bar(
        type: "panUpdate", groupIndex: 2, rodIndex: 1, stackItemIndex: nil),
      .map([
        "type": .string("panUpdate"),
        "group_index": .int(2),
        "rod_index": .int(1),
        "stack_item_index": .null,
      ]))
    XCTAssertEqual(
      ChartEventSemantics.line(
        type: "tapUp", spots: [(barIndex: 0, spotIndex: 3), (barIndex: 2, spotIndex: 4)]),
      .map([
        "type": .string("tapUp"),
        "spots": .array([
          .map(["bar_index": .int(0), "spot_index": .int(3)]),
          .map(["bar_index": .int(2), "spot_index": .int(4)]),
        ]),
      ]))
    XCTAssertEqual(
      ChartEventSemantics.pie(
        type: "pointerHover", sectionIndex: nil, localX: 12.5, localY: nil),
      .map([
        "type": .string("pointerHover"),
        "section_index": .null,
        "local_x": .double(12.5),
        "local_y": .null,
      ]))
    XCTAssertEqual(
      ChartEventSemantics.spot(type: "tapCancel", spotIndex: nil),
      .map(["type": .string("tapCancel"), "spot_index": .null]))
    XCTAssertEqual(
      ChartEventSemantics.radar(
        type: "longPressStart", dataSetIndex: 1, entryIndex: 4, entryValue: 8.25),
      .map([
        "type": .string("longPressStart"),
        "data_set_index": .int(1),
        "entry_index": .int(4),
        "entry_value": .double(8.25),
      ]))
  }

  func testEventRepeatFilteringMatchesEachDartAdapter() {
    let bar = ChartEventSemantics.bar(
      type: "tapUp", groupIndex: 1, rodIndex: 0, stackItemIndex: nil)
    XCTAssertTrue(ChartEventSemantics.shouldForward(bar, after: nil, chartType: "BarChart"))
    XCTAssertFalse(ChartEventSemantics.shouldForward(bar, after: bar, chartType: "BarChart"))

    let changedBar = ChartEventSemantics.bar(
      type: "tapUp", groupIndex: 2, rodIndex: 0, stackItemIndex: nil)
    XCTAssertTrue(
      ChartEventSemantics.shouldForward(changedBar, after: bar, chartType: "BarChart"))

    // The pinned Scatter adapter has no `_eventData` cache.
    let scatter = ChartEventSemantics.spot(type: "tapUp", spotIndex: 3)
    XCTAssertTrue(
      ChartEventSemantics.shouldForward(scatter, after: scatter, chartType: "ScatterChart"))
  }

  func testPieRepeatFilteringIgnoresLocalPositionLikeDartEquatable() {
    let first = ChartEventSemantics.pie(
      type: "pointerHover", sectionIndex: 2, localX: 10, localY: 20)
    let movedInsideSection = ChartEventSemantics.pie(
      type: "pointerHover", sectionIndex: 2, localX: 40, localY: 60)
    let movedToSection = ChartEventSemantics.pie(
      type: "pointerHover", sectionIndex: 3, localX: 40, localY: 60)

    XCTAssertFalse(
      ChartEventSemantics.shouldForward(
        movedInsideSection, after: first, chartType: "PieChart"))
    XCTAssertTrue(
      ChartEventSemantics.shouldForward(movedToSection, after: first, chartType: "PieChart"))
  }

  func testNativeGestureLifecycleUsesFletChartEventTypeNames() {
    XCTAssertEqual(
      ChartInteractionSemantics.dragChanged(
        first: true, crossedPanThreshold: false, panning: false),
      ["tapDown"])
    XCTAssertEqual(
      ChartInteractionSemantics.dragChanged(
        first: false, crossedPanThreshold: true, panning: false),
      ["tapCancel", "panDown", "panStart"])
    XCTAssertEqual(
      ChartInteractionSemantics.dragChanged(
        first: false, crossedPanThreshold: true, panning: true),
      ["panUpdate"])
    XCTAssertEqual(
      ChartInteractionSemantics.dragEnded(panning: false, longPressing: false),
      ["tapUp"])
    XCTAssertEqual(
      ChartInteractionSemantics.dragEnded(panning: true, longPressing: false),
      ["panEnd"])
    XCTAssertEqual(
      ChartInteractionSemantics.longPressStarted(),
      ["tapCancel", "longPressStart"])
    XCTAssertEqual(
      ChartInteractionSemantics.dragEnded(panning: false, longPressing: true),
      ["longPressEnd"])
  }

  func testLongPressDurationUsesFletMillisecondAndDurationPayloads() {
    XCTAssertEqual(
      ChartInteractionSemantics.longPressDuration(
        for: ControlNode(id: 1, type: "ScatterChart", props: [:])),
      0.5)
    XCTAssertEqual(
      ChartInteractionSemantics.longPressDuration(
        for: ControlNode(
          id: 1, type: "ScatterChart", props: ["long_press_duration": .int(750)])),
      0.75)
    XCTAssertEqual(
      ChartInteractionSemantics.longPressDuration(
        for: ControlNode(
          id: 1, type: "ScatterChart",
          props: ["long_press_duration": .map(["seconds": .int(1), "milliseconds": .int(250)])])),
      1.25)
    XCTAssertEqual(
      ChartInteractionSemantics.longPressDuration(
        for: ControlNode(
          id: 1, type: "ScatterChart",
          props: ["long_press_duration": .extended(type: 3, string: "625000")])),
      0.625)
  }

  func testSelectedTooltipIndicatorsMatchPinnedFamilyRules() {
    XCTAssertFalse(ChartInteractionSemantics.showsSelectedTooltip(
      chartType: "LineChart", interactive: true, selected: true,
      showTooltip: true, hasTooltip: true))
    XCTAssertTrue(ChartInteractionSemantics.showsSelectedTooltip(
      chartType: "LineChart", interactive: false, selected: true,
      showTooltip: true, hasTooltip: true))
    XCTAssertTrue(ChartInteractionSemantics.showsSelectedTooltip(
      chartType: "BarChart", interactive: false, selected: true,
      showTooltip: true, hasTooltip: true))
    XCTAssertTrue(ChartInteractionSemantics.showsSelectedTooltip(
      chartType: "ScatterChart", interactive: true, selected: true,
      showTooltip: true, hasTooltip: true))
    XCTAssertTrue(ChartInteractionSemantics.showsSelectedTooltip(
      chartType: "CandlestickChart", interactive: false, selected: true,
      showTooltip: true, hasTooltip: true))
    XCTAssertFalse(ChartInteractionSemantics.showsSelectedTooltip(
      chartType: "ScatterChart", interactive: true, selected: true,
      showTooltip: false, hasTooltip: true))
    XCTAssertFalse(ChartInteractionSemantics.showsSelectedTooltip(
      chartType: "ScatterChart", interactive: true, selected: true,
      showTooltip: true, hasTooltip: false))
  }

  func testSelectedOnlyDisablesBuiltInTouchTooltipsWhereFletDoes() {
    let selectedOnlyScatter = ControlNode(
      id: 1, type: "ScatterChart",
      props: ["show_tooltips_for_selected_spots_only": .bool(true)])
    let selectedOnlyCandle = ControlNode(
      id: 2, type: "CandlestickChart",
      props: ["show_tooltips_for_selected_spots_only": .bool(true)])
    let line = ControlNode(
      id: 3, type: "LineChart",
      props: ["show_tooltips_for_selected_spots_only": .bool(true)])

    XCTAssertFalse(ChartInteractionSemantics.handlesBuiltInTooltips(for: selectedOnlyScatter))
    XCTAssertFalse(ChartInteractionSemantics.handlesBuiltInTooltips(for: selectedOnlyCandle))
    XCTAssertTrue(ChartInteractionSemantics.handlesBuiltInTooltips(for: line))
  }
}
