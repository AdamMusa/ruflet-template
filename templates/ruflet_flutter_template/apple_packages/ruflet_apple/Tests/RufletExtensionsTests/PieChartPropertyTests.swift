import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletCharts

@MainActor
final class PieChartPropertyTests: XCTestCase {
  func testSectionDefaultsMatchPinnedPieChartSectionData() {
    let section = PieChartSection.parse(makeSection(id: 1), index: 0)

    XCTAssertEqual(section.value, 10)
    XCTAssertEqual(section.radius, 40)
    XCTAssertNil(section.title)
    XCTAssertNil(section.titleStyle)
    XCTAssertNil(section.badge)
    XCTAssertEqual(section.titlePosition, 0.5)
    XCTAssertEqual(section.badgePosition, 0.5)
  }

  func testSectionConsumesTitleStyleBadgeAndBadgePosition() {
    let section = PieChartSection.parse(makeSection(id: 1, properties: [
      "value": .double(25),
      "radius": .double(52),
      "title": .string("Revenue"),
      "title_style": .map([
        "size": .double(18),
        "italic": .bool(true),
        "color": .string("#ff3366"),
      ]),
      "badge_widget": .map([
        "_c": .string("Text"),
        "_i": .int(2),
        "value": .string("New"),
      ]),
      "badge_position_percentage_offset": .double(0.8),
    ]), index: 0)

    XCTAssertEqual(section.value, 25)
    XCTAssertEqual(section.radius, 52)
    XCTAssertEqual(section.title, "Revenue")
    XCTAssertEqual(section.titleStyle?.size, 18)
    XCTAssertEqual(section.titleStyle?.italic, true)
    XCTAssertEqual(section.badge?.id, 2)
    XCTAssertEqual(section.badge?.string("value"), "New")
    XCTAssertEqual(section.badgePosition, 0.8)
  }

  func testAutomaticCenterRadiusAndSectionSpaceMatchPinnedGeometryContract() {
    let sections = [
      PieChartSection.parse(makeSection(id: 1, properties: ["value": .double(1)]), index: 0),
      PieChartSection.parse(makeSection(id: 2, properties: ["value": .double(1)]), index: 1),
    ]
    let layout = PieChartLayout(
      size: CGSize(width: 200, height: 240),
      sections: sections,
      requestedCenterRadius: nil,
      sectionsSpace: 2,
      startDegreeOffset: 0)

    XCTAssertEqual(layout.centerRadius, 60)
    XCTAssertEqual(layout.slices.count, 2)
    XCTAssertEqual(layout.slices[0].outerRadius, 100)
    XCTAssertGreaterThan(layout.slices[0].start, 0)
    XCTAssertLessThan(layout.slices[0].end, .pi)
    XCTAssertEqual(layout.slices[1].middle, .pi * 1.5, accuracy: 0.000_001)
  }

  func testHitTestingRejectsCenterOutsideAndSectionGap() {
    let sections = [
      PieChartSection.parse(makeSection(id: 1, properties: ["value": .double(1)]), index: 0),
      PieChartSection.parse(makeSection(id: 2, properties: ["value": .double(1)]), index: 1),
    ]
    let layout = PieChartLayout(
      size: CGSize(width: 140, height: 140),
      sections: sections,
      requestedCenterRadius: 20,
      sectionsSpace: 8,
      startDegreeOffset: 0)

    XCTAssertNil(layout.sectionIndex(at: layout.center))
    XCTAssertNil(layout.sectionIndex(at: CGPoint(x: 139, y: 70)))
    XCTAssertNil(layout.sectionIndex(at: CGPoint(x: 110, y: 70)))
    XCTAssertEqual(layout.sectionIndex(at: layout.point(in: layout.slices[0], percentage: 0.5)), 0)
    XCTAssertEqual(layout.sectionIndex(at: layout.point(in: layout.slices[1], percentage: 0.5)), 1)
  }

  private func makeSection(
    id: Int,
    properties: [String: RufletValue] = [:]
  ) -> RufletControl {
    RufletControl(
      id: id,
      type: "section",
      properties: properties,
      backend: PieChartTestBackend())
  }
}

@MainActor
private final class PieChartTestBackend: RufletBackendProtocol {
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
