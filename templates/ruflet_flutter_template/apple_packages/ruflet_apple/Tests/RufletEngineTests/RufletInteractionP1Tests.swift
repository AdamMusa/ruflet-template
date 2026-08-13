import RufletProtocol
import SwiftUI
import XCTest
@testable import RufletEngine

@MainActor
final class RufletInteractionP1Tests: XCTestCase {
  func testCheckboxActivationProducesExactlyOneUpdateAndChangeEvent() {
    let backend = InteractionBackend()
    let control = RufletControl(
      id: 1,
      type: "Checkbox",
      properties: ["value": false],
      backend: backend)

    rufletActivateCheckbox(control: control, current: false, tristate: false)

    XCTAssertEqual(backend.updates.count, 1)
    XCTAssertEqual(backend.updates[0].properties, ["value": true])
    XCTAssertTrue(backend.updates[0].notify)
    XCTAssertEqual(backend.events.count, 1)
    XCTAssertEqual(backend.events[0].name, "change")
    XCTAssertEqual(backend.events[0].data, true)
  }

  func testCheckboxTristateCycleMatchesPinnedControl() {
    XCTAssertEqual(rufletNextCheckboxValue(current: nil, tristate: true), false)
    XCTAssertEqual(rufletNextCheckboxValue(current: false, tristate: true), true)
    XCTAssertEqual(rufletNextCheckboxValue(current: true, tristate: true), .null)
    XCTAssertEqual(rufletNextCheckboxValue(current: true, tristate: false), false)
  }

  func testRadioActivationWritesBindingExactlyOnce() {
    var selection: String? = "one"
    var writes = 0
    let binding = Binding<String?>(
      get: { selection },
      set: {
        writes += 1
        selection = $0
      })

    rufletActivateRadio(
      selection: binding,
      selected: false,
      toggleable: false,
      value: "two")

    XCTAssertEqual(writes, 1)
    XCTAssertEqual(selection, "two")
    XCTAssertNil(rufletNextRadioSelection(selected: true, toggleable: true, value: "two"))
  }

  func testTextEditFiltersBeforeCapitalizationAndMapsExpandedCaret() throws {
    let filter = RufletInputFilter(
      expression: try NSRegularExpression(pattern: "^[a-zß]*$"),
      allow: true,
      replacementString: "")
    let current = RufletTextEditSnapshot(
      text: "aß",
      selection: NSRange(location: 2, length: 0),
      composing: nil)

    let transaction = try XCTUnwrap(formatRufletTextEdit(
      current: current,
      replacementRange: NSRange(location: 2, length: 0),
      replacement: "c",
      capitalization: .characters,
      maxLength: nil,
      inputFilter: filter))

    // The lowercase raw edit passes the pinned filter before capitalization.
    XCTAssertEqual(transaction.rawValue.text, "aßc")
    XCTAssertEqual(transaction.formattedValue.text, "ASSC")
    XCTAssertEqual(transaction.formattedValue.selection, NSRange(location: 4, length: 0))
    XCTAssertTrue(transaction.requiresManualMutation)
  }

  func testTextEditRejectsInvalidFilterAndMaximumLengthBeforeNativeMutation() throws {
    let filter = RufletInputFilter(
      expression: try NSRegularExpression(pattern: "^[0-9]*$"),
      allow: true,
      replacementString: "")
    let current = RufletTextEditSnapshot(
      text: "12",
      selection: NSRange(location: 2, length: 0),
      composing: nil)

    XCTAssertNil(formatRufletTextEdit(
      current: current,
      replacementRange: NSRange(location: 2, length: 0),
      replacement: "a",
      capitalization: .none,
      maxLength: nil,
      inputFilter: filter))
    XCTAssertNil(formatRufletTextEdit(
      current: current,
      replacementRange: NSRange(location: 2, length: 0),
      replacement: "3",
      capitalization: .none,
      maxLength: 2,
      inputFilter: filter))
  }

  func testTextEditPreservesCompositionAcrossCapitalization() throws {
    let current = RufletTextEditSnapshot(
      text: "ab",
      selection: NSRange(location: 2, length: 0),
      composing: NSRange(location: 0, length: 2))

    let transaction = try XCTUnwrap(formatRufletTextEdit(
      current: current,
      replacementRange: NSRange(location: 1, length: 1),
      replacement: "ß",
      capitalization: .characters,
      maxLength: nil,
      inputFilter: nil))

    XCTAssertEqual(transaction.rawValue.composing, NSRange(location: 0, length: 2))
    XCTAssertEqual(transaction.formattedValue.text, "ASS")
    XCTAssertEqual(transaction.formattedValue.selection, NSRange(location: 3, length: 0))
    XCTAssertEqual(transaction.formattedValue.composing, NSRange(location: 0, length: 3))
  }
}

@MainActor
private final class InteractionBackend: RufletBackendProtocol {
  struct Update: Equatable {
    let properties: [String: RufletValue]
    let notify: Bool
  }

  struct Event: Equatable {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var updates: [Update] = []
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
    updates.append(Update(properties: properties, notify: notify))
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
