@testable import RufletDataTable2
import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

final class DataTable2PropertyTests: XCTestCase {
  @MainActor
  func testPassiveRowsAndCellsDoNotInstallCompetingRecognizers() {
    let backend = DataTable2PropertyTestBackend()
    let passive = RufletControl(id: 1, type: "DataCell", properties: [:], backend: backend)
    let active = RufletControl(
      id: 2,
      type: "DataCell",
      properties: ["on_tap": true, "on_long_press": true, "on_tap_down": true],
      backend: backend)

    let passiveContract = RufletDataTable2InteractionContract(control: passive)
    XCTAssertFalse(passiveContract.handlesTap)
    XCTAssertFalse(passiveContract.handlesDoubleTap)
    XCTAssertFalse(passiveContract.handlesLongPress)
    XCTAssertFalse(passiveContract.handlesTapDown)
    XCTAssertFalse(passiveContract.handlesTapCancel)

    let activeContract = RufletDataTable2InteractionContract(control: active)
    XCTAssertTrue(activeContract.handlesTap)
    XCTAssertTrue(activeContract.handlesLongPress)
    XCTAssertTrue(activeContract.handlesTapDown)
  }

  func testCheckboxThemeConsumesPinnedFillCheckBorderAndShape() {
    let theme: RufletValue = .map([
      "fill_color": .map([
        "selected": .string("#112233"),
        "default": .string("#445566"),
      ]),
      "check_color": .string("#ffffff"),
      "border_side": .map([
        "color": .string("#abcdef"), "width": .double(3),
      ]),
      "shape": .map([
        "_type": .string("RoundedRectangleBorder"), "radius": .double(6),
      ]),
    ])

    let selected = RufletDataTable2CheckboxStyle(
      theme: theme, state: .checked, enabled: true)
    let unselected = RufletDataTable2CheckboxStyle(
      theme: theme, state: .unchecked, enabled: true)
    XCTAssertEqual(selected.borderWidth, 3)
    XCTAssertEqual(selected.cornerRadius, 6)
    XCTAssertNotEqual(String(describing: selected.fill), String(describing: unselected.fill))
  }

  func testCheckboxCircleShapeAndDurationDefaultsMatchPinnedDataTable2() {
    let theme: RufletValue = .map([
      "shape": .map(["_type": .string("CircleBorder")]),
    ])
    XCTAssertEqual(
      RufletDataTable2CheckboxStyle(
        theme: theme, state: .mixed, enabled: true).cornerRadius,
      9)
    XCTAssertEqual(rufletDataTable2Duration(nil), 0.000_150, accuracy: 0.000_000_1)
    XCTAssertEqual(
      rufletDataTable2Duration(.int(250)), 0.25, accuracy: 0.000_000_1)
  }
}

@MainActor
private final class DataTable2PropertyTestBackend: RufletBackendProtocol {
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
