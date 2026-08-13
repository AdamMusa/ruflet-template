import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class SnackBarPropertyConsumptionTests: XCTestCase {
  func testPinnedDefaultUsesHardEdgeClipping() {
    let presentation = RufletSnackBarPresentation(control: control(properties: [:]))

    XCTAssertEqual(presentation.clipBehavior, "hardedge")
    XCTAssertTrue(presentation.clipsContent)
    XCTAssertFalse(presentation.antialiasedClip)
  }

  func testNoneAndAntialiasModesRemainDistinct() {
    let none = RufletSnackBarPresentation(
      control: control(properties: ["clip_behavior": .string("none")]))
    XCTAssertFalse(none.clipsContent)

    for value in ["antiAlias", "antiAliasWithSaveLayer"] {
      let presentation = RufletSnackBarPresentation(
        control: control(properties: ["clip_behavior": .string(value)]))
      XCTAssertTrue(presentation.clipsContent)
      XCTAssertTrue(presentation.antialiasedClip)
    }
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "SnackBar",
      properties: properties,
      backend: SnackBarPropertyTestBackend())
  }
}

@MainActor
private final class SnackBarPropertyTestBackend: RufletBackendProtocol {
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
