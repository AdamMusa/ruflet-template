import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class InteractiveViewerPropertyConsumptionTests: XCTestCase {
  func testPinnedPointerDefaultsPanWithoutTrackpadScaling() {
    let configuration = RufletInteractivePointerConfiguration(control: control(properties: [:]))

    XCTAssertEqual(configuration.scaleFactor, 200)
    XCTAssertFalse(configuration.trackpadScrollCausesScale)
    XCTAssertEqual(configuration.scaleMultiplier(for: 0), 1)
    XCTAssertEqual(
      configuration.scaleMultiplier(for: 200),
      Foundation.exp(-1),
      accuracy: 0.000_001)
  }

  func testPinnedScaleFactorControlsExponentialTrackpadZoom() {
    let configuration = RufletInteractivePointerConfiguration(
      control: control(properties: [
        "scale_factor": .double(100),
        "trackpad_scroll_causes_scale": .bool(true),
      ]))

    XCTAssertEqual(configuration.scaleFactor, 100)
    XCTAssertTrue(configuration.trackpadScrollCausesScale)
    XCTAssertEqual(
      configuration.scaleMultiplier(for: -100),
      Foundation.exp(1),
      accuracy: 0.000_001)
    XCTAssertEqual(
      configuration.scaleMultiplier(for: 50),
      Foundation.exp(-0.5),
      accuracy: 0.000_001)
  }

  func testInvalidScaleFactorRemainsFinite() {
    let configuration = RufletInteractivePointerConfiguration(
      control: control(properties: [
        "scale_factor": .double(0)
      ]))

    XCTAssertGreaterThan(configuration.scaleFactor, 0)
    XCTAssertTrue(configuration.scaleMultiplier(for: 1).isFinite)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "InteractiveViewer",
      properties: properties,
      backend: InteractiveViewerTestBackend())
  }
}

@MainActor
private final class InteractiveViewerTestBackend: RufletBackendProtocol {
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
