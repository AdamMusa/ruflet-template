import Foundation

/// Apple-native port of Flet's pinned `utils/cupertino_icons.dart` catalog.
///
/// The Dart source is a stable ordered list of Cupertino `IconData`. Ruflet's
/// protocol assigns that same order consecutive wire values beginning at
/// `131_072`; the bundled catalog retains the canonical names and glyphs.
public enum RufletCupertinoIcons {
  public static let firstCode = RufletAppleIconCatalog.cupertinoFirstCode
  public static let count = RufletAppleIconCatalog.cupertinoCount

  public static func name(at index: Int) -> String? {
    guard index >= 0, index < count else { return nil }
    return RufletAppleIconCatalog.cupertinoName(for: firstCode + index)
  }

  public static func icon(at index: Int) -> RufletAppleIcon? {
    guard index >= 0, index < count else { return nil }
    return RufletAppleIconCatalog.icon(for: firstCode + index)
  }
}
