import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class RangeSliderPropertyConsumptionTests: XCTestCase {
  func testPresentationConsumesPinnedAppearanceAndLabelProperties() {
    let fixture = makeControl(
      properties: [
        "min": 10.0,
        "max": 30.0,
        "start_value": 14.0,
        "end_value": 26.0,
        "divisions": 10,
        "round": 2,
        "label": "USD {value}",
        "active_color": "green",
        "inactive_color": "grey",
        "mouse_cursor": ["default": "basic", "hovered": "click", "dragged": "grabbing"],
        "overlay_color": ["pressed": "red", "hovered": "blue"],
      ])
    let presentation = RufletRangeSliderPresentation(control: fixture.control)

    XCTAssertEqual(presentation.minimum, 10)
    XCTAssertEqual(presentation.maximum, 30)
    XCTAssertEqual(presentation.values, RufletRangeValues(start: 14, end: 26))
    XCTAssertEqual(presentation.divisions, 10)
    XCTAssertEqual(presentation.precision, 2)
    XCTAssertEqual(presentation.formattedLabel(for: 14), "USD 14.00")
    XCTAssertNotNil(presentation.activeColor)
    XCTAssertNotNil(presentation.inactiveColor)
    XCTAssertEqual(
      presentation.resolvedMouseCursor(hovered: false, pressed: false), "basic")
    XCTAssertEqual(
      presentation.resolvedMouseCursor(hovered: true, pressed: false), "click")
    XCTAssertEqual(
      presentation.resolvedMouseCursor(hovered: false, pressed: true), "grabbing")
    XCTAssertNotNil(presentation.resolvedOverlay(hovered: false, pressed: true))
    XCTAssertNotNil(presentation.resolvedOverlay(hovered: true, pressed: false))
  }

  func testPresentationNormalizesBoundsValuesAndDivisions() {
    let fixture = makeControl(
      properties: [
        "min": 100.0,
        "max": 0.0,
        "start_value": 90.0,
        "end_value": 20.0,
        "divisions": 4,
      ])
    let presentation = RufletRangeSliderPresentation(control: fixture.control)

    XCTAssertEqual(presentation.minimum, 0)
    XCTAssertEqual(presentation.maximum, 100)
    XCTAssertEqual(presentation.values, RufletRangeValues(start: 20, end: 90))
    XCTAssertEqual(presentation.snap(64), 75)
    XCTAssertEqual(presentation.fraction(for: 20), 0.2)
  }

  func testChangeTransactionUpdatesBothValuesBeforeFiringBareEvent() {
    let fixture = makeControl(properties: ["start_value": 1.0, "end_value": 3.0])
    RangeSliderControl(control: fixture.control).updateValues(
      RufletRangeValues(start: 1.5, end: 2.5))

    XCTAssertEqual(fixture.backend.updates.count, 1)
    XCTAssertEqual(
      fixture.backend.updates[0],
      ["start_value": .double(1.5), "end_value": .double(2.5)])
    XCTAssertEqual(fixture.backend.events, [Event(name: "change", data: .null)])
  }

  func testPinnedEventContractIsStartThenChangeThenEnd() {
    let fixture = makeControl(properties: [:])
    fixture.control.triggerEvent("change_start")
    RangeSliderControl(control: fixture.control).updateValues(
      RufletRangeValues(start: 0.25, end: 0.75))
    fixture.control.triggerEvent("change_end")

    XCTAssertEqual(fixture.backend.events.map(\.name), ["change_start", "change", "change_end"])
    XCTAssertTrue(fixture.backend.events.allSatisfy { $0.data == .null })
  }

  private func makeControl(
    properties: [String: RufletValue]
  ) -> (control: RufletControl, backend: RangeSliderBackend) {
    let backend = RangeSliderBackend()
    return (
      RufletControl(id: 73, type: "RangeSlider", properties: properties, backend: backend),
      backend)
  }
}

private struct Event: Equatable {
  let name: String
  let data: RufletValue
}

@MainActor
private final class RangeSliderBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var updates: [[String: RufletValue]] = []
  var events: [Event] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    updates.append(properties)
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
