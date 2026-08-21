import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

#if os(macOS)
  import AppKit
#endif

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

  func testCardUsesActiveFletThemeBeforeMaterialDefaults() {
    let theme = parseTheme(
      [
        "card_theme": [
          "color": "#112233",
          "shadow_color": "#445566",
          "elevation": 6,
          "clip_behavior": "hardEdge",
          "margin": 9,
        ]
      ],
      brightness: .dark)
    let themed = RufletCardPresentation(control: control(properties: [:]), theme: theme)

    assertColor(themed.backgroundColor, rgb: (0x11, 0x22, 0x33))
    assertColor(themed.shadowColor, rgb: (0x44, 0x55, 0x66))
    XCTAssertEqual(themed.elevation, 6)
    XCTAssertEqual(themed.clipBehavior, "hardedge")
    XCTAssertEqual(themed.margin.top, 9)
    XCTAssertEqual(themed.margin.leading, 9)

    let explicit = RufletCardPresentation(
      control: control(properties: [
        "bgcolor": .string("#AABBCC"),
        "elevation": .double(2),
      ]),
      theme: theme)
    assertColor(explicit.backgroundColor, rgb: (0xAA, 0xBB, 0xCC))
    XCTAssertEqual(explicit.elevation, 2)
  }

  func testCardVariantsUsePinnedMaterialThreeSurfaceRoles() {
    let theme = parseTheme([:], brightness: .dark)
    let elevated = RufletCardPresentation(control: control(properties: [:]), theme: theme)
    let filled = RufletCardPresentation(
      control: control(properties: ["variant": .string("filled")]), theme: theme)
    let outlined = RufletCardPresentation(
      control: control(properties: ["variant": .string("outlined")]), theme: theme)

    assertSameColor(elevated.backgroundColor, theme.colorScheme?["surface_container_low"])
    assertSameColor(filled.backgroundColor, theme.colorScheme?["surface_container_highest"])
    assertSameColor(outlined.backgroundColor, theme.colorScheme?["surface"])
    XCTAssertNotNil(outlined.borderSide)
  }

  func testElevationShadowsOnlyTheCardSurface() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(
      contentsOf: root.appendingPathComponent("Sources/RufletEngine/Controls/card.swift"),
      encoding: .utf8)

    XCTAssertTrue(source.contains("shape\n          .fill(presentation.backgroundColor)\n          .shadow("))
    XCTAssertEqual(source.components(separatedBy: ".shadow(").count - 1, 1)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "Card",
      properties: properties,
      backend: CardTestBackend())
  }

  private func assertColor(
    _ color: Color,
    rgb: (Int, Int, Int),
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    #if os(macOS)
      guard let native = NSColor(color).usingColorSpace(.sRGB) else {
        return XCTFail("Expected an sRGB color", file: file, line: line)
      }
      XCTAssertEqual(
        native.redComponent, CGFloat(rgb.0) / 255, accuracy: 0.002, file: file, line: line)
      XCTAssertEqual(
        native.greenComponent, CGFloat(rgb.1) / 255, accuracy: 0.002, file: file, line: line)
      XCTAssertEqual(
        native.blueComponent, CGFloat(rgb.2) / 255, accuracy: 0.002, file: file, line: line)
    #else
      XCTAssertTrue(true)
    #endif
  }

  private func assertSameColor(
    _ actual: Color,
    _ expected: Color?,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    #if os(macOS)
      guard let expected,
        let actualNative = NSColor(actual).usingColorSpace(.sRGB),
        let expectedNative = NSColor(expected).usingColorSpace(.sRGB)
      else {
        return XCTFail("Expected comparable sRGB colors", file: file, line: line)
      }
      XCTAssertEqual(
        actualNative.redComponent, expectedNative.redComponent, accuracy: 0.002,
        file: file, line: line)
      XCTAssertEqual(
        actualNative.greenComponent, expectedNative.greenComponent, accuracy: 0.002,
        file: file, line: line)
      XCTAssertEqual(
        actualNative.blueComponent, expectedNative.blueComponent, accuracy: 0.002,
        file: file, line: line)
    #else
      XCTAssertNotNil(expected, file: file, line: line)
    #endif
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
