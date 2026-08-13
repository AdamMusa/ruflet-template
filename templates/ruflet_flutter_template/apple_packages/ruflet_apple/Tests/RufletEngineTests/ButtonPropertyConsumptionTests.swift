import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class ButtonPropertyConsumptionTests: XCTestCase {
  func testEveryMaterialButtonVariantDefaultsToNoClip() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let style = style(for: type, properties: [:])
      XCTAssertEqual(style.clipBehavior, "none", type)
      XCTAssertFalse(style.clipsContent, type)
      XCTAssertFalse(style.antialiasedClip, type)
    }
  }

  func testSharedStylePreservesHardEdgeAndAntialiasModes() {
    let hardEdge = style(for: "Button", properties: ["clip_behavior": .string("hardEdge")])
    XCTAssertTrue(hardEdge.clipsContent)
    XCTAssertFalse(hardEdge.antialiasedClip)

    let antialias = style(
      for: "FilledButton",
      properties: ["clip_behavior": .string("antiAliasWithSaveLayer")])
    XCTAssertTrue(antialias.clipsContent)
    XCTAssertTrue(antialias.antialiasedClip)
  }

  private func style(
    for type: String,
    properties: [String: RufletValue]
  ) -> RufletAppleButtonStyle {
    let control = RufletControl(
      id: 1,
      type: type,
      properties: properties,
      backend: ButtonPropertyTestBackend())
    return ButtonControl(control: control).buttonStyle
  }
}

@MainActor
private final class ButtonPropertyTestBackend: RufletBackendProtocol {
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
