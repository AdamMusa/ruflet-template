import RufletApple
@testable import RufletAppExtensions
import SwiftUI
import XCTest

@MainActor
final class ExtensionContractTests: XCTestCase {
  func testApplicationExtensionCanCreateLayoutWrappedNativeControl() {
    let backend = ExtensionTestBackend()
    let control = RufletControl(
      id: 42,
      type: "Rating",
      properties: ["value": .int(3), "width": .int(180)],
      backend: backend)
    let appExtension = RatingContractExtension()

    XCTAssertEqual(appExtension.renderedControlTypes, ["Rating"])
    XCTAssertNotNil(appExtension.createView(for: control))
  }

  func testApplicationExtensionsKeepRegistrationOrder() {
    let backend = ExtensionTestBackend()
    let first = RatingContractExtension(marker: "first")
    let second = RatingContractExtension(marker: "second")
    let registry = RufletExtensionRegistry([first, second])
    let control = RufletControl(id: 7, type: "Rating", properties: [:], backend: backend)

    XCTAssertEqual(registry.renderedControlTypes, ["Rating"])
    XCTAssertNotNil(registry.view(for: control))
    XCTAssertEqual(first.initialization.value, 1)
    XCTAssertEqual(second.initialization.value, 1)
  }
}

@MainActor
private struct RatingContractExtension: RufletExtension {
  let marker: String
  let initialization: InitializationCounter

  init(marker: String = "rating") {
    self.init(marker: marker, initialization: InitializationCounter())
  }

  init(marker: String, initialization: InitializationCounter) {
    self.marker = marker
    self.initialization = initialization
  }

  var renderedControlTypes: Set<String> { ["Rating"] }

  func ensureInitialized() {
    initialization.value += 1
  }

  func createView(for control: RufletControl) -> AnyView? {
    guard control.type == "Rating" else { return nil }
    return AnyView(
      LayoutControl(control: control) {
        Text("\(marker):\(control.integer("value") ?? 0)")
      })
  }
}

@MainActor
private final class InitializationCounter {
  var value = 0
}

@MainActor
private final class ExtensionTestBackend: RufletBackendProtocol {
  var pageURI: URL?
  lazy var extensionRegistry = RufletExtensionRegistry([])

  func index(_: RufletControl) {}
  func triggerControlEvent(_: RufletControl, name _: String, data _: RufletValue) {}
  func triggerControlEvent(controlID _: Int, name _: String, data _: RufletValue) {}
  func updateControl(
    _: Int,
    properties _: [String: RufletValue],
    client _: Bool,
    server _: Bool,
    notify _: Bool
  ) {}
  func resolveAssetSource(_: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_: String, state _: RufletWindowState) {}
}
