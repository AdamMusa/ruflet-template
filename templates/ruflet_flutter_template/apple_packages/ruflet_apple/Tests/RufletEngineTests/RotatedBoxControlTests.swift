import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class RotatedBoxControlTests: XCTestCase {
  func testQuarterTurnsNormalizeAcrossPositiveAndNegativeRotations() {
    let expected = [
      (-5, 3), (-4, 0), (-3, 1), (-2, 2), (-1, 3),
      (0, 0), (1, 1), (2, 2), (3, 3), (4, 0), (5, 1),
    ]

    for (input, normalized) in expected {
      XCTAssertEqual(RufletRotatedBoxPresentation.normalized(input), normalized)
    }
  }

  func testOddQuarterTurnsSwapNativeLayoutDimensions() {
    for turns in 0..<4 {
      let presentation = RufletRotatedBoxPresentation(
        control: control(properties: ["quarter_turns": .int(Int64(turns))]))
      XCTAssertEqual(presentation.swapsDimensions, turns == 1 || turns == 3)
      XCTAssertEqual(presentation.angle.degrees, Double(turns * 90))
    }
  }

  func testCoreRegistryClaimsAndCreatesRufletCompatibilityWireType() {
    let backend = RotatedBoxTestBackend()
    let extensionRegistry = backend.extensionRegistry
    let control = RufletControl(
      id: 1,
      type: "RotatedBox",
      properties: [:],
      backend: backend)

    XCTAssertTrue(extensionRegistry.renderedControlTypes.contains("RotatedBox"))
    XCTAssertNotNil(extensionRegistry.view(for: control))
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "RotatedBox",
      properties: properties,
      backend: RotatedBoxTestBackend())
  }
}

@MainActor
private final class RotatedBoxTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  lazy var extensionRegistry = RufletExtensionRegistry([RufletCoreExtension()])

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
