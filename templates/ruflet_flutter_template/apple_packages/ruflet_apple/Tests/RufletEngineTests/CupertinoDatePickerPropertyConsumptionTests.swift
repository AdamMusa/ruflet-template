import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class CupertinoDatePickerPropertyConsumptionTests: XCTestCase {
  func testEveryPinnedDateOrderProducesExactColumns() {
    let expected: [String: [RufletDateWheelComponent]] = [
      "dmy": [.day, .month, .year],
      "mdy": [.month, .day, .year],
      "ymd": [.year, .month, .day],
      "ydm": [.year, .day, .month],
    ]

    for (order, components) in expected {
      let configuration = configuration(properties: ["date_order": .string(order)])
      XCTAssertEqual(configuration.components, components)
    }
  }

  func testMonthYearCollapsesDayWhilePreservingYearSide() {
    XCTAssertEqual(
      configuration(properties: [
        "date_picker_mode": .string("monthYear"),
        "date_order": .string("dmy"),
      ]).components,
      [.month, .year])
    XCTAssertEqual(
      configuration(properties: [
        "date_picker_mode": .string("monthYear"),
        "date_order": .string("ydm"),
      ]).components,
      [.year, .month])
  }

  func testWeekdayLabelTracksSelectedMonthAndYear() throws {
    let configuration = configuration(properties: [
      "locale": .string("en_US"),
      "show_day_of_week": .bool(true),
    ])
    let date = try XCTUnwrap(
      configuration.calendar.date(from: DateComponents(year: 2024, month: 2, day: 1)))

    XCTAssertEqual(configuration.label(for: .day, row: 28, value: date), "Thu 29")
  }

  func testChangingMonthClampsInvalidDayAndRange() throws {
    let configuration = configuration(properties: [
      "minimum_year": .int(2024),
      "maximum_year": .int(2025),
    ])
    let january31 = try XCTUnwrap(
      configuration.calendar.date(from: DateComponents(year: 2024, month: 1, day: 31)))
    let february = try XCTUnwrap(
      configuration.replacing(component: .month, row: 1, in: january31))

    XCTAssertEqual(
      configuration.calendar.dateComponents([.year, .month, .day], from: february),
      DateComponents(year: 2024, month: 2, day: 29))
  }

  func testExplicitYearBoundsIntersectFirstAndLastDates() {
    let configuration = configuration(properties: [
      "first_date": .extensionValue(
        type: 1,
        payload: Data("2024-01-01T00:00:00.000Z".utf8)),
      "last_date": .extensionValue(
        type: 1,
        payload: Data("2028-12-31T00:00:00.000Z".utf8)),
      "minimum_year": .int(2025),
      "maximum_year": .int(2027),
    ])

    XCTAssertEqual(configuration.minimumYear, 2025)
    XCTAssertEqual(configuration.maximumYear, 2027)
  }

  private func configuration(
    properties: [String: RufletValue]
  ) -> RufletCupertinoDateWheelConfiguration {
    RufletCupertinoDateWheelConfiguration(
      control: RufletControl(
        id: 1,
        type: "CupertinoDatePicker",
        properties: properties,
        backend: CupertinoDatePickerTestBackend()))
  }
}

@MainActor
private final class CupertinoDatePickerTestBackend: RufletBackendProtocol {
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
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
