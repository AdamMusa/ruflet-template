import SwiftUI
import XCTest

@testable import RufletEngine

#if os(macOS)
  import AppKit
#endif

final class LoadingPageContractTests: XCTestCase {
  func testLoadingSurfaceUsesInheritedFletThemeInsteadOfPlatformBackground() {
    let inheritedTheme = parseCupertinoTheme(
      ["color_scheme": ["surface": "#112233"]],
      brightness: .dark)

    assertColor(
      rufletLoadingSurfaceColor(pageTheme: inheritedTheme, colorScheme: .light),
      rgb: (0x11, 0x22, 0x33))
  }

  func testTopLevelLoadingSurfaceUsesFletDefaultThemeForAmbientBrightness() {
    let expected = parseCupertinoTheme(nil, brightness: .dark).colorScheme!["surface"]!
    assertSameColor(
      rufletLoadingSurfaceColor(pageTheme: nil, colorScheme: .dark),
      expected)
  }

  private func assertColor(
    _ color: Color,
    rgb: (UInt8, UInt8, UInt8),
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    assertSameColor(
      color,
      Color(
        red: Double(rgb.0) / 255,
        green: Double(rgb.1) / 255,
        blue: Double(rgb.2) / 255),
      file: file,
      line: line)
  }

  private func assertSameColor(
    _ first: Color,
    _ second: Color,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    #if os(macOS)
      let firstColor = NSColor(first).usingColorSpace(.sRGB)
      let secondColor = NSColor(second).usingColorSpace(.sRGB)
      XCTAssertNotNil(firstColor, file: file, line: line)
      XCTAssertNotNil(secondColor, file: file, line: line)
      guard let firstColor, let secondColor else { return }
      XCTAssertEqual(firstColor.redComponent, secondColor.redComponent, accuracy: 0.01, file: file, line: line)
      XCTAssertEqual(firstColor.greenComponent, secondColor.greenComponent, accuracy: 0.01, file: file, line: line)
      XCTAssertEqual(firstColor.blueComponent, secondColor.blueComponent, accuracy: 0.01, file: file, line: line)
    #endif
  }
}
