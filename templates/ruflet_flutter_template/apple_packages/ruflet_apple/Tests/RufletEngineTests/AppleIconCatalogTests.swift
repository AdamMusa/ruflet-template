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

  func testExplorerMaterialWireNamesResolveToAppleArtwork() {
    XCTAssertEqual(RufletAppleIconCatalog.icon(for: 71_894), .cupertinoGlyph(0xf903))
    XCTAssertEqual(
      RufletAppleIconCatalog.icon(for: 69_314),
      RufletAppleIconCatalog.icon(forCupertinoName: "circle_grid_hex_fill"))
    XCTAssertEqual(
      RufletAppleIconCatalog.icon(for: 69_217),
      RufletAppleIconCatalog.icon(forCupertinoName: "home"))
    XCTAssertEqual(
      RufletAppleIconCatalog.icon(for: 69_330),
      RufletAppleIconCatalog.icon(forCupertinoName: "photo_fill"))
    XCTAssertEqual(
      RufletAppleIconCatalog.icon(for: 68_985),
      RufletAppleIconCatalog.icon(forCupertinoName: "square_grid_2x2"))
    XCTAssertEqual(
      RufletAppleIconCatalog.icon(for: 72_414),
      RufletAppleIconCatalog.icon(forCupertinoName: "graph_square"))
    XCTAssertEqual(
      RufletAppleIconCatalog.icon(for: 74_196),
      RufletAppleIconCatalog.icon(forCupertinoName: "square_grid_2x2_fill"))
  }

  func testEveryCupertinoWireIconUsesItsExactBundledGlyph() {
    for code in 131_072...132_393 {
      guard case .cupertinoGlyph = RufletAppleIconCatalog.icon(for: code) else {
        return XCTFail("Cupertino wire code \(code) did not resolve to its canonical glyph")
      }
    }
  }

  func testEveryMaterialWireIconHasAnExplicitAppleEquivalent() {
    var unresolved: [String] = []
    for code in 65_536...74_360 {
      guard let name = RufletAppleIconCatalog.materialName(for: code) else {
        return XCTFail("Missing canonical Material wire name for \(code)")
      }
      if RufletAppleIconCatalog.icon(for: code) == nil { unresolved.append(name) }
    }
    if !unresolved.isEmpty {
      XCTContext.runActivity(named: "Unresolved Material → Apple icon debt") { activity in
        activity.add(XCTAttachment(string: unresolved.joined(separator: "\n")))
      }
    }
    XCTAssertTrue(
      unresolved.isEmpty,
      "Unresolved Material icons: \(unresolved.count); first: \(unresolved.prefix(20).joined(separator: ", "))"
    )
  }

  func testEveryMappedSystemSymbolCanBeInstantiatedNatively() {
    var checked: Set<String> = []
    var invalid: [String] = []
    for code in 65_536...74_360 {
      guard case .systemSymbol(let name) = RufletAppleIconCatalog.icon(for: code),
        checked.insert(name).inserted
      else { continue }
      #if canImport(UIKit)
        if UIImage(systemName: name) == nil { invalid.append(name) }
      #elseif canImport(AppKit)
        if NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil {
          invalid.append(name)
        }
      #endif
    }
    XCTAssertTrue(
      invalid.isEmpty,
      "Invalid native system symbols: \(invalid.sorted().joined(separator: ", "))")
  }

  func testUnknownWireCodesDoNotRenderAnUnrelatedFallback() {
    XCTAssertNil(RufletAppleIconCatalog.icon(for: -1))
    XCTAssertNil(RufletAppleIconCatalog.icon(for: 999_999))
  }
}
