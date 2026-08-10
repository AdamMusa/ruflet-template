import XCTest

@testable import RufletUI

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
