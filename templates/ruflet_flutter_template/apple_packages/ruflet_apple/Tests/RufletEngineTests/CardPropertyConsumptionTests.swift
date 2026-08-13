import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class CardPropertyConsumptionTests: XCTestCase {
  func testPinnedDefaultsKeepContentUnclippedAndBorderInForeground() {
    let presentation = RufletCardPresentation(
      control: control(properties: [
        "variant": .string("outlined")
      ]))

    XCTAssertEqual(presentation.variant, .outlined)
    XCTAssertEqual(presentation.clipBehavior, "none")
    XCTAssertFalse(presentation.clipsContent)
    XCTAssertFalse(presentation.antialiasedClip)
    XCTAssertTrue(presentation.showBorderOnForeground)
    XCTAssertEqual(presentation.borderLayer, .foreground)
    XCTAssertTrue(presentation.semanticContainer)
  }

  func testPinnedClipModesAndBackgroundBorderArePreserved() {
    let antialias = RufletCardPresentation(
      control: control(properties: [
        "variant": .string("outlined"),
        "clip_behavior": .string("antiAliasWithSaveLayer"),
        "show_border_on_foreground": .bool(false),
        "semantic_container": .bool(false),
      ]))

    XCTAssertTrue(antialias.clipsContent)
    XCTAssertTrue(antialias.antialiasedClip)
    XCTAssertEqual(antialias.borderLayer, .background)
    XCTAssertFalse(antialias.semanticContainer)

    let hardEdge = RufletCardPresentation(
      control: control(properties: [
        "variant": .string("filled"),
        "clip_behavior": .string("hardEdge"),
      ]))
    XCTAssertTrue(hardEdge.clipsContent)
    XCTAssertFalse(hardEdge.antialiasedClip)
    XCTAssertEqual(hardEdge.borderLayer, .none)
  }

  func testVariantElevationAndShapeDefaultsMatchPinnedCardContract() {
    let elevated = RufletCardPresentation(control: control(properties: [:]))
    XCTAssertEqual(elevated.variant, .elevated)
    XCTAssertEqual(elevated.elevation, 1)
    XCTAssertEqual(elevated.radius.uniform, 12)

    let filled = RufletCardPresentation(
      control: control(properties: [
        "variant": .string("filled"),
        "elevation": .double(4),
        "shape": .map(["border_radius": .double(7)]),
      ]))
    XCTAssertEqual(filled.elevation, 4)
    XCTAssertEqual(filled.radius.uniform, 7)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "Card",
      properties: properties,
      backend: CardTestBackend())
  }
}

@MainActor
private final class CardTestBackend: RufletBackendProtocol {
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
