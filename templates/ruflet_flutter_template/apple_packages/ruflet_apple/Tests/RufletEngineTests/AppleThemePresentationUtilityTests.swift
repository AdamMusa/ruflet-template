import SwiftUI
import XCTest
@testable import RufletEngine

final class AppleThemePresentationUtilityTests: XCTestCase {
  func testCircularIntervalsRepeatWithoutLosingThePinnedOrder() {
    let intervals = CircularIntervalList([5.0, 10.0, 3.0])
    XCTAssertEqual([intervals.next, intervals.next, intervals.next, intervals.next], [5, 10, 3, 5])
  }

  func testMarkdownCodeThemeUsesHighlightWireKeyTransforms() {
    let parsed = parseMarkdownCodeTheme([
      "class_name": ["size": 14],
      "built_in": ["italic": true],
      "attribute_name": ["weight": "bold"],
    ])
    guard case .styles(let styles)? = parsed else {
      return XCTFail("Expected a decoded markdown code theme")
    }
    XCTAssertNotNil(styles["class"])
    XCTAssertNotNil(styles["built_in"])
    XCTAssertNotNil(styles["attribute-name"])
  }

  func testMarkdownStyleSheetPreservesRawStyleAndSpacingValues() {
    let style = parseMarkdownStyleSheet([
      "block_spacing": 12,
      "list_indent": 30,
      "p_padding": ["left": 4, "top": 2],
      "h1_text_style": ["size": 24],
    ])
    XCTAssertEqual(style?.blockSpacing, 12)
    XCTAssertEqual(style?.listIndent, 30)
    XCTAssertEqual(style?.paragraphPadding.leading, 4)
    XCTAssertNotNil(style?.textStyle("h1_text_style"))
  }

  func testThemeRetainsComponentWireDataAndOnlyBuildsAppleTransitions() {
    let theme = parseTheme([
      "font_family": "Avenir Next",
      "visual_density": "compact",
      "color_scheme": ["primary": "#112233"],
      "text_theme": ["title_large": ["size": 22]],
      "checkbox_theme": ["fill_color": "#445566"],
      "page_transitions": [
        "android": "zoom",
        "ios": "cupertino",
        "linux": "fadeupwards",
        "macos": "fadeforwards",
      ],
    ], brightness: .dark)

    XCTAssertEqual(theme.brightness, .dark)
    XCTAssertEqual(theme.fontFamily, "Avenir Next")
    XCTAssertEqual(theme.visualDensity, .compact)
    XCTAssertNotNil(theme.colorScheme?["primary"])
    XCTAssertNotNil(theme.textTheme?["title_large"])
    XCTAssertNotNil(theme.componentTheme("checkbox_theme"))
    XCTAssertEqual(Set(theme.pageTransitions.keys), Set(["ios", "macos"]))
    XCTAssertEqual(theme.pageTransitions["ios"], .cupertino)
    XCTAssertEqual(theme.pageTransitions["macos"], .fadeForwards)
  }

  func testColorSchemeSeedGeneratesThePinnedFlutterTonalSpotRoles() {
    let light = parseTheme(["color_scheme_seed": "#6750A4"], brightness: .light)
    XCTAssertEqual(light.colorScheme?.argb("primary"), 0xff65558f)
    XCTAssertEqual(light.colorScheme?.argb("secondary"), 0xff625b71)
    XCTAssertEqual(light.colorScheme?.argb("tertiary"), 0xff7e5260)
    XCTAssertEqual(light.colorScheme?.argb("surface"), 0xfffdf7ff)
    XCTAssertEqual(light.colorScheme?.argb("on_surface"), 0xff1d1b20)

    let dark = parseTheme(["color_scheme_seed": "#6750A4"], brightness: .dark)
    XCTAssertEqual(dark.colorScheme?.argb("primary"), 0xffcfbdfe)
    XCTAssertEqual(dark.colorScheme?.argb("secondary"), 0xffcbc2db)
    XCTAssertEqual(dark.colorScheme?.argb("tertiary"), 0xffefb8c8)
    XCTAssertEqual(dark.colorScheme?.argb("surface"), 0xff141218)
    XCTAssertEqual(dark.colorScheme?.argb("on_surface"), 0xffe6e0e9)
  }

  func testExplicitColorSchemeCopiesOverGeneratedSeedScheme() {
    let theme = parseTheme([
      "color_scheme_seed": "#6750A4",
      "color_scheme": ["primary": "#112233"],
    ], brightness: .dark)

    XCTAssertEqual(theme.colorScheme?.argb("primary"), 0xff112233)
    XCTAssertEqual(theme.colorScheme?.argb("surface"), 0xff141218)
  }

  func testMaterial3TextThemeUsesFlutter2021GeometryAndCopiesOverrides() {
    let theme = parseTheme([
      "text_theme": ["body_medium": ["size": 15]],
    ], brightness: .dark)

    XCTAssertEqual(theme.textTheme?["title_large"]?.size, 22)
    XCTAssertEqual(theme.textTheme?["title_large"]?.height, 1.27)
    XCTAssertEqual(theme.textTheme?["label_large"]?.weight, .medium)
    XCTAssertEqual(theme.textTheme?["label_large"]?.letterSpacing, 0.1)
    XCTAssertEqual(theme.textTheme?["body_medium"]?.size, 15)
    XCTAssertEqual(theme.textTheme?["body_medium"]?.height, 1.43)
    XCTAssertEqual(theme.textTheme?["body_medium"]?.letterSpacing, 0.25)
  }

  func testOverlayBrightnessUsesPinnedAppleContrastDefaults() {
    let style = parseSystemUIOverlayStyle([:], brightness: .light)
    XCTAssertEqual(style?.statusBarBrightness, .light)
    XCTAssertEqual(style?.statusBarIconBrightness, .dark)
    XCTAssertEqual(style?.navigationBarIconBrightness, .dark)
  }

  func testTabsAndTooltipDecodePinnedDefaults() {
    XCTAssertEqual(parseTabBarIndicatorSize("LABEL"), .label)
    XCTAssertEqual(parseTabIndicatorAnimation("elastic"), .elastic)
    let indicator = parseUnderlineTabIndicator([
      "insets": ["left": 3, "right": 5],
      "border_side": ["width": 4, "color": "#000000"],
    ])
    XCTAssertEqual(indicator?.insets.leading, 3)
    XCTAssertEqual(indicator?.insets.trailing, 5)
    XCTAssertEqual(indicator?.borderSide.width, 4)

    let simpleTooltip = parseTooltip("Details")
    XCTAssertEqual(simpleTooltip?.message, "Details")
    XCTAssertEqual(simpleTooltip?.waitDuration, 0.8)
    XCTAssertEqual(simpleTooltip?.tapToDismiss, true)
  }
}
