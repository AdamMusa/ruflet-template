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
      "arrow_back": "chevron.left",
      "arrow_back_ios": "chevron.left",
      "arrow_drop_down_circle": "chevron.down.circle",
      "arrow_forward_ios": "chevron.right",
      "audiotrack": "music.note",
      "auto_awesome": "sparkles",
      "battery_full": "battery.100",
      "calendar_today": "calendar",
      "check_box": "checkmark.square.fill",
      "check_circle": "checkmark.circle.fill",
      "chevron_left": "chevron.left",
      "chevron_right": "chevron.right",
      "close": "xmark",
      "code": "chevron.left.forwardslash.chevron.right",
      "crop_square": "square",
      "date_range": "calendar",
      "delete": "trash",
      "directions_car": "car",
      "donut_large": "chart.pie",
      "edit": "pencil",
      "flashlight_on": "flashlight.on.fill",
      "folder_open": "folder",
      "grid_view": "square.grid.2x2",
      "home": "house",
      "hub": "point.3.connected.trianglepath.dotted",
      "image": "photo",
      "info": "info.circle",
      "info_outline": "info.circle",
      "insert_drive_file": "doc",
      "ios_share": "square.and.arrow.up",
      "language": "globe",
      "link": "link",
      "linear_scale": "slider.horizontal.3",
      "list": "list.bullet",
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
      "radio_button_checked": "largecircle.fill.circle",
      "rocket_launch": "paperplane.fill",
      "save": "tray.and.arrow.down",
      "schedule": "clock",
      "search": "magnifyingglass",
      "sensors": "dot.radiowaves.left.and.right",
      "settings": "gearshape",
      "share": "square.and.arrow.up",
      "show_chart": "chart.xyaxis.line",
      "star": "star.fill",
      "stop": "stop.fill",
      "tab": "rectangle.split.3x1",
      "table_chart": "tablecells",
      "text_fields": "textformat",
      "toggle_on": "switch.2",
      "touch_app": "hand.tap",
      "tune": "slider.horizontal.3",
      "unfold_less": "chevron.up.chevron.down",
      "upload_file": "doc.badge.arrow.up",
      "view_column": "rectangle.split.3x1",
      "view_module": "square.grid.2x2",
      "view_stream": "rectangle.split.1x2",
      "waving_hand": "hand.wave",
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

  func testCupertinoWireIconsPreferSystemSymbolsAndRetainExactFallbackArtwork() {
    var nativeSymbolCount = 0
    for code in 131_072...132_393 {
      switch RufletAppleIconCatalog.icon(for: code) {
      case .systemSymbol:
        nativeSymbolCount += 1
      case .cupertinoGlyph:
        break
      default:
        return XCTFail("Cupertino wire code \(code) did not resolve to Apple artwork")
      }
    }
    XCTAssertGreaterThanOrEqual(nativeSymbolCount, 1_000)
    XCTAssertEqual(RufletAppleIconCatalog.icon(forCupertinoName: "home"), .systemSymbol("house"))
    XCTAssertEqual(
      RufletAppleIconCatalog.icon(forCupertinoName: "person_crop_circle_fill"),
      .systemSymbol("person.crop.circle.fill"))
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
