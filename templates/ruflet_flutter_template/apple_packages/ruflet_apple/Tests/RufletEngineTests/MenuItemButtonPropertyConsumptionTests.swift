import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class MenuItemButtonPropertyConsumptionTests: XCTestCase {
  func testPinnedDefaultDoesNotClipMenuItemContent() {
    let appearance = RufletMenuButtonAppearance(control: control(properties: [:]))

    XCTAssertEqual(appearance.clipBehavior, "none")
    XCTAssertFalse(appearance.clipsContent)
    XCTAssertFalse(appearance.antialiasedClip)
  }

  func testPinnedClipModesPreserveHardAndAntialiasedEdges() {
    let hardEdge = RufletMenuButtonAppearance(
      control: control(properties: ["clip_behavior": .string("hardEdge")]))
    XCTAssertTrue(hardEdge.clipsContent)
    XCTAssertFalse(hardEdge.antialiasedClip)

    let antialias = RufletMenuButtonAppearance(
      control: control(properties: ["clip_behavior": .string("antiAliasWithSaveLayer")]))
    XCTAssertTrue(antialias.clipsContent)
    XCTAssertTrue(antialias.antialiasedClip)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "MenuItemButton",
      properties: properties,
      backend: MenuItemButtonTestBackend())
  }
}

@MainActor
private final class MenuItemButtonTestBackend: RufletBackendProtocol {
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
