import CoreText
import Foundation
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Exact native artwork resolved from a Flet icon wire value.
public enum RufletAppleIcon: Equatable, Sendable {
  case systemSymbol(String)
  case cupertinoGlyph(UInt32)
  case materialGlyph(UInt32)
}

private struct RufletInheritedIconSizeKey: EnvironmentKey {
  static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
  var rufletInheritedIconSize: CGFloat? {
    get { self[RufletInheritedIconSizeKey.self] }
    set { self[RufletInheritedIconSizeKey.self] = newValue }
  }
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

    guard let materialName = catalogs.materialNamesByCode[code],
      let glyph = catalogs.materialGlyphs[materialName]
    else { return nil }
    return .materialGlyph(glyph)
  }

  public static func icon(forMaterialName rawName: String) -> RufletAppleIcon? {
    catalogs.materialGlyphs[canonical(rawName).uppercased()]
      .map(RufletAppleIcon.materialGlyph)
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
    let materialGlyphs: [String: UInt32]

    init() {
      materialNamesByCode = Self.names(resource: "material_icons")
      cupertinoNamesByCode = Self.names(resource: "cupertino_icons")
      cupertinoGlyphs = Self.glyphs(resource: "cupertino_glyphs")
      materialGlyphs = Self.glyphs(resource: "material_glyphs")
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
    case .materialGlyph(let scalar):
      Text(String(UnicodeScalar(scalar)!))
        .font(.custom(RufletMaterialIconFont.postScriptName, size: size))
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

private enum RufletMaterialIconFont {
  static let postScriptName = "MaterialIcons-Regular"

  static func register() {
    _ = registration
  }

  private static let registration: Void = {
    guard
      let url = Bundle.module.url(
        forResource: "MaterialIcons-Regular",
        withExtension: "otf",
        subdirectory: "MaterialIcons")
        ?? Bundle.module.url(forResource: "MaterialIcons-Regular", withExtension: "otf")
    else {
      preconditionFailure("Missing bundled MaterialIcons-Regular.otf")
    }
    registerIconFont(url: url, name: "MaterialIcons-Regular.otf")
  }()
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
    registerIconFont(url: url, name: "CupertinoIcons.ttf")
  }()
}

private func registerIconFont(url: URL, name: String) {
  var error: Unmanaged<CFError>?
  let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
  if !registered,
    let description = error?.takeRetainedValue().localizedDescription,
    !description.localizedCaseInsensitiveContains("already")
  {
    preconditionFailure("Unable to register \(name): \(description)")
  }
}

extension RufletAppleIconView {
  public static func registered(
    icon: RufletAppleIcon,
    size: CGFloat = 24,
    weight: Font.Weight = .regular
  ) -> RufletAppleIconView {
    switch icon {
    case .cupertinoGlyph: RufletCupertinoIconFont.register()
    case .materialGlyph: RufletMaterialIconFont.register()
    case .systemSymbol: break
    }
    return RufletAppleIconView(icon: icon, size: size, weight: weight)
  }
}
