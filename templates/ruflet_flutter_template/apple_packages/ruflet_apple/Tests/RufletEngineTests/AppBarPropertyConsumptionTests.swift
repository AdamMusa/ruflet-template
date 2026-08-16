import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class AppBarPropertyConsumptionTests: XCTestCase {
  func testPinnedDefaultsKeepMaterialBackgroundAndDoNotClip() {
    let presentation = RufletAppBarPresentation(control: control(properties: [:]))

    XCTAssertEqual(presentation.clipBehavior, "none")
    XCTAssertFalse(presentation.clipsContent)
    XCTAssertFalse(presentation.antialiasedClip)
    XCTAssertFalse(presentation.forceTransparency)
  }

  func testPinnedClipModesSelectNativeShapeClipping() {
    let hardEdge = RufletAppBarPresentation(
      control: control(properties: ["clip_behavior": .string("hardEdge")]))
    XCTAssertTrue(hardEdge.clipsContent)
    XCTAssertFalse(hardEdge.antialiasedClip)

    let antialias = RufletAppBarPresentation(
      control: control(properties: ["clip_behavior": .string("antiAliasWithSaveLayer")]))
    XCTAssertTrue(antialias.clipsContent)
    XCTAssertTrue(antialias.antialiasedClip)
  }

  func testForcedMaterialTransparencyDoesNotLeakIntoCupertinoBar() {
    let control = control(properties: ["force_material_transparency": .bool(true)])

    XCTAssertTrue(RufletAppBarPresentation(control: control).forceTransparency)
    XCTAssertFalse(
      RufletAppBarPresentation(control: control, isMaterial: false).forceTransparency)
  }

  func testMaterialTitleCenteringFollowsExplicitThemeAndPlatformPrecedence() {
    XCTAssertTrue(rufletMaterialAppBarCenterTitle(
      explicit: true, themed: false, centersByPlatformDefault: false, actionCount: 3))
    XCTAssertFalse(rufletMaterialAppBarCenterTitle(
      explicit: nil, themed: false, centersByPlatformDefault: true, actionCount: 0))
    XCTAssertTrue(rufletMaterialAppBarCenterTitle(
      explicit: nil, themed: nil, centersByPlatformDefault: true, actionCount: 1))
    XCTAssertFalse(rufletMaterialAppBarCenterTitle(
      explicit: nil, themed: nil, centersByPlatformDefault: true, actionCount: 2))
    XCTAssertFalse(rufletMaterialAppBarCenterTitle(
      explicit: nil, themed: nil, centersByPlatformDefault: false, actionCount: 0))
  }

  func testTitleSpacingFollowsExplicitThemeAndPinnedDefaultPrecedence() {
    XCTAssertEqual(rufletAppBarTitleSpacing(explicit: 8, themed: 12), 8)
    XCTAssertEqual(rufletAppBarTitleSpacing(explicit: nil, themed: 12), 12)
    XCTAssertEqual(rufletAppBarTitleSpacing(explicit: nil, themed: nil), 16)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "AppBar",
      properties: properties,
      backend: AppBarTestBackend())
  }
}

@MainActor
private final class AppBarTestBackend: RufletBackendProtocol {
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
