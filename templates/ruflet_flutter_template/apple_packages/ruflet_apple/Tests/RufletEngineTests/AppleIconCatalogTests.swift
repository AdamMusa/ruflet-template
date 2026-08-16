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

  func testExplorerMaterialWireNamesResolveToFlutterGlyphs() {
    XCTAssertEqual(RufletAppleIconCatalog.icon(for: 69_314), .materialGlyph(0xf051d))
    XCTAssertEqual(RufletAppleIconCatalog.icon(for: 69_749), .materialGlyph(0xe380))
    XCTAssertEqual(RufletAppleIconCatalog.icon(for: 69_969), .materialGlyph(0xe3b2))
    XCTAssertEqual(RufletAppleIconCatalog.icon(for: 71_571), .materialGlyph(0xe4f7))
    XCTAssertEqual(RufletAppleIconCatalog.icon(for: 67_006), .materialGlyph(0xe176))
  }

  func testEveryCupertinoWireIconUsesItsExactBundledGlyph() {
    for code in 131_072...132_393 {
      guard case .cupertinoGlyph = RufletAppleIconCatalog.icon(for: code) else {
        return XCTFail("Cupertino wire code \(code) did not resolve to its canonical glyph")
      }
    }
  }

  func testEveryMaterialWireIconUsesItsExactBundledGlyph() {
    var unresolved: [String] = []
    for code in 65_536...74_360 {
      guard let name = RufletAppleIconCatalog.materialName(for: code) else {
        return XCTFail("Missing canonical Material wire name for \(code)")
      }
      guard case .materialGlyph = RufletAppleIconCatalog.icon(for: code) else {
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
