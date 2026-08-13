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
}
