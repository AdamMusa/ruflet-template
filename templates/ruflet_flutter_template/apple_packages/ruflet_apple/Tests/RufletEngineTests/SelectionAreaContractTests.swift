import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class SelectionAreaContractTests: XCTestCase {
  func testSelectionChangeEmitsOnlyTheSelectedPlainText() {
    let backend = SelectionAreaTestBackend()
    let control = RufletControl(
      id: 1,
      type: "SelectionArea",
      properties: ["on_change": .bool(true)],
      backend: backend)

    rufletSelectionAreaChanged(
      control: control,
      text: "hello native world",
      selection: RufletTextSelection(baseOffset: 6, extentOffset: 12))

    XCTAssertEqual(backend.events, [.string("native")])
  }

  func testCollapsedSelectionEmitsFletNull() {
    let backend = SelectionAreaTestBackend()
    let control = RufletControl(
      id: 1,
      type: "SelectionArea",
      properties: ["on_change": .bool(true)],
      backend: backend)

    rufletSelectionAreaChanged(
      control: control,
      text: "hello",
      selection: RufletTextSelection(baseOffset: 2, extentOffset: 2))

    XCTAssertEqual(backend.events, [.null])
  }
}

@MainActor
private final class SelectionAreaTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  lazy var extensionRegistry = RufletExtensionRegistry([])
  var events: [RufletValue] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    if name == "change" { events.append(data) }
  }
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
