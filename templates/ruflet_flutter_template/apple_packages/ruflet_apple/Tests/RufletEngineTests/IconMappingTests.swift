import XCTest
import CoreText

@testable import RufletUI
import RufletProtocol

final class IconMappingTests: XCTestCase {
  /// Static and thumbnail icons exercised across Ruflet Explorer's 65 gallery
  /// scenarios. Dynamic icon-search entries are covered separately by the
  /// generated Cupertino-catalog test below.
  private let explorerMaterialIcons = [
    "accessibility", "account_circle", "add", "alarm", "animation", "arrow_back",
    "arrow_drop_down_circle", "audiotrack", "auto_awesome", "battery_full",
    "calendar_today", "check_box", "check_circle", "chevron_right", "close", "code",
    "crop_square", "date_range", "delete", "directions_car", "donut_large", "edit",
    "flashlight_on", "folder_open", "grid_view", "home", "hub", "image", "info",
    "info_outline", "insert_drive_file", "ios_share", "language", "linear_scale", "list",
    "location_on", "login", "map", "mic", "open_in_new", "open_with", "photo_camera",
    "play_arrow", "play_circle", "qr_code_scanner", "radio_button_checked", "rocket_launch",
    "save", "schedule", "search", "sensors", "settings", "share", "show_chart", "star",
    "stop", "tab", "table_chart", "text_fields", "toggle_on", "touch_app", "tune",
    "unfold_less", "upload_file", "view_column", "view_module", "view_stream", "waving_hand",
    "widgets", "wifi",
  ]

  func testCodepointDescriptorPreservesIconFamily() {
    XCTAssertEqual(
      MaterialIconNames.descriptor(forCodepoint: MaterialIconNames.firstCodepoint)?.family,
      .material)
    XCTAssertEqual(
      MaterialIconNames.descriptor(forCodepoint: MaterialIconNames.cupertinoFirstCodepoint)?.family,
      .cupertino)
  }

  func testEveryMaterialCatalogEntryHasTheExactFlutterGlyphCodepoint() {
    XCTAssertEqual(MaterialIconGlyphs.codepoints.count, MaterialIconNames.material.count)
    XCTAssertEqual(MaterialIconGlyphs.codepoint(forName: "ABC"), 0xf04b6)
    XCTAssertEqual(MaterialIconGlyphs.codepoint(forName: "HOME"), 0xe318)
    XCTAssertEqual(MaterialIconGlyphs.codepoint(forName: "HOME_OUTLINED"), 0xf107)
    XCTAssertTrue(MaterialIconGlyphs.matchesTextDirection(name: "ARROW_BACK"))
    XCTAssertFalse(MaterialIconGlyphs.matchesTextDirection(name: "HOME"))
    XCTAssertTrue(MaterialIconGlyphs.codepoints.allSatisfy { UnicodeScalar($0) != nil })
  }

  func testMaterialAndCupertinoWireIconsResolveToNativeAppleSymbols() throws {
    let homeIndex = try XCTUnwrap(MaterialIconNames.material.firstIndex(of: "HOME"))
    let homeCodepoint = MaterialIconNames.firstCodepoint + homeIndex
    XCTAssertEqual(
      IconMapping.rendering(for: .int(Int64(homeCodepoint))),
      .systemSymbol("house"))
    XCTAssertEqual(IconMapping.rendering(for: .string("home")), .systemSymbol("house"))
    guard case .systemSymbol(let symbol) = IconMapping.rendering(
      for: .int(Int64(MaterialIconNames.cupertinoFirstCodepoint)))
    else { return XCTFail("Cupertino wire icon did not resolve to an SF Symbol") }
    XCTAssertTrue(IconMapping.nativeSymbolExists(symbol))
  }

  func testBundledMaterialFontRegistersAndContainsFlutterGlyphs() {
    XCTAssertTrue(MaterialIconsFont.registrationSucceeded)
    let font = CTFontCreateWithName(MaterialIconGlyphs.postScriptName as CFString, 24, nil)
    XCTAssertEqual(CTFontCopyPostScriptName(font) as String, MaterialIconGlyphs.postScriptName)

    var character = UniChar(0xe318) // Icons.home
    var glyph = CGGlyph()
    XCTAssertTrue(CTFontGetGlyphsForCharacters(font, &character, &glyph, 1))
    XCTAssertNotEqual(glyph, 0)

    for (index, codepoint) in MaterialIconGlyphs.codepoints.enumerated() {
      guard let scalar = UnicodeScalar(codepoint) else {
        return XCTFail("Invalid scalar for \(MaterialIconNames.material[index])")
      }
      let characters = Array(String(scalar).utf16)
      var glyphs = Array(repeating: CGGlyph(), count: characters.count)
      let mapped = characters.withUnsafeBufferPointer { characterBuffer in
        glyphs.withUnsafeMutableBufferPointer { glyphBuffer in
          CTFontGetGlyphsForCharacters(
            font, characterBuffer.baseAddress!, glyphBuffer.baseAddress!, characters.count)
        }
      }
      XCTAssertTrue(
        mapped && glyphs.contains(where: { $0 != 0 }),
        "Font has no glyph for \(MaterialIconNames.material[index]) (U+\(String(codepoint, radix: 16)))")
    }
  }

  func testCupertinoNamesResolveToNativeSymbols() {
    XCTAssertEqual(IconMapping.symbol(forCupertinoName: "ADD"), "plus")
    XCTAssertEqual(IconMapping.symbol(forCupertinoName: "SETTINGS"), "gearshape")
    XCTAssertEqual(IconMapping.symbol(forCupertinoName: "PERSON_CIRCLE"), "person.crop.circle")
  }

  func testUnknownCupertinoIconRemainsVisible() {
    XCTAssertEqual(
      IconMapping.symbol(forCupertinoName: "AN_ICON_THAT_CANNOT_EXIST"),
      IconMapping.placeholderSymbol)
  }

  func testEveryExplorerCorpusIconResolvesToAnAvailableNativeSymbol() {
    for name in explorerMaterialIcons {
      let symbol = IconMapping.symbol(forName: name, family: .material)
      XCTAssertNotEqual(symbol, IconMapping.placeholderSymbol, "Missing Explorer icon: \(name)")
      XCTAssertTrue(
        IconMapping.nativeSymbolExists(symbol),
        "Explorer icon \(name) mapped to unavailable SF Symbol \(symbol)")
    }
  }

  func testRubyMaterialNamesResolveToTheirNativeAppleMeaning() {
    XCTAssertEqual(IconMapping.symbol(forMaterialName: "home"), "house")
    XCTAssertTrue(
      ["rocket.fill", "paperplane.fill"].contains(
        IconMapping.symbol(forMaterialName: "rocket_launch")))
    XCTAssertEqual(IconMapping.symbol(forMaterialName: "account_circle"), "person.crop.circle")
    XCTAssertEqual(IconMapping.symbol(forMaterialName: "chevron_right"), "chevron.right")
  }

  func testAppleIconSearchExposesOnlyTheCupertinoCatalog() {
    XCTAssertEqual(IconMapping.preferredFamily(forPlatform: "ios"), .cupertino)
    XCTAssertEqual(IconMapping.preferredFamily(forPlatform: "macos"), .cupertino)
    XCTAssertEqual(IconMapping.preferredFamily(forPlatform: "android"), .material)

    let iosNames = IconMapping.searchableNames(forPlatform: "ios")
    XCTAssertEqual(iosNames, MaterialIconNames.cupertino)
    XCTAssertFalse(iosNames.contains("ACCESSIBILITY_NEW"))
  }

  func testCupertinoCatalogHasBroadNativeCoverage() {
    let mapped = MaterialIconNames.cupertino.filter {
      IconMapping.symbol(forCupertinoName: $0) != IconMapping.placeholderSymbol
    }

    XCTAssertEqual(
      mapped.count,
      MaterialIconNames.cupertino.count,
      "Only \(mapped.count) of \(MaterialIconNames.cupertino.count) Cupertino icons mapped")
  }
}
