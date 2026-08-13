import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

@MainActor
final class SafeAreaPropertyConsumptionTests: XCTestCase {
  func testPinnedDefaultsDoNotMaintainPhysicalBottomInset() {
    let configuration = RufletSafeAreaConfiguration(control: control(properties: [:]))

    XCTAssertTrue(configuration.avoidsBottomIntrusion)
    XCTAssertFalse(configuration.maintainBottomViewPadding)
    XCTAssertEqual(
      RufletSafeAreaKeyboardInsetPolicy.additionalBottomInset(
        maintainBottomViewPadding: configuration.maintainBottomViewPadding,
        avoidsBottomIntrusion: configuration.avoidsBottomIntrusion,
        keyboardOverlap: 300,
        persistentBottomInset: 34
      ),
      0
    )
  }

  func testPinnedMaintainBottomViewPaddingSurvivesKeyboardOcclusion() {
    let configuration = RufletSafeAreaConfiguration(
      control: control(properties: ["maintain_bottom_view_padding": .bool(true)]))

    XCTAssertTrue(configuration.maintainBottomViewPadding)
    XCTAssertEqual(
      RufletSafeAreaKeyboardInsetPolicy.additionalBottomInset(
        maintainBottomViewPadding: configuration.maintainBottomViewPadding,
        avoidsBottomIntrusion: configuration.avoidsBottomIntrusion,
        keyboardOverlap: 300,
        persistentBottomInset: 34
      ),
      34
    )
  }

  func testMaintainedInsetRequiresBottomAvoidanceAndAnOccludingKeyboard() {
    for (avoidsBottom, keyboardOverlap) in [(false, CGFloat(300)), (true, CGFloat.zero)] {
      XCTAssertEqual(
        RufletSafeAreaKeyboardInsetPolicy.additionalBottomInset(
          maintainBottomViewPadding: true,
          avoidsBottomIntrusion: avoidsBottom,
          keyboardOverlap: keyboardOverlap,
          persistentBottomInset: 34
        ),
        0
      )
    }
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "SafeArea",
      properties: properties,
      backend: SafeAreaTestBackend())
  }
}

@MainActor
private final class SafeAreaTestBackend: RufletBackendProtocol {
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
