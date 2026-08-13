import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class BottomAppBarPropertyConsumptionTests: XCTestCase {
  func testPinnedDefaultWithoutRadiusDoesNotClip() {
    let presentation = RufletBottomAppBarPresentation(control: control(properties: [:]))

    XCTAssertFalse(presentation.hasBorderRadius)
    XCTAssertEqual(presentation.clipBehavior, "none")
    XCTAssertFalse(presentation.clipsContent)
  }

  func testRoundedBarsFallBackToAntialiasedClip() {
    for explicit in [nil, "none"] as [String?] {
      var properties: [String: RufletValue] = ["border_radius": .double(12)]
      if let explicit { properties["clip_behavior"] = .string(explicit) }
      let presentation = RufletBottomAppBarPresentation(control: control(properties: properties))

      XCTAssertTrue(presentation.hasBorderRadius)
      XCTAssertEqual(presentation.clipBehavior, "antialias")
      XCTAssertTrue(presentation.clipsContent)
      XCTAssertTrue(presentation.antialiasedClip)
    }
  }

  func testExplicitHardEdgeRemainsNonAntialiased() {
    let presentation = RufletBottomAppBarPresentation(
      control: control(properties: [
        "border_radius": .double(12),
        "clip_behavior": .string("hardEdge"),
      ]))

    XCTAssertTrue(presentation.clipsContent)
    XCTAssertFalse(presentation.antialiasedClip)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "BottomAppBar",
      properties: properties,
      backend: BottomAppBarTestBackend())
  }
}

@MainActor
private final class BottomAppBarTestBackend: RufletBackendProtocol {
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
