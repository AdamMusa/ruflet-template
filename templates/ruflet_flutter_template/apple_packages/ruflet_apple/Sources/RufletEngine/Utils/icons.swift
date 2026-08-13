import CoreText
import Foundation
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Native Apple artwork resolved from a Flet icon wire value.
///
/// Material integer values are protocol identities only. They are never
/// rendered with the Material font on Apple: each value is translated to an
/// SF Symbol or to the corresponding glyph in Apple's Cupertino icon family.
public enum RufletAppleIcon: Equatable, Sendable {
  case systemSymbol(String)
  case cupertinoGlyph(UInt32)
}

/// Canonical Flet Material/Cupertino wire catalogs and their Apple artwork.
public enum RufletAppleIconCatalog {
  public static let materialFirstCode = 65_536
  public static let cupertinoFirstCode = 131_072

  public static var materialCount: Int { catalogs.materialNamesByCode.count }
  public static var cupertinoCount: Int { catalogs.cupertinoNamesByCode.count }

  public static func icon(for code: Int) -> RufletAppleIcon? {
    if let name = catalogs.cupertinoNamesByCode[code],
      let glyph = catalogs.cupertinoGlyphs[name]
    {
      return .cupertinoGlyph(glyph)
    }

    guard let materialName = catalogs.materialNamesByCode[code] else { return nil }
    return icon(forMaterialName: materialName)
  }

  public static func icon(forMaterialName rawName: String) -> RufletAppleIcon? {
    guard let translation = catalogs.materialToApple[canonical(rawName).uppercased()] else {
      return nil
    }
    switch translation.kind {
    case "cupertino_glyph":
      return catalogs.cupertinoGlyphs[translation.value.uppercased()]
        .map(RufletAppleIcon.cupertinoGlyph)
    case "system_symbol":
      return .systemSymbol(translation.value)
    default:
      preconditionFailure("Invalid Apple icon translation kind: \(translation.kind)")
    }
  }

  public static func icon(forCupertinoName rawName: String) -> RufletAppleIcon? {
    cupertinoGlyph(named: rawName).map(RufletAppleIcon.cupertinoGlyph)
  }

  public static func materialName(for code: Int) -> String? {
    catalogs.materialNamesByCode[code]
  }

  public static func cupertinoName(for code: Int) -> String? {
    catalogs.cupertinoNamesByCode[code]
  }

  private static func cupertinoGlyph(named rawName: String) -> UInt32? {
    catalogs.cupertinoGlyphs[canonical(rawName).uppercased()]
  }

  private static func canonical(_ rawName: String) -> String {
    rawName
      .lowercased()
      .replacingOccurrences(of: "cupertinoicons.", with: "")
      .replacingOccurrences(of: "icons.", with: "")
      .replacingOccurrences(of: "-", with: "_")
      .replacingOccurrences(of: " ", with: "_")
  }

  private struct Catalogs {
    let materialNamesByCode: [Int: String]
    let cupertinoNamesByCode: [Int: String]
    let cupertinoGlyphs: [String: UInt32]
    let materialToApple: [String: AppleTranslation]

    init() {
      materialNamesByCode = Self.names(resource: "material_icons")
      cupertinoNamesByCode = Self.names(resource: "cupertino_icons")
      cupertinoGlyphs = Self.glyphs(resource: "cupertino_glyphs")
      materialToApple = Self.translations(resource: "material_to_apple")
    }

    private static func names(resource: String) -> [Int: String] {
      guard
        let url = resourceURL(
          name: resource,
          extension: "json",
          subdirectory: "IconCatalog"),
        let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: NSNumber]
      else {
        preconditionFailure("Missing Ruflet icon catalog resource: \(resource).json")
      }
      return Dictionary(uniqueKeysWithValues: object.map { (Int($0.value.int64Value), $0.key) })
    }

    private static func glyphs(resource: String) -> [String: UInt32] {
      guard
        let url = resourceURL(
          name: resource,
          extension: "json",
          subdirectory: "IconCatalog"),
        let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: NSNumber]
      else {
        preconditionFailure("Missing Ruflet icon glyph resource: \(resource).json")
      }
      return object.mapValues { UInt32(truncating: $0) }
    }

    private static func translations(resource: String) -> [String: AppleTranslation] {
      guard
        let url = resourceURL(
          name: resource,
          extension: "json",
          subdirectory: "IconCatalog"),
        let data = try? Data(contentsOf: url),
        let object = try? JSONDecoder().decode([String: AppleTranslation].self, from: data)
      else {
        preconditionFailure("Missing Ruflet Apple translation resource: \(resource).json")
      }
      return object
    }

    private static func resourceURL(
      name: String,
      extension fileExtension: String,
      subdirectory: String
    ) -> URL? {
      Bundle.module.url(
        forResource: name,
        withExtension: fileExtension,
        subdirectory: subdirectory)
        ?? Bundle.module.url(forResource: name, withExtension: fileExtension)
    }
  }

  private static let catalogs = Catalogs()

  private struct AppleTranslation: Decodable {
    let kind: String
    let value: String
    let concept: String
    let confidence: String
    let source: String
  }
}

@MainActor
public struct RufletAppleIconView: View {
  public let icon: RufletAppleIcon
  public var size: CGFloat
  public var weight: Font.Weight

  public init(icon: RufletAppleIcon, size: CGFloat = 24, weight: Font.Weight = .regular) {
    self.icon = icon
    self.size = size
    self.weight = weight
  }

  public var body: some View {
    switch icon {
    case .systemSymbol(let name):
      Image(systemName: validatedSystemSymbol(name)).font(.system(size: size, weight: weight))
    case .cupertinoGlyph(let scalar):
      Text(String(UnicodeScalar(scalar)!))
        .font(.custom(RufletCupertinoIconFont.postScriptName, size: size))
    }
  }

  private func validatedSystemSymbol(_ name: String) -> String {
    #if canImport(UIKit)
      precondition(UIImage(systemName: name) != nil, "Invalid Ruflet SF Symbol: \(name)")
    #elseif canImport(AppKit)
      precondition(
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
        "Invalid Ruflet SF Symbol: \(name)")
    #endif
    return name
  }
}

private enum RufletCupertinoIconFont {
  static let postScriptName = "CupertinoIcons"

  static func register() {
    _ = registration
  }

  private static let registration: Void = {
    guard
      let url = Bundle.module.url(
        forResource: "CupertinoIcons",
        withExtension: "ttf",
        subdirectory: "CupertinoIcons")
        ?? Bundle.module.url(forResource: "CupertinoIcons", withExtension: "ttf")
    else {
      preconditionFailure("Missing bundled CupertinoIcons.ttf")
    }
    var error: Unmanaged<CFError>?
    let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    if !registered,
      let description = error?.takeRetainedValue().localizedDescription,
      !description.localizedCaseInsensitiveContains("already")
    {
      preconditionFailure("Unable to register CupertinoIcons.ttf: \(description)")
    }
  }()
}

extension RufletAppleIconView {
  public static func registered(
    icon: RufletAppleIcon,
    size: CGFloat = 24,
    weight: Font.Weight = .regular
  ) -> RufletAppleIconView {
    RufletCupertinoIconFont.register()
    return RufletAppleIconView(icon: icon, size: size, weight: weight)
  }
}
