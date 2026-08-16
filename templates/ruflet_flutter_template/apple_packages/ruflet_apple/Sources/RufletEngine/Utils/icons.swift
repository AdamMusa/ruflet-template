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
    if let name = catalogs.cupertinoNamesByCode[code] {
      if let symbol = catalogs.cupertinoSystemSymbols[name] {
        return .systemSymbol(symbol)
      }
      return catalogs.cupertinoGlyphs[name].map(RufletAppleIcon.cupertinoGlyph)
    }

    guard let materialName = catalogs.materialNamesByCode[code] else { return nil }
    if let symbol = materialSystemSymbols[materialName] {
      return .systemSymbol(symbol)
    }
    return catalogs.materialGlyphs[materialName].map(RufletAppleIcon.materialGlyph)
  }

  public static func icon(forMaterialName rawName: String) -> RufletAppleIcon? {
    let name = canonical(rawName).uppercased()
    if let symbol = materialSystemSymbols[name] {
      return .systemSymbol(symbol)
    }
    return catalogs.materialGlyphs[name].map(RufletAppleIcon.materialGlyph)
  }

  public static func icon(forCupertinoName rawName: String) -> RufletAppleIcon? {
    let name = canonical(rawName).uppercased()
    if let symbol = catalogs.cupertinoSystemSymbols[name] {
      return .systemSymbol(symbol)
    }
    return catalogs.cupertinoGlyphs[name].map(RufletAppleIcon.cupertinoGlyph)
  }

  public static func materialName(for code: Int) -> String? {
    catalogs.materialNamesByCode[code]
  }

  public static func cupertinoName(for code: Int) -> String? {
    catalogs.cupertinoNamesByCode[code]
  }

  private static func canonical(_ rawName: String) -> String {
    rawName
      .lowercased()
      .replacingOccurrences(of: "cupertinoicons.", with: "")
      .replacingOccurrences(of: "icons.", with: "")
      .replacingOccurrences(of: "-", with: "_")
      .replacingOccurrences(of: " ", with: "_")
  }

  /// Native equivalents for Material names used by Ruflet applications.
  ///
  /// Both lookups in the hot path (`wire code -> Material name -> SF Symbol`)
  /// are dictionaries. The Ruby protocol remains Flet-compatible while the
  /// Apple renderer paints platform-native symbols in constant time.
  private static let materialSystemSymbols: [String: String] = [
    "ACCESSIBILITY": "accessibility",
    "ACCOUNT_CIRCLE": "person.crop.circle",
    "ADD": "plus",
    "ALARM": "alarm",
    "ANIMATION": "wand.and.stars",
    "ARROW_BACK": "chevron.left",
    "ARROW_BACK_IOS": "chevron.left",
    "ARROW_DROP_DOWN_CIRCLE": "chevron.down.circle",
    "ARROW_FORWARD_IOS": "chevron.right",
    "AUDIOTRACK": "music.note",
    "AUTO_AWESOME": "sparkles",
    "BATTERY_FULL": "battery.100",
    "CALENDAR_TODAY": "calendar",
    "CHECK_BOX": "checkmark.square.fill",
    "CHECK_CIRCLE": "checkmark.circle.fill",
    "CHEVRON_LEFT": "chevron.left",
    "CHEVRON_RIGHT": "chevron.right",
    "CLOSE": "xmark",
    "CODE": "chevron.left.forwardslash.chevron.right",
    "CROP_SQUARE": "square",
    "DATE_RANGE": "calendar",
    "DELETE": "trash",
    "DIRECTIONS_CAR": "car",
    "DONUT_LARGE": "chart.pie",
    "EDIT": "pencil",
    "FLASHLIGHT_ON": "flashlight.on.fill",
    "FOLDER_OPEN": "folder",
    "GRID_VIEW": "square.grid.2x2",
    "HOME": "house",
    "HUB": "point.3.connected.trianglepath.dotted",
    "IMAGE": "photo",
    "INFO": "info.circle",
    "INFO_OUTLINE": "info.circle",
    "INSERT_DRIVE_FILE": "doc",
    "IOS_SHARE": "square.and.arrow.up",
    "LANGUAGE": "globe",
    "LINEAR_SCALE": "slider.horizontal.3",
    "LINK": "link",
    "LIST": "list.bullet",
    "LOCATION_ON": "mappin",
    "LOCK": "lock",
    "LOGIN": "arrow.right.to.line",
    "MAP": "map",
    "MENU": "line.3.horizontal",
    "MIC": "mic",
    "MORE_HORIZ": "ellipsis",
    "MORE_VERT": "ellipsis",
    "NAVIGATE_BEFORE": "chevron.left",
    "NAVIGATE_NEXT": "chevron.right",
    "OPEN_IN_NEW": "arrow.up.forward.square",
    "OPEN_WITH": "arrow.up.and.down.and.arrow.left.and.right",
    "PHOTO_CAMERA": "camera",
    "PLAY_ARROW": "play.fill",
    "PLAY_CIRCLE": "play.circle.fill",
    "QR_CODE_SCANNER": "qrcode.viewfinder",
    "RADIO_BUTTON_CHECKED": "largecircle.fill.circle",
    "ROCKET_LAUNCH": "paperplane.fill",
    "SAVE": "tray.and.arrow.down",
    "SCHEDULE": "clock",
    "SEARCH": "magnifyingglass",
    "SENSORS": "dot.radiowaves.left.and.right",
    "SETTINGS": "gearshape",
    "SHARE": "square.and.arrow.up",
    "SHOW_CHART": "chart.xyaxis.line",
    "STAR": "star.fill",
    "STOP": "stop.fill",
    "TAB": "rectangle.split.3x1",
    "TABLE_CHART": "tablecells",
    "TEXT_FIELDS": "textformat",
    "TOGGLE_ON": "switch.2",
    "TOUCH_APP": "hand.tap",
    "TUNE": "slider.horizontal.3",
    "UNFOLD_LESS": "chevron.up.chevron.down",
    "UPLOAD_FILE": "doc.badge.arrow.up",
    "VIEW_COLUMN": "rectangle.split.3x1",
    "VIEW_MODULE": "square.grid.2x2",
    "VIEW_STREAM": "rectangle.split.1x2",
    "WAVING_HAND": "hand.wave",
    "WIDGETS": "square.grid.2x2",
    "WIFI": "wifi",
  ]

  /// Cupertino's catalog mostly mirrors SF Symbol identifiers. This small
  /// alias table covers the older Flutter names that are semantic rather than
  /// direct underscore-to-dot spellings; the rest are discovered once when
  /// the immutable catalog is loaded.
  private static let cupertinoSystemSymbolAliases: [String: String] = [
    "ADD": "plus",
    "ADD_CIRCLED": "plus.circle",
    "ADD_CIRCLED_SOLID": "plus.circle.fill",
    "BACK": "chevron.backward",
    "BACKWARD": "backward",
    "CLEAR": "xmark.circle",
    "CLEAR_CIRCLED": "xmark.circle",
    "CLEAR_CIRCLED_SOLID": "xmark.circle.fill",
    "DELETE": "trash",
    "FORWARD": "forward",
    "HOME": "house",
    "LOCATION": "location",
    "LOCATION_SOLID": "location.fill",
    "OPTIONS": "slider.horizontal.3",
    "PERSON": "person",
    "PERSON_ADD": "person.badge.plus",
    "PLAY_ARROW": "play",
    "PLAY_ARROW_SOLID": "play.fill",
    "REFRESH": "arrow.clockwise",
    "SEARCH": "magnifyingglass",
    "SHARE": "square.and.arrow.up",
  ]

  private static func nativeCupertinoSymbol(for name: String) -> String? {
    let candidate =
      cupertinoSystemSymbolAliases[name]
      ?? name.lowercased().replacingOccurrences(of: "_", with: ".")
    #if canImport(UIKit)
      return UIImage(systemName: candidate) == nil ? nil : candidate
    #elseif canImport(AppKit)
      return NSImage(systemSymbolName: candidate, accessibilityDescription: nil) == nil
        ? nil : candidate
    #else
      return nil
    #endif
  }

  private struct Catalogs {
    let materialNamesByCode: [Int: String]
    let cupertinoNamesByCode: [Int: String]
    let cupertinoSystemSymbols: [String: String]
    let cupertinoGlyphs: [String: UInt32]
    let materialGlyphs: [String: UInt32]

    init() {
      let materialNames = Self.names(resource: "material_icons")
      let cupertinoNames = Self.names(resource: "cupertino_icons")
      materialNamesByCode = materialNames
      cupertinoNamesByCode = cupertinoNames
      cupertinoGlyphs = Self.glyphs(resource: "cupertino_glyphs")
      materialGlyphs = Self.glyphs(resource: "material_glyphs")
      cupertinoSystemSymbols = Dictionary(
        uniqueKeysWithValues: cupertinoNames.values.compactMap { name in
          RufletAppleIconCatalog.nativeCupertinoSymbol(for: name).map { (name, $0) }
        })
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
