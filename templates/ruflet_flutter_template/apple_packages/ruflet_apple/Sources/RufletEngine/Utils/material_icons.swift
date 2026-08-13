import Foundation

/// Apple-native port of Flet's pinned `utils/material_icons.dart` catalog.
///
/// Material values remain wire identities only. Every lookup is translated by
/// `RufletAppleIconCatalog` to Cupertino artwork or an SF Symbol; Material's
/// font is never loaded or rendered on Apple platforms.
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
