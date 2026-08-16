import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest
#if os(macOS)
  import AppKit
#endif

@testable import RufletCharts

@MainActor
final class CartesianChartPropertyTests: XCTestCase {
  #if os(macOS)
    func testSharedChartFrameHonorsRubyWidthAndHeight() {
      let chart = makeControl(id: 1, type: "BarChart", properties: [
        "width": .double(320),
        "height": .double(180),
      ])
      let hosting = NSHostingView(
        rootView: ChartFrame(control: chart) { Color.clear })

      XCTAssertEqual(hosting.fittingSize.width, 320, accuracy: 0.5)
      XCTAssertEqual(hosting.fittingSize.height, 180, accuracy: 0.5)
    }
  #endif

  func testAxisParsesPinnedTitleLabelsAndReservedSizes() {
    let backend = CartesianChartTestBackend()
    let chart = makeControl(id: 1, type: "LineChart", properties: [
      "left_axis": controlValue(id: 2, type: "axis", properties: [
        "show_labels": .bool(true),
        "label_size": .double(30),
        "title_size": .double(18),
        "title": controlValue(id: 3, type: "Text", properties: ["value": .string("Amount")]),
        "labels": .array([
          controlValue(id: 4, type: "l", properties: [
            "value": .double(25),
            "label": .string("Quarter"),
          ]),
        ]),
      ]),
      "bottom_axis": controlValue(id: 5, type: "axis", properties: [
        "label_size": .double(20),
      ]),
    ], backend: backend)

    let axes = ChartAxes(control: chart)
    XCTAssertEqual(axes.left?.title?.id, 3)
    XCTAssertEqual(axes.left?.labels.map(\.value), [25])
    XCTAssertEqual(axes.left?.labels.first?.control.string("label"), "Quarter")
    XCTAssertEqual(axes.left?.reservedSize, 48)
    XCTAssertEqual(axes.bottom?.reservedSize, 20)

    let layout = ChartCartesianLayout(size: CGSize(width: 240, height: 160), axes: axes)
    XCTAssertEqual(layout.plotRect, CGRect(x: 48, y: 0, width: 192, height: 140))
  }

  func testGridBorderAndTickIntervalsPreservePinnedValues() {
    let chart = makeControl(id: 1, type: "BarChart", properties: [
      "horizontal_grid_lines": .map([
        "interval": .double(2.5),
        "color": .string("#112233"),
        "width": .double(3),
        "dash_pattern": .array([.int(4), .int(2)]),
      ]),
      "vertical_grid_lines": .map(["interval": .double(5)]),
      "border": .map(["width": .double(2), "color": .string("#445566")]),
    ])

    let configuration = ChartCartesianConfiguration(control: chart)
    XCTAssertEqual(configuration.grid.horizontal?.interval, 2.5)
    XCTAssertEqual(configuration.grid.horizontal?.width, 3)
    XCTAssertEqual(configuration.grid.horizontal?.dash, [4, 2])
    XCTAssertEqual(configuration.grid.vertical?.interval, 5)
    XCTAssertEqual(configuration.border?.left?.width, 2)
    XCTAssertEqual(chartTicks(min: -2.5, max: 5, interval: 2.5), [-2.5, 0, 2.5, 5])
  }

  func testTicksMatchPinnedFlChartBaselineAndEndpointRules() {
    XCTAssertEqual(
      chartTicks(
        min: -3, max: 3, interval: 2, baseline: 0,
        includeMinimum: false, includeMaximum: false),
      [-2, 0, 2])
    XCTAssertEqual(
      chartTicks(min: -3, max: 3, interval: 2, baseline: 0),
      [-3, -2, 0, 2, 3])
    XCTAssertEqual(
      chartTicks(
        min: 1, max: 5, interval: 2, baseline: 1,
        includeMinimum: false, includeMaximum: false),
      [3])
  }

  func testBarGroupCentersMatchPinnedFlChartAlignmentMath() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
    let widths: [CGFloat] = [10, 20]

    XCTAssertEqual(
      chartBarGroupCenters(in: rect, widths: widths, alignment: "start", spacing: 7),
      [5, 27])
    XCTAssertEqual(
      chartBarGroupCenters(in: rect, widths: widths, alignment: "end", spacing: 7),
      [68, 90])
    XCTAssertEqual(
      chartBarGroupCenters(in: rect, widths: widths, alignment: "center", spacing: 7),
      [36.5, 58.5])
    XCTAssertEqual(
      chartBarGroupCenters(in: rect, widths: widths, alignment: "space_between", spacing: 7),
      [5, 90])
    XCTAssertEqual(
      chartBarGroupCenters(in: rect, widths: widths, alignment: "space_around", spacing: 7),
      [22.5, 72.5])
    let evenly = chartBarGroupCenters(
      in: rect, widths: widths, alignment: "space_evenly", spacing: 7)
    XCTAssertEqual(evenly[0], 28.333_333_333, accuracy: 0.000_001)
    XCTAssertEqual(evenly[1], 66.666_666_667, accuracy: 0.000_001)

    XCTAssertEqual(
      chartBarGroupCenters(
        in: CGRect(x: 0, y: 0, width: 20, height: 40),
        widths: widths, alignment: "start", spacing: 7),
      chartBarGroupCenters(
        in: CGRect(x: 0, y: 0, width: 20, height: 40),
        widths: widths, alignment: "space_evenly", spacing: 7))
  }

  func testLineIndicatorUsesDataDomainAndPinnedDefaults() {
    let chart = makeControl(id: 1, type: "LineChart", properties: [
      "min_y": .double(-5),
      "max_y": .double(15),
    ])
    let domain = ChartDomain(points: [], control: chart)

    XCTAssertEqual(
      chartIndicatorRange(start: nil, end: nil, pointY: 8, domain: domain),
      -5...8)
    XCTAssertEqual(
      chartIndicatorRange(start: -100, end: 100, pointY: 8, domain: domain),
      -5...15)
    XCTAssertEqual(
      chartIndicatorRange(start: 12, end: 2, pointY: 8, domain: domain),
      2...12)
  }

  func testBarEventPayloadIncludesPinnedStackItemField() {
    let value = BarChartEventData(
      eventType: "tapUp", groupIndex: 2, rodIndex: 1, stackItemIndex: 0).value
    XCTAssertEqual(value["type"], .string("tapUp"))
    XCTAssertEqual(value["group_index"], .int(2))
    XCTAssertEqual(value["rod_index"], .int(1))
    XCTAssertEqual(value["stack_item_index"], .int(0))
  }

  func testBarMetadataConsumesSpacingSelectionGradientRadiusAndStackItems() {
    let group = makeControl(id: 1, type: "group", properties: [
      "bars_space": .double(7),
      "showing_tooltip_indicators": .array([.int(1)]),
      "rods": .array([
        controlValue(id: 2, type: "rod", properties: ["to_y": .double(10)]),
        controlValue(id: 3, type: "rod", properties: [
          "to_y": .double(20),
          "gradient": .map([
            "colors": .array([.string("red"), .string("blue")]),
          ]),
          "border_radius": .double(6),
          "rod_stack_items": .array([
            controlValue(id: 4, type: "stack_item", properties: [
              "from_y": .double(5),
              "to_y": .double(12),
              "color": .string("green"),
              "border_side": .map(["width": .double(2), "color": .string("black")]),
            ]),
          ]),
        ]),
      ]),
    ])

    let parsed = BarChartGroup.parse(group, paletteIndex: 0)
    XCTAssertEqual(parsed.spacing, 7)
    XCTAssertFalse(parsed.rods[0].selected)
    XCTAssertTrue(parsed.rods[1].selected)
    XCTAssertNotNil(parsed.rods[1].gradient)
    XCTAssertEqual(parsed.rods[1].borderRadius, 6)
    XCTAssertEqual(parsed.rods[1].stackItems.count, 1)
    XCTAssertEqual(parsed.rods[1].stackItems[0].fromY, 5)
    XCTAssertEqual(parsed.rods[1].stackItems[0].borderSide?.width, 2)
  }

  func testBarMetadataAcceptsPinnedSpacingAndStackItemSlots() {
    let group = makeControl(id: 1, type: "group", properties: [
      "spacing": .double(5),
      "bars_space": .double(9),
      "rods": .array([
        controlValue(id: 2, type: "rod", properties: [
          "to_y": .double(20),
          "stack_items": .array([
            controlValue(id: 3, type: "stack_item", properties: [
              "from_y": .double(4),
              "to_y": .double(15),
              "color": .string("orange"),
            ]),
          ]),
          "rod_stack_items": .array([
            controlValue(id: 4, type: "stack_item", properties: [
              "from_y": .double(0),
              "to_y": .double(1),
              "color": .string("blue"),
            ]),
          ]),
        ]),
      ]),
    ])

    let parsed = BarChartGroup.parse(group, paletteIndex: 0)
    XCTAssertEqual(parsed.spacing, 5)
    XCTAssertEqual(parsed.rods[0].stackItems.map(\.id), [3])
  }

  func testLineSeriesConsumesGradientCurveStrokeCapAndPoints() {
    let series = makeControl(id: 1, type: "data", properties: [
      "gradient": .map([
        "colors": .array([.string("cyan"), .string("purple")]),
      ]),
      "stroke_width": .double(5),
      "curved": .bool(true),
      "rounded_stroke_cap": .bool(true),
      "points": .array([
        controlValue(id: 2, type: "p", properties: ["x": .double(1), "y": .double(3)]),
      ]),
    ])

    let parsed = LineChartSeries.parse(series, index: 0)
    XCTAssertNotNil(parsed.gradient)
    XCTAssertEqual(parsed.strokeWidth, 5)
    XCTAssertTrue(parsed.curved)
    XCTAssertTrue(parsed.roundedStrokeCap)
    XCTAssertEqual(parsed.points.map { ChartPoint(x: $0.x, y: $0.y) }, [ChartPoint(x: 1, y: 3)])
  }

  private func makeControl(
    id: Int,
    type: String,
    properties: [String: RufletValue],
    backend: CartesianChartTestBackend? = nil
  ) -> RufletControl {
    RufletControl(
      id: id, type: type, properties: properties,
      backend: backend ?? CartesianChartTestBackend())
  }

  private func controlValue(
    id: Int,
    type: String,
    properties: [String: RufletValue]
  ) -> RufletValue {
    .map(properties.merging(["_c": .string(type), "_i": .int(Int64(id))]) { current, _ in current })
  }
}

@MainActor
private final class CartesianChartTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ value: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
