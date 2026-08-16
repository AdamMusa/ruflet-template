import XCTest

@testable import RufletEngine

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

final class AppleIconCatalogTests: XCTestCase {
  func testPinnedIconCorpusCountsAndWireBoundaries() {
    XCTAssertEqual(RufletAppleIconCatalog.materialCount, 8_825)
    XCTAssertEqual(RufletAppleIconCatalog.cupertinoCount, 1_322)
    XCTAssertEqual(RufletAppleIconCatalog.materialName(for: 65_536), "ABC")
    XCTAssertEqual(RufletAppleIconCatalog.materialName(for: 74_360), "ZOOM_OUT_SHARP")
    XCTAssertEqual(RufletAppleIconCatalog.cupertinoName(for: 131_072), "ADD")
    XCTAssertEqual(RufletAppleIconCatalog.cupertinoName(for: 132_393), "ZZZ")
    XCTAssertEqual(RufletMaterialIcons.count, 8_825)
    XCTAssertEqual(RufletMaterialIcons.name(at: 0), "ABC")
    XCTAssertNil(RufletMaterialIcons.name(at: -1))
    XCTAssertNil(RufletMaterialIcons.name(at: RufletMaterialIcons.count))
    XCTAssertEqual(RufletCupertinoIcons.count, 1_322)
    XCTAssertEqual(RufletCupertinoIcons.name(at: 0), "ADD")
    XCTAssertNil(RufletCupertinoIcons.icon(at: RufletCupertinoIcons.count))
  }

  func testExplorerMaterialWireNamesResolveToNativeSystemSymbols() {
    let expected: [String: String] = [
      "accessibility": "accessibility",
      "account_circle": "person.crop.circle",
      "add": "plus",
      "alarm": "alarm",
      "animation": "wand.and.stars",
      "arrow_back": "arrow.left",
      "arrow_back_ios": "chevron.left",
      "arrow_forward_ios": "chevron.right",
      "audiotrack": "music.note",
      "auto_awesome": "sparkles",
      "battery_full": "battery.100",
      "check_circle": "checkmark.circle.fill",
      "chevron_left": "chevron.left",
      "chevron_right": "chevron.right",
      "code": "chevron.left.forwardslash.chevron.right",
      "delete": "trash",
      "directions_car": "car",
      "flashlight_on": "flashlight.on.fill",
      "folder_open": "folder",
      "home": "house",
      "hub": "point.3.connected.trianglepath.dotted",
      "image": "photo",
      "info": "info.circle",
      "insert_drive_file": "doc",
      "ios_share": "square.and.arrow.up",
      "language": "globe",
      "link": "link",
      "location_on": "mappin",
      "lock": "lock",
      "login": "arrow.right.to.line",
      "map": "map",
      "menu": "line.3.horizontal",
      "mic": "mic",
      "more_horiz": "ellipsis",
      "more_vert": "ellipsis",
      "navigate_before": "chevron.left",
      "navigate_next": "chevron.right",
      "open_in_new": "arrow.up.forward.square",
      "open_with": "arrow.up.and.down.and.arrow.left.and.right",
      "photo_camera": "camera",
      "play_arrow": "play.fill",
      "play_circle": "play.circle.fill",
      "qr_code_scanner": "qrcode.viewfinder",
      "rocket_launch": "paperplane.fill",
      "save": "tray.and.arrow.down",
      "search": "magnifyingglass",
      "sensors": "dot.radiowaves.left.and.right",
      "settings": "gearshape",
      "share": "square.and.arrow.up",
      "show_chart": "chart.xyaxis.line",
      "stop": "stop.fill",
      "unfold_less": "chevron.up.chevron.down",
      "upload_file": "doc.badge.arrow.up",
      "view_module": "square.grid.2x2",
      "widgets": "square.grid.2x2",
      "wifi": "wifi",
    ]

    for (materialName, systemName) in expected {
      XCTAssertEqual(
        RufletAppleIconCatalog.icon(forMaterialName: materialName),
        .systemSymbol(systemName),
        materialName)
      #if canImport(UIKit)
        XCTAssertNotNil(UIImage(systemName: systemName), systemName)
      #elseif canImport(AppKit)
        XCTAssertNotNil(
          NSImage(systemSymbolName: systemName, accessibilityDescription: nil), systemName)
      #endif
    }
  }

  func testEveryCupertinoWireIconUsesItsExactBundledGlyph() {
    for code in 131_072...132_393 {
      guard case .cupertinoGlyph = RufletAppleIconCatalog.icon(for: code) else {
        return XCTFail("Cupertino wire code \(code) did not resolve to its canonical glyph")
      }
    }
  }

  func testEveryMaterialWireIconHasNativeOrCanonicalArtwork() {
    var unresolved: [String] = []
    for code in 65_536...74_360 {
      guard let name = RufletAppleIconCatalog.materialName(for: code) else {
        return XCTFail("Missing canonical Material wire name for \(code)")
      }
      guard RufletAppleIconCatalog.icon(for: code) != nil else {
        unresolved.append(name)
        continue
      }
    }
    if !unresolved.isEmpty {
      XCTContext.runActivity(named: "Unresolved Material icon glyph debt") { activity in
        activity.add(XCTAttachment(string: unresolved.joined(separator: "\n")))
      }
    }
    XCTAssertTrue(
      unresolved.isEmpty,
      "Unresolved Material icons: \(unresolved.count); first: \(unresolved.prefix(20).joined(separator: ", "))"
    )
  }

  func testUnknownWireCodesDoNotRenderAnUnrelatedFallback() {
    XCTAssertNil(RufletAppleIconCatalog.icon(for: -1))
    XCTAssertNil(RufletAppleIconCatalog.icon(for: 999_999))
  }
}
