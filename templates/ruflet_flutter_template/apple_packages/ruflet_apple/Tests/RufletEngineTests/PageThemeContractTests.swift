import SwiftUI
import XCTest

@testable import RufletEngine

#if os(macOS)
  import AppKit
#endif

final class PageThemeContractTests: XCTestCase {
  func testMissingDarkThemeReparsesThemeAtDarkBrightness() {
    let themes = parsePageThemes(
      theme: [
        "font_family": "Avenir Next",
        "color_scheme": ["primary": "#123456"],
      ],
      darkTheme: nil)

    XCTAssertEqual(themes.light.brightness, .light)
    XCTAssertEqual(themes.dark.brightness, .dark)
    XCTAssertEqual(themes.light.fontFamily, "Avenir Next")
    XCTAssertEqual(themes.dark.fontFamily, "Avenir Next")
    assertColor(themes.light.appleAccentColor, rgb: (0x12, 0x34, 0x56))
    assertColor(themes.dark.appleAccentColor, rgb: (0x12, 0x34, 0x56))
  }

  func testExplicitDarkThemeAndThemeModeSelectionMatchPinnedPage() {
    let themes = parsePageThemes(
      theme: ["font_family": "Light Family"],
      darkTheme: ["font_family": "Dark Family"])

    XCTAssertEqual(
      themes.active(themeMode: .light, systemColorScheme: .dark).fontFamily,
      "Light Family")
    XCTAssertEqual(
      themes.active(themeMode: .dark, systemColorScheme: .light).fontFamily,
      "Dark Family")
    XCTAssertEqual(
      themes.active(themeMode: .system, systemColorScheme: .light).fontFamily,
      "Light Family")
    XCTAssertEqual(
      themes.active(themeMode: .system, systemColorScheme: .dark).fontFamily,
      "Dark Family")
  }

  func testApplePresentationUsesPinnedScaffoldBarAndForegroundPrecedence() {
    let theme = parseCupertinoTheme(
      [
        "color_scheme_seed": "#010203",
        "scaffold_bgcolor": "#112233",
        "color_scheme": [
          "primary": "#445566",
          "surface": "#778899",
          "on_surface": "#AABBCC",
        ],
        "text_theme": [
          "body_medium": [
            "size": 18,
            "font_family": "Body Family",
            "color": "#DDEEFF",
          ]
        ],
      ], brightness: .light)

    assertColor(theme.appleAccentColor, rgb: (0x44, 0x55, 0x66))
    assertColor(theme.applePageBackgroundColor, rgb: (0x11, 0x22, 0x33))
    assertColor(theme.appleBarBackgroundColor, rgb: (0x77, 0x88, 0x99))
    assertColor(theme.appleContentColor, rgb: (0xAA, 0xBB, 0xCC))
    XCTAssertEqual(theme.appleBodyTextStyle?.size, 18)
    XCTAssertEqual(theme.appleBodyTextStyle?.fontFamily, "Body Family")
  }

  func testAppleRendererExposesOnlyCupertinoPageDesign() {
    XCTAssertEqual(RufletPageDesign.cupertino.rawValue, "cupertino")
  }

  @MainActor
  func testControlThemeInheritsParentOnlyWithoutExplicitMode() {
    let backend = RufletBackend(
      pageURL: URL(string: "http://127.0.0.1:8550")!,
      assetsDirectory: "")
    defer { backend.dispose() }
    let control = RufletControl(
      id: 30,
      type: "Container",
      properties: [
        "theme": .map(["font_family": .string("Child Family")])
      ],
      backend: backend)
    let parent = parseCupertinoTheme(
      [
        "font_family": "Parent Family",
        "color_scheme": ["primary": "#112233"],
      ], brightness: .dark)

    let inherited = rufletControlThemeContext(
      control: control,
      inheritedMode: .light,
      inheritedTheme: parent,
      platformBrightness: .dark)
    XCTAssertEqual(inherited?.mode, .light)
    XCTAssertEqual(inherited?.brightness, .light)
    XCTAssertEqual(inherited?.theme.fontFamily, "Child Family")
    assertColor(inherited?.theme.appleAccentColor, rgb: (0x11, 0x22, 0x33))

    control.update(["theme_mode": .string("light")])
    let fresh = rufletControlThemeContext(
      control: control,
      inheritedMode: .dark,
      inheritedTheme: parent,
      platformBrightness: .dark)
    XCTAssertEqual(fresh?.mode, .light)
    XCTAssertEqual(fresh?.brightness, .light)
    XCTAssertEqual(fresh?.theme.fontFamily, "Child Family")
    assertSameColor(
      fresh?.theme.appleAccentColor,
      parseCupertinoTheme(
        ["font_family": "Child Family"], brightness: .light
      ).appleAccentColor)

    control.update(["theme_mode": .null])
    let inheritedDark = rufletControlThemeContext(
      control: control,
      inheritedMode: .dark,
      inheritedTheme: parent,
      platformBrightness: .light)
    XCTAssertEqual(inheritedDark?.theme.fontFamily, "Parent Family")
  }

  @MainActor
  func testControlThemeUsesDarkThemeAndHonorsSkipContract() {
    let backend = RufletBackend(
      pageURL: URL(string: "http://127.0.0.1:8550")!,
      assetsDirectory: "")
    defer { backend.dispose() }
    let control = RufletControl(
      id: 31,
      type: "Container",
      properties: [
        "theme_mode": .string("system"),
        "theme": .map(["font_family": .string("Light Family")]),
        "dark_theme": .map(["font_family": .string("Dark Family")]),
      ],
      backend: backend)
    let context = rufletControlThemeContext(
      control: control,
      inheritedMode: .light,
      inheritedTheme: nil,
      platformBrightness: .dark)
    XCTAssertEqual(context?.theme.fontFamily, "Dark Family")

    control.update([
      "_internals": .map(["skip_inherited_notifier": .bool(true)])
    ])
    XCTAssertNil(
      rufletControlThemeContext(
        control: control,
        inheritedMode: .light,
        inheritedTheme: nil,
        platformBrightness: .dark))
  }

  private func assertColor(
    _ color: Color?,
    rgb: (Int, Int, Int),
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    #if os(macOS)
      guard let color,
        let native = NSColor(color).usingColorSpace(.sRGB)
      else {
        return XCTFail("Expected an sRGB color", file: file, line: line)
      }
      XCTAssertEqual(
        native.redComponent, CGFloat(rgb.0) / 255, accuracy: 0.002, file: file, line: line)
      XCTAssertEqual(
        native.greenComponent, CGFloat(rgb.1) / 255, accuracy: 0.002, file: file, line: line)
      XCTAssertEqual(
        native.blueComponent, CGFloat(rgb.2) / 255, accuracy: 0.002, file: file, line: line)
    #else
      XCTAssertNotNil(color, file: file, line: line)
    #endif
  }

  private func assertSameColor(
    _ actual: Color?,
    _ expected: Color,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    #if os(macOS)
      guard let actual,
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
      XCTAssertNotNil(actual, file: file, line: line)
    #endif
  }
}
