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

  func testExplicitSafeAreaUsesMediaPaddingAndMinimumByMaximum() {
    let configuration = RufletSafeAreaConfiguration(
      control: control(properties: [
        "avoid_intrusions_right": .bool(false),
        "minimum_padding": .map([
          "left": .double(20),
          "top": .double(4),
          "right": .double(7),
          "bottom": .double(40),
        ]),
      ]))

    XCTAssertEqual(
      configuration.resolvedPadding(
        safeAreaInsets: RufletSafeAreaInsets(
          top: 59, leading: 12, bottom: 34, trailing: 12)),
      EdgeInsets(top: 59, leading: 20, bottom: 40, trailing: 7))
  }

  func testScaffoldBarsConsumeOnlyTheirMediaPaddingEdges() {
    let insets = RufletSafeAreaInsets(top: 59, leading: 4, bottom: 34, trailing: 5)

    XCTAssertEqual(
      rufletScaffoldBodySafeAreaInsets(insets, hasAppBar: true, hasBottomBar: true),
      RufletSafeAreaInsets(top: 0, leading: 4, bottom: 0, trailing: 5))
    XCTAssertEqual(
      rufletScaffoldBodySafeAreaInsets(insets, hasAppBar: false, hasBottomBar: false),
      insets)
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
