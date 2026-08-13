import XCTest
@testable import RufletUI
import RufletProtocol

final class IconMappingTests: XCTestCase {
  private var applePackageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // RufletEngineTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // package root
  }

  /// Static and thumbnail icons exercised across Ruflet Explorer's 65 gallery
  /// scenarios. Dynamic icon-search entries are covered separately by the
  /// generated Cupertino-catalog test below.
  private let explorerMaterialIcons = [
    "accessibility", "account_circle", "add", "alarm", "animation", "arrow_back",
    "arrow_drop_down_circle", "audiotrack", "auto_awesome", "battery_full",
    "calendar_today", "check_box", "check_circle", "chevron_right", "close", "code",
    "crop_square", "date_range", "delete", "directions_car", "donut_large", "edit",
    "cameraswitch", "flashlight_on", "folder_open", "grid_view", "home", "hub", "image", "info",
    "info_outline", "insert_drive_file", "ios_share", "language", "linear_scale", "list",
    "link", "location_on", "login", "map", "mic", "open_in_new", "open_with", "photo_camera",
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

  func testEveryMaterialWireIconUsesAppleRenderingOnly() {
    for (index, name) in MaterialIconNames.material.enumerated() {
      let wire = MaterialIconNames.firstCodepoint + index
      guard let rendering = IconMapping.rendering(for: .int(Int64(wire))) else {
        return XCTFail("Material icon \(name) resolved to no Apple rendering")
      }
      switch rendering {
      case .systemSymbol(let symbol):
        XCTAssertTrue(IconMapping.nativeSymbolExists(symbol), "Unavailable SF Symbol \(symbol) for \(name)")
      }
    }
  }

  func testApplePackageContainsNoMaterialIconRendererOrFontPipeline() throws {
    let manager = FileManager.default
    let forbiddenFileNames: Set<String> = [
      "MaterialIcons-Regular.otf",
      "MaterialIconGlyphs.generated.swift",
      "generate_material_icon_glyphs.rb",
    ]
    let enumerator = try XCTUnwrap(
      manager.enumerator(
        at: applePackageRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]))

    var found: [String] = []
    for case let url as URL in enumerator where forbiddenFileNames.contains(url.lastPathComponent) {
      found.append(url.path)
    }
    XCTAssertEqual(found, [], "Apple must never ship the Android Material icon renderer: \(found)")
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

  func testCupertinoResolutionNeverGuessesMeaningFromSubstrings() {
    XCTAssertEqual(
      IconMapping.symbol(forCupertinoName: "MY_HOME_AUTOMATION_VENDOR"),
      IconMapping.placeholderSymbol)
    XCTAssertEqual(
      IconMapping.symbol(forCupertinoName: "UNRELATED_CAMERA_SERVICE"),
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
    let nativeRocket = IconMapping.nativeSymbolExists("rocket")
    XCTAssertEqual(
      IconMapping.symbol(forMaterialName: "rocket_launch"),
      nativeRocket ? "rocket.fill" : "arrow.up.right")
    XCTAssertEqual(
      IconMapping.symbol(forMaterialName: "rocket"),
      nativeRocket ? "rocket" : "arrow.up.right")
    XCTAssertEqual(IconMapping.symbol(forMaterialName: "account_circle"), "person.crop.circle")
    XCTAssertEqual(IconMapping.symbol(forMaterialName: "chevron_right"), "chevron.right")
    XCTAssertEqual(
      IconMapping.symbol(forMaterialName: "cameraswitch"),
      "arrow.triangle.2.circlepath.camera")
    XCTAssertEqual(
      IconMapping.symbol(forMaterialName: "BROADCAST_ON_HOME_OUTLINED"),
      "house.badge.wifi")
    XCTAssertEqual(
      IconMapping.symbol(forMaterialName: "HOME_REPAIR_SERVICE_ROUNDED"),
      "wrench.and.screwdriver")
  }

  func testExplorerGalleryCategoriesUseClosestNativeAppleArtwork() {
    let expected: [String: String] = [
      "rocket_launch": IconMapping.nativeSymbolExists("rocket")
        ? "rocket.fill" : "arrow.up.right",
      "view_module": "square.grid.3x3.fill",
      "widgets": "square.grid.2x2.fill",
      "image": "photo.fill",
      "show_chart": "chart.line.uptrend.xyaxis",
      "animation": "circle.hexagongrid.fill",
      "auto_awesome": "sparkles",
      "settings": "gearshape.fill",
    ]

    for (materialName, nativeSymbol) in expected {
      XCTAssertEqual(IconMapping.symbol(forMaterialName: materialName), nativeSymbol)
      XCTAssertTrue(IconMapping.nativeSymbolExists(nativeSymbol))
    }
  }

  func testUnmappedMaterialNameIsExplicitInsteadOfHeuristicallyGuessed() {
    XCTAssertEqual(
      IconMapping.symbol(forMaterialName: "AIRLINE_SEAT_INDIVIDUAL_SUITE"),
      IconMapping.placeholderSymbol)
  }

  func testMaterialAddHomeVariantsMapToNativeHouseArtwork() {
    let addHome = IconMapping.symbol(forMaterialName: "ADD_HOME")
    let outlined = IconMapping.symbol(forMaterialName: "ADD_HOME_OUTLINED")
    XCTAssertTrue(IconMapping.nativeSymbolExists(addHome))
    XCTAssertEqual(
      addHome,
      IconMapping.nativeSymbolExists("house.badge.plus") ? "house.badge.plus" : "house")
    XCTAssertEqual(outlined, addHome)
  }

  func testAppleIconSearchExposesOnlyTheCupertinoCatalog() {
    XCTAssertEqual(IconMapping.searchableNames, MaterialIconNames.cupertino)
    XCTAssertFalse(IconMapping.searchableNames.contains("ACCESSIBILITY_NEW"))
  }

  func testCupertinoCatalogHasBroadNativeCoverage() {
    let missing = MaterialIconNames.cupertino.filter {
      IconMapping.symbol(forCupertinoName: $0) == IconMapping.placeholderSymbol
    }

    XCTAssertEqual(
      missing,
      [],
      "Unmapped Cupertino icons: \(missing.joined(separator: ", "))")
  }
}
