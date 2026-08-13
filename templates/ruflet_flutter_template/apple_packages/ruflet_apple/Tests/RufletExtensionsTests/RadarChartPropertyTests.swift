import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletCharts

@MainActor
final class RadarChartPropertyTests: XCTestCase {
  func testTitleConsumesPinnedTextAnglePositionAndNotifiesParent() {
    let control = makeTitle(properties: [
      "text": .string("Revenue"),
      "angle": .double(35),
      "position_percentage_offset": .double(0.4),
    ])

    let title = RadarChartTitleConfiguration.parse(
      control,
      defaultAngle: 90,
      defaultPositionPercentageOffset: 0.2)

    XCTAssertEqual(title.text, "Revenue")
    XCTAssertEqual(title.angle, 35)
    XCTAssertEqual(title.positionPercentageOffset, 0.4)
    XCTAssertTrue(control.notifyParent)
  }

  func testTitleUsesPinnedAxisAngleAndChartPositionDefaults() {
    let title = RadarChartTitleConfiguration.parse(
      makeTitle(),
      defaultAngle: 120,
      defaultPositionPercentageOffset: 0.2)

    XCTAssertEqual(title.text, "")
    XCTAssertEqual(title.angle, 120)
    XCTAssertEqual(title.positionPercentageOffset, 0.2)
  }

  func testTitlePositionMovesOutwardAlongItsRadarAxis() {
    let title = RadarChartTitleConfiguration(
      id: 2,
      text: "Axis",
      angle: 90,
      positionPercentageOffset: 0.25)

    let position = title.position(
      index: 1,
      count: 4,
      radius: 80,
      center: CGPoint(x: 100, y: 100),
      textHeight: 20)

    XCTAssertEqual(position.x, 210, accuracy: 0.000_001)
    XCTAssertEqual(position.y, 100, accuracy: 0.000_001)
  }

  func testRadarChartReadsInvisibleTitlesAsMetadata() throws {
    let source = try String(contentsOf: sourceURL(), encoding: .utf8)

    XCTAssertTrue(source.contains("control.children(\"titles\", visibleOnly: false)"))
    XCTAssertTrue(source.contains("RadarChartTitleConfiguration.parse("))
  }

  func testConfigurationConsumesPinnedRadarAppearanceAndInteraction() {
    let control = makeChart(properties: [
      "radar_shape": .string("circle"),
      "radar_bgcolor": .string("#112233"),
      "radar_border_side": stroke(width: 3, color: "red"),
      "grid_border_side": stroke(width: 4, color: "green"),
      "tick_border_side": stroke(width: 5, color: "blue"),
      "border": .map(["width": .double(6), "color": .string("orange")]),
      "title_text_style": .map(["size": .double(17)]),
      "ticks_text_style": .map(["size": .double(13)]),
      "title_position_percentage_offset": .double(0.6),
      "tick_count": .int(4),
      "center_min_value": .bool(true),
      "touch_spot_threshold": .double(12),
      "interactive": .bool(true),
      "disabled": .bool(true),
    ])

    let configuration = RadarChartConfiguration(control: control)

    XCTAssertEqual(configuration.shape, .circle)
    XCTAssertEqual(configuration.radarBorder.width, 3)
    XCTAssertEqual(configuration.gridBorder.width, 4)
    XCTAssertEqual(configuration.tickBorder.width, 5)
    XCTAssertEqual(configuration.chartBorder?.top?.width, 6)
    XCTAssertEqual(configuration.titleStyle?.size, 17)
    XCTAssertEqual(configuration.tickStyle?.size, 13)
    XCTAssertEqual(configuration.titlePositionPercentageOffset, 0.6)
    XCTAssertEqual(configuration.tickCount, 4)
    XCTAssertTrue(configuration.centerMinimumValue)
    XCTAssertEqual(configuration.touchSpotThreshold, 12)
    XCTAssertFalse(configuration.interactive)
  }

  func testDataSetConsumesPinnedGradientEntryAndBorderContract() {
    let dataSet = RadarDataSet.parse(
      makeControl(
        id: 3, type: "RadarDataSet",
        properties: [
          "fill_color": .string("red"),
          "fill_gradient": .map([
            "colors": .array([.string("green"), .string("blue")])
          ]),
          "border_color": .string("black"),
          "border_width": .double(7),
          "entry_radius": .double(8),
          "entries": .array([
            controlValue(id: 4, type: "RadarDataSetEntry", properties: ["value": .double(10)]),
            controlValue(id: 5, type: "RadarDataSetEntry", properties: ["value": .double(20)]),
            controlValue(id: 6, type: "RadarDataSetEntry", properties: ["value": .double(30)]),
          ]),
        ]),
      index: 0)

    XCTAssertEqual(dataSet.entries, [10, 20, 30])
    XCTAssertNotNil(dataSet.fillGradient)
    XCTAssertEqual(dataSet.borderWidth, 7)
    XCTAssertEqual(dataSet.entryRadius, 8)
  }

  func testLayoutMatchesPinnedMinimumAndTickScaling() {
    let dataSets = [makeDataSet(id: 1, entries: [10, 20, 30])]
    let standard = RadarChartLayout(
      size: CGSize(width: 200, height: 300),
      dataSets: dataSets,
      configuration: RadarChartConfiguration(
        control: makeChart(properties: ["tick_count": .int(2)])))

    XCTAssertEqual(standard.radius, 80)
    XCTAssertEqual(standard.centerValue, 0)
    XCTAssertEqual(standard.scaledRadius(for: 10), 80 / 3, accuracy: 0.000_001)
    XCTAssertEqual(standard.ticks.map(\.value), [10, 20])
    XCTAssertEqual(standard.ticks.map(\.radius), [80 / 3, 160 / 3])

    let centered = RadarChartLayout(
      size: CGSize(width: 200, height: 300),
      dataSets: dataSets,
      configuration: RadarChartConfiguration(
        control: makeChart(properties: [
          "tick_count": .int(2),
          "center_min_value": .bool(true),
        ])))
    XCTAssertEqual(centered.centerValue, 10)
    XCTAssertEqual(centered.scaledRadius(for: 10), 0)
    XCTAssertEqual(centered.scaledRadius(for: 30), 80)
    XCTAssertEqual(centered.ticks.map(\.radius), [0, 40])
  }

  func testHitTestingUsesPinnedSpotThresholdAndActualEntryGeometry() {
    let dataSets = [
      makeDataSet(id: 1, entries: [10, 20, 30]),
      makeDataSet(id: 2, entries: [20, 25, 30]),
    ]
    let layout = RadarChartLayout(
      size: CGSize(width: 200, height: 200),
      dataSets: dataSets,
      configuration: RadarChartConfiguration(control: makeChart()))
    let point = layout.vertex(index: 0, radius: layout.scaledRadius(for: 20))

    XCTAssertEqual(
      layout.hitTest(point, dataSets: dataSets, threshold: 2),
      RadarChartLayout.Hit(dataSetIndex: 1, entryIndex: 0, entryValue: 20))
    XCTAssertNil(
      layout.hitTest(
        CGPoint(x: point.x + 11, y: point.y + 11),
        dataSets: dataSets,
        threshold: 10))
  }

  private func makeTitle(properties: [String: RufletValue] = [:]) -> RufletControl {
    makeControl(id: 2, type: "RadarChartTitle", properties: properties)
  }

  private func makeChart(properties: [String: RufletValue] = [:]) -> RufletControl {
    makeControl(id: 1, type: "RadarChart", properties: properties)
  }

  private func makeControl(
    id: Int,
    type: String,
    properties: [String: RufletValue]
  ) -> RufletControl {
    RufletControl(id: id, type: type, properties: properties, backend: RadarChartTestBackend())
  }

  private func makeDataSet(id: Int, entries: [Double]) -> RadarDataSet {
    RadarDataSet(
      id: id,
      entries: entries,
      fillColor: .cyan,
      fillGradient: nil,
      borderColor: .cyan,
      borderWidth: 2,
      entryRadius: 5)
  }

  private func stroke(width: Double, color: String) -> RufletValue {
    .map(["width": .double(width), "color": .string(color)])
  }

  private func controlValue(
    id: Int,
    type: String,
    properties: [String: RufletValue]
  ) -> RufletValue {
    .map(
      properties.merging([
        "_c": .string(type),
        "_i": .int(Int64(id)),
      ]) { current, _ in current })
  }

  private func sourceURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletExtensions/RufletCharts/Sources/RadarChart.swift")
  }
}

@MainActor
private final class RadarChartTestBackend: RufletBackendProtocol {
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
