import Foundation
import RufletProtocol
import Testing

@testable import RufletEngine

@MainActor
@Suite("Pinned Flet CupertinoPicker contract")
struct CupertinoPickerControlTests {
  @Test("wire properties retain pinned defaults")
  func defaults() {
    let configuration = RufletCupertinoPickerConfiguration(control: makePicker())

    #expect(configuration.diameterRatio == 1.07)
    #expect(!configuration.looping)
    #expect(configuration.magnification == 1)
    #expect(configuration.offAxisFraction == 0)
    #expect(configuration.squeeze == 1.45)
    #expect(!configuration.useMagnifier)
    #expect(configuration.itemExtent == 32)
    #expect(configuration.rowPitch == 32)
  }

  @Test("all native wheel geometry properties are consumed")
  func geometry() {
    let configuration = RufletCupertinoPickerConfiguration(
      control: makePicker(properties: [
        "diameter_ratio": 2.4,
        "looping": true,
        "magnification": 1.3,
        "off_axis_fraction": -0.4,
        "squeeze": 2.9,
        "use_magnifier": true,
        "item_extent": 40,
      ]))

    #expect(configuration.diameterRatio == 2.4)
    #expect(configuration.looping)
    #expect(configuration.magnification == 1.3)
    #expect(configuration.offAxisFraction == -0.4)
    #expect(configuration.squeeze == 2.9)
    #expect(configuration.useMagnifier)
    #expect(configuration.itemExtent == 40)
    #expect(configuration.rowPitch == 20)
    #expect(configuration.scale(forDistance: 0) == 1.3)
    #expect(configuration.scale(forDistance: 2) < 1)
    #expect(configuration.horizontalOffset(availableWidth: 300) == -60)
  }

  @Test("looping projects an odd centered virtual wheel onto exact child indices")
  func loopingProjection() {
    let configuration = RufletCupertinoPickerConfiguration(
      control: makePicker(properties: ["looping": true, "selected_index": 2]))

    #expect(configuration.rowCount(for: 4) == 4_004)
    #expect(configuration.initialRow(selectedIndex: 2, itemCount: 4) == 2_002)
    #expect(configuration.itemIndex(forRow: 2_002, itemCount: 4) == 2)
    #expect(configuration.itemIndex(forRow: -1, itemCount: 4) == 3)
    #expect(configuration.nearestRow(selectedIndex: 0, to: 2_003, itemCount: 4) == 2_004)
  }

  @Test("finite wheels clamp server selection and have no rows when empty")
  func finiteProjection() {
    let configuration = RufletCupertinoPickerConfiguration(control: makePicker())

    #expect(configuration.rowCount(for: 0) == 0)
    #expect(configuration.itemIndex(forRow: 0, itemCount: 0) == nil)
    #expect(configuration.initialRow(selectedIndex: 40, itemCount: 3) == 2)
    #expect(configuration.nearestRow(selectedIndex: -2, to: 2, itemCount: 3) == 0)
  }

  private func makePicker(
    properties: [String: RufletValue] = [:]
  ) -> RufletControl {
    RufletControl(
      id: 1,
      type: "CupertinoPicker",
      properties: properties,
      backend: CupertinoPickerTestBackend())
  }
}

@MainActor
private final class CupertinoPickerTestBackend: RufletBackendProtocol {
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
