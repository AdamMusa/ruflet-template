import Foundation

/// Exact native port of Flet's pinned `utils/material_icons.dart` catalog.
/// Wire identities resolve to the same MaterialIcons glyphs Flutter paints.
public enum RufletMaterialIcons {
  public static let firstCode = RufletAppleIconCatalog.materialFirstCode
  public static let count = RufletAppleIconCatalog.materialCount

  public static func name(at index: Int) -> String? {
    guard index >= 0, index < count else { return nil }
    return RufletAppleIconCatalog.materialName(for: firstCode + index)
  }

  public static func appleIcon(at index: Int) -> RufletAppleIcon? {
    guard index >= 0, index < count else { return nil }
    return RufletAppleIconCatalog.icon(for: firstCode + index)
  }
}
