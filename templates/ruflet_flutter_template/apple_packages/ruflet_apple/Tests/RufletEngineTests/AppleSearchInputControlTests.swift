import RufletProtocol
import XCTest
@testable import RufletEngine

@MainActor
final class AppleSearchInputControlTests: XCTestCase {
  func testAutoCompleteParsesAndFiltersPinnedSuggestionWireFormat() {
    let backend = SearchInputBackend()
    let control = RufletControl(
      id: 1,
      type: "AutoComplete",
      properties: [
        "value": "roc",
        "suggestions": [
          ["key": "ROCKET_LAUNCH", "value": "Rocket"],
          ["key": "home"],
          ["value": "Photo"],
          ["key": "", "value": ""],
        ],
      ],
      backend: backend)
    let coordinator = RufletAutoCompleteCoordinator(control: control)

    XCTAssertEqual(
      coordinator.suggestions,
      [
        AutoCompleteSuggestion(key: "ROCKET_LAUNCH", value: "Rocket"),
        AutoCompleteSuggestion(key: "home", value: "home"),
        AutoCompleteSuggestion(key: "Photo", value: "Photo"),
      ])
    XCTAssertEqual(
      coordinator.filteredSuggestions,
      [AutoCompleteSuggestion(key: "ROCKET_LAUNCH", value: "Rocket")])
  }

  func testAutoCompleteSelectionEmitsImmediateChangeThenPinnedSelection() {
    let backend = SearchInputBackend()
    let control = RufletControl(
      id: 2,
      type: "AutoComplete",
      properties: [
        "value": "ro",
        "suggestions": [["key": "ROCKET_LAUNCH", "value": "Rocket"]],
      ],
      backend: backend)
    let coordinator = RufletAutoCompleteCoordinator(control: control)

    coordinator.select(
      AutoCompleteSuggestion(key: "ROCKET_LAUNCH", value: "Rocket"),
      originalIndex: 0)

    XCTAssertEqual(backend.updates.map(\.properties), [
      ["value": "Rocket"],
      ["_selected_index": 0],
    ])
    XCTAssertEqual(backend.events.map(\.name), ["change", "select"])
    XCTAssertEqual(backend.events[0].data, "Rocket")
    XCTAssertEqual(backend.events[1].data, [
      "index": 0,
      "selection": ["key": "ROCKET_LAUNCH", "value": "Rocket"],
    ])
  }

  func testSearchBarMaintainsImmediateCapitalizedStateAndConditionalCallbacks() {
    let backend = SearchInputBackend()
    let control = RufletControl(
      id: 3,
      type: "SearchBar",
      properties: [
        "capitalization": "characters",
        "on_change": true,
        "on_submit": true,
        "on_tap": true,
        "on_tap_outside_bar": true,
      ],
      backend: backend)
    let coordinator = RufletSearchBarCoordinator(control: control)

    coordinator.textChanged("native apple")
    XCTAssertEqual(coordinator.value, "NATIVE APPLE")
    coordinator.tapped()
    coordinator.tappedOutside()
    coordinator.focusChanged(true)
    coordinator.focusChanged(false)
    coordinator.submitted("swift")

    XCTAssertEqual(backend.updates.map(\.properties), [
      ["value": "NATIVE APPLE"],
      ["value": "SWIFT"],
    ])
    XCTAssertEqual(backend.events.map(\.name), [
      "change", "tap", "tap_outside_bar", "focus", "blur", "change", "submit",
    ])
    XCTAssertEqual(backend.events.last?.data, "SWIFT")
  }

  func testSearchBarMethodsMatchPinnedOpenCloseAndFocusContract() throws {
    let backend = SearchInputBackend()
    let control = RufletControl(
      id: 4,
      type: "SearchBar",
      properties: ["capitalization": "words"],
      backend: backend)
    let coordinator = RufletSearchBarCoordinator(control: control)

    XCTAssertEqual(try coordinator.invoke("open_view", args: .null), .null)
    XCTAssertTrue(coordinator.isOpen)
    XCTAssertEqual(
      try coordinator.invoke("close_view", args: ["text": "hello APPLE"]),
      .null)
    XCTAssertFalse(coordinator.isOpen)
    XCTAssertEqual(coordinator.value, "Hello Apple")
    XCTAssertEqual(backend.updates.last?.properties, ["value": "Hello Apple"])

    let priorFocusRequest = coordinator.focusRequest
    XCTAssertEqual(try coordinator.invoke("focus", args: .null), .null)
    XCTAssertEqual(coordinator.focusRequest, priorFocusRequest + 1)
    XCTAssertThrowsError(try coordinator.invoke("unsupported", args: .null)) { error in
      XCTAssertEqual(error as? RufletSearchBarError, .unknownMethod("unsupported"))
    }
  }

  func testAutofillGroupScopeDefaultsToCommitAndPreservesCancel() {
    let backend = SearchInputBackend()
    let defaultControl = RufletControl(
      id: 5, type: "AutofillGroup", properties: [:], backend: backend)
    let cancelControl = RufletControl(
      id: 6,
      type: "AutofillGroup",
      properties: ["dispose_action": "cancel"],
      backend: backend)

    XCTAssertEqual(defaultControl.id, AutofillGroupControl(control: defaultControl).scope.controlID)
    XCTAssertEqual(
      AutofillGroupControl(control: defaultControl).scope.disposeAction,
      .commit)
    XCTAssertEqual(
      AutofillGroupControl(control: cancelControl).scope.disposeAction,
      .cancel)
  }
}

@MainActor
private final class SearchInputBackend: RufletBackendProtocol {
  struct Update: Equatable {
    let controlID: Int
    let properties: [String: RufletValue]
  }

  struct Event: Equatable {
    let controlID: Int
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var updates: [Update] = []
  var events: [Event] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(controlID: control.id, name: name, data: data))
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(controlID: controlID, name: name, data: data))
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    updates.append(Update(controlID: id, properties: properties))
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
