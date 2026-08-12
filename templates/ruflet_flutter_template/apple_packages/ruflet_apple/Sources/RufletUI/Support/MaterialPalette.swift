import RufletEngine
import RufletProtocol
import SwiftUI
import MaterialColorUtilities

/// Resolves Ruflet colour strings to SwiftUI colours.
///
/// `Ruflet::Control` lowercases every colour-ish prop before it goes on the
/// wire, so what arrives is one of:
///
///   * a Material swatch name, optionally with a shade: `"blue"`, `"blue400"`,
///     `"redaccent200"`
///   * a black/white alias carrying opacity: `"black54"`, `"white70"`
///   * a Material 3 scheme role: `"primary"`, `"onsurfacevariant"`
///   * a hex literal: `"#rrggbb"`, `"#aarrggbb"`, `"0xff2196f3"`
///   * any of the above with an opacity suffix from `Colors.with_opacity`:
///     `"blue,0.5"`
public enum MaterialPalette {
  private static var generatedRoles = makeRoles(lightSeed: 0x2196f3, darkSeed: 0x2196f3)

  /// Installs the page's Ruby-declared Material theme before descendants are
  /// rendered. `dark_theme` inherits `theme` exactly as Flet's Page does.
  public static func configure(
    theme: [String: RufletValue]?,
    darkTheme: [String: RufletValue]? = nil
  ) {
    let lightSeed = seed(in: theme) ?? 0x2196f3
    let darkSeed = seed(in: darkTheme ?? theme) ?? lightSeed
    generatedRoles = makeRoles(lightSeed: lightSeed, darkSeed: darkSeed)
  }

  public static func color(_ name: String?) -> Color? {
    guard var token = name?.trimmingCharacters(in: .whitespaces).lowercased(), !token.isEmpty
    else { return nil }

    var opacity = 1.0
    if let comma = token.lastIndex(of: ","),
      let parsed = Double(token[token.index(after: comma)...])
    {
      opacity = parsed
      token = String(token[..<comma])
    }

    guard let base = resolve(token) else {
      RufletLog.debug("Unmapped colour token `\(token)`")
      return nil
    }
    return opacity == 1.0 ? base : base.opacity(opacity)
  }

  /// Resolves with a fallback, for props where "no colour" is not an option.
  public static func color(_ name: String?, default fallback: Color) -> Color {
    color(name) ?? fallback
  }

  /// Resolves the exact Flet semantic colour: explicit wire value first,
  /// followed by the pinned Flutter constructor/theme token. The consumer can
  /// still be a native SwiftUI/UIKit/AppKit control.
  public static func color(for node: ControlNode, property: String) -> Color? {
    color(RufletThemeDefaults.resolvedColorToken(for: node, property: property))
  }

  /// Resolves only a user-supplied colour. Use this for rendering-policy
  /// decisions, never as a substitute for the semantic default resolver.
  static func explicitColor(for node: ControlNode, property: String) -> Color? {
    color(RufletThemeDefaults.explicitColorToken(for: node, property: property))
  }

  public static func color(
    for node: ControlNode,
    property: String,
    default fallback: Color
  ) -> Color {
    color(for: node, property: property) ?? fallback
  }

  private static func resolve(_ token: String) -> Color? {
    if let hex = hexColor(token) { return hex }
    if let scheme = schemeColor(token) { return scheme }
    if let fixed = fixedColor(token) { return fixed }
    if let swatch = swatchColor(token) { return swatch }
    return nil
  }

  // MARK: - Hex

  private static func hexColor(_ token: String) -> Color? {
    var digits = token
    if digits.hasPrefix("#") {
      digits.removeFirst()
    } else if digits.hasPrefix("0x") {
      digits.removeFirst(2)
    } else {
      return nil
    }
    guard let value = UInt64(digits, radix: 16) else { return nil }

    switch digits.count {
    case 6:
      return rgb(UInt32(value))
    case 8:
      // Flutter writes ARGB, so the alpha byte leads.
      let alpha = Double((value >> 24) & 0xff) / 255
      return rgb(UInt32(value & 0x00ff_ffff)).opacity(alpha)
    case 3:
      // #rgb expands each nibble to a byte.
      let r: UInt64 = (value >> 8) & 0xf
      let g: UInt64 = (value >> 4) & 0xf
      let b: UInt64 = value & 0xf
      let expanded: UInt64 = (r << 20) | (r << 16) | (g << 12) | (g << 8) | (b << 4) | b
      return rgb(UInt32(expanded))
    default:
      return nil
    }
  }

  private static func rgb(_ value: UInt32) -> Color {
    Color(
      .sRGB,
      red: Double((value >> 16) & 0xff) / 255,
      green: Double((value >> 8) & 0xff) / 255,
      blue: Double(value & 0xff) / 255,
      opacity: 1)
  }

  // MARK: - Material 3 scheme roles

  /// Flutter/Flet's exact default Material 3 scheme. Flet constructs
  /// `ThemeData(colorSchemeSeed: Colors.blue, brightness: ...)` when Ruby did
  /// not provide a theme, so omission must resolve to these generated roles —
  /// never to SwiftUI's app accent or platform gray.
  private static func schemeColor(_ token: String) -> Color? {
    if let pair = generatedRoles[token] {
      return adaptive(pair.light, pair.dark)
    }
    switch token {
    case "primary": return adaptive(0x36618e, 0xa0cafd)
    case "onprimary": return adaptive(0xffffff, 0x003258)
    case "primarycontainer": return adaptive(0xd1e4ff, 0x194975)
    case "onprimarycontainer": return adaptive(0x194975, 0xd1e4ff)
    case "primaryfixed": return rgb(0xd1e4ff)
    case "primaryfixeddim": return rgb(0xa0cafd)
    case "onprimaryfixed": return rgb(0x001d36)
    case "onprimaryfixedvariant": return rgb(0x194975)
    case "secondary": return adaptive(0x535f70, 0xbbc7db)
    case "onsecondary": return adaptive(0xffffff, 0x253140)
    case "secondarycontainer": return adaptive(0xd7e3f7, 0x3b4858)
    case "onsecondarycontainer": return adaptive(0x3b4858, 0xd7e3f7)
    case "secondaryfixed": return rgb(0xd7e3f7)
    case "secondaryfixeddim": return rgb(0xbbc7db)
    case "onsecondaryfixed": return rgb(0x101c2b)
    case "onsecondaryfixedvariant": return rgb(0x3b4858)
    case "tertiary": return adaptive(0x6b5778, 0xd6bee4)
    case "ontertiary": return adaptive(0xffffff, 0x3b2948)
    case "tertiarycontainer": return adaptive(0xf2daff, 0x523f5f)
    case "ontertiarycontainer": return adaptive(0x523f5f, 0xf2daff)
    case "tertiaryfixed": return rgb(0xf2daff)
    case "tertiaryfixeddim": return rgb(0xd6bee4)
    case "ontertiaryfixed": return rgb(0x251432)
    case "ontertiaryfixedvariant": return rgb(0x523f5f)
    case "error": return adaptive(0xba1a1a, 0xffb4ab)
    case "onerror": return adaptive(0xffffff, 0x690005)
    case "errorcontainer": return adaptive(0xffdad6, 0x93000a)
    case "onerrorcontainer": return adaptive(0x93000a, 0xffdad6)
    case "surface", "background": return adaptive(0xf8f9ff, 0x111418)
    case "surfacedim": return adaptive(0xd8dae0, 0x111418)
    case "surfacebright": return adaptive(0xf8f9ff, 0x36393e)
    case "surfacecontainerlowest": return adaptive(0xffffff, 0x0b0e13)
    case "surfacecontainerlow": return adaptive(0xf2f3fa, 0x191c20)
    case "surfacecontainer": return adaptive(0xeceef4, 0x1d2024)
    case "surfacecontainerhigh": return adaptive(0xe6e8ee, 0x272a2f)
    case "surfacecontainerhighest": return adaptive(0xe1e2e8, 0x32353a)
    case "onsurface", "onbackground": return adaptive(0x191c20, 0xe1e2e8)
    case "onsurfacevariant": return adaptive(0x43474e, 0xc3c7cf)
    case "surfacetint": return adaptive(0x36618e, 0xa0cafd)
    case "outline": return adaptive(0x73777f, 0x8d9199)
    case "outlinevariant": return adaptive(0xc3c7cf, 0x43474e)
    case "shadow", "scrim": return .black
    case "inversesurface": return adaptive(0x2e3135, 0xe1e2e8)
    case "oninversesurface": return adaptive(0xeff0f7, 0x2e3135)
    case "inverseprimary": return adaptive(0xa0cafd, 0x36618e)
    default: return nil
    }
  }

  private static func seed(in theme: [String: RufletValue]?) -> UInt32? {
    guard var token = theme?["color_scheme_seed"]?.stringValue?
      .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    else { return nil }
    if token.hasPrefix("#") { token.removeFirst() }
    if token.hasPrefix("0x") { token.removeFirst(2) }
    if token.count == 8 { token.removeFirst(2) }
    return UInt32(token, radix: 16)
  }

  private static func makeRoles(
    lightSeed: UInt32,
    darkSeed: UInt32
  ) -> [String: (light: UInt32, dark: UInt32)] {
    let light = SchemeTonalSpot(
      sourceColorHct: Hct(Int(0xff00_0000 | lightSeed)),
      isDark: false,
      contrastLevel: 0)
    let dark = SchemeTonalSpot(
      sourceColorHct: Hct(Int(0xff00_0000 | darkSeed)),
      isDark: true,
      contrastLevel: 0)
    func pair(_ lightValue: Int, _ darkValue: Int) -> (UInt32, UInt32) {
      (UInt32(truncatingIfNeeded: lightValue) & 0x00ff_ffff,
       UInt32(truncatingIfNeeded: darkValue) & 0x00ff_ffff)
    }
    return [
      "primary": pair(light.primary, dark.primary),
      "onprimary": pair(light.onPrimary, dark.onPrimary),
      "primarycontainer": pair(light.primaryContainer, dark.primaryContainer),
      "onprimarycontainer": pair(light.onPrimaryContainer, dark.onPrimaryContainer),
      "primaryfixed": pair(light.primaryFixed, dark.primaryFixed),
      "primaryfixeddim": pair(light.primaryFixedDim, dark.primaryFixedDim),
      "onprimaryfixed": pair(light.onPrimaryFixed, dark.onPrimaryFixed),
      "onprimaryfixedvariant": pair(light.onPrimaryFixedVariant, dark.onPrimaryFixedVariant),
      "secondary": pair(light.secondary, dark.secondary),
      "onsecondary": pair(light.onSecondary, dark.onSecondary),
      "secondarycontainer": pair(light.secondaryContainer, dark.secondaryContainer),
      "onsecondarycontainer": pair(light.onSecondaryContainer, dark.onSecondaryContainer),
      "secondaryfixed": pair(light.secondaryFixed, dark.secondaryFixed),
      "secondaryfixeddim": pair(light.secondaryFixedDim, dark.secondaryFixedDim),
      "onsecondaryfixed": pair(light.onSecondaryFixed, dark.onSecondaryFixed),
      "onsecondaryfixedvariant": pair(light.onSecondaryFixedVariant, dark.onSecondaryFixedVariant),
      "tertiary": pair(light.tertiary, dark.tertiary),
      "ontertiary": pair(light.onTertiary, dark.onTertiary),
      "tertiarycontainer": pair(light.tertiaryContainer, dark.tertiaryContainer),
      "ontertiarycontainer": pair(light.onTertiaryContainer, dark.onTertiaryContainer),
      "tertiaryfixed": pair(light.tertiaryFixed, dark.tertiaryFixed),
      "tertiaryfixeddim": pair(light.tertiaryFixedDim, dark.tertiaryFixedDim),
      "ontertiaryfixed": pair(light.onTertiaryFixed, dark.onTertiaryFixed),
      "ontertiaryfixedvariant": pair(light.onTertiaryFixedVariant, dark.onTertiaryFixedVariant),
      "error": pair(light.error, dark.error),
      "onerror": pair(light.onError, dark.onError),
      "errorcontainer": pair(light.errorContainer, dark.errorContainer),
      "onerrorcontainer": pair(light.onErrorContainer, dark.onErrorContainer),
      "surface": pair(light.surface, dark.surface),
      "background": pair(light.background, dark.background),
      "onsurface": pair(light.onSurface, dark.onSurface),
      "onbackground": pair(light.onBackground, dark.onBackground),
      "surfacedim": pair(light.surfaceDim, dark.surfaceDim),
      "surfacebright": pair(light.surfaceBright, dark.surfaceBright),
      "surfacecontainerlowest": pair(light.surfaceContainerLowest, dark.surfaceContainerLowest),
      "surfacecontainerlow": pair(light.surfaceContainerLow, dark.surfaceContainerLow),
      "surfacecontainer": pair(light.surfaceContainer, dark.surfaceContainer),
      "surfacecontainerhigh": pair(light.surfaceContainerHigh, dark.surfaceContainerHigh),
      "surfacecontainerhighest": pair(light.surfaceContainerHighest, dark.surfaceContainerHighest),
      "onsurfacevariant": pair(light.onSurfaceVariant, dark.onSurfaceVariant),
      "outline": pair(light.outline, dark.outline),
      "outlinevariant": pair(light.outlineVariant, dark.outlineVariant),
      "inversesurface": pair(light.inverseSurface, dark.inverseSurface),
      "oninversesurface": pair(light.inverseOnSurface, dark.inverseOnSurface),
      "inverseprimary": pair(light.inversePrimary, dark.inversePrimary),
      "surfacetint": pair(light.surfaceTint, dark.surfaceTint),
      "shadow": pair(light.shadow, dark.shadow),
      "scrim": pair(light.scrim, dark.scrim)
    ]
  }

  private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
    #if canImport(UIKit)
      return Color(UIColor { traits in uiColor(traits.userInterfaceStyle == .dark ? dark : light) })
    #elseif canImport(AppKit)
      return Color(
        NSColor(name: nil) { appearance in
          let match = appearance.bestMatch(from: [.darkAqua, .aqua])
          return nsColor(match == .darkAqua ? dark : light)
        })
    #else
      return rgb(light)
    #endif
  }

  #if canImport(UIKit)
    private static func uiColor(_ value: UInt32) -> UIColor {
      UIColor(
        red: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: 1)
    }
  #elseif canImport(AppKit)
    private static func nsColor(_ value: UInt32) -> NSColor {
      NSColor(
        srgbRed: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: 1)
    }
  #endif

  // MARK: - Fixed colours

  private static func fixedColor(_ token: String) -> Color? {
    switch token {
    case "transparent": return .clear
    case "black": return .black
    case "black12": return .black.opacity(0.12)
    case "black26": return .black.opacity(0.26)
    case "black38": return .black.opacity(0.38)
    case "black45": return .black.opacity(0.45)
    case "black54": return .black.opacity(0.54)
    case "black87": return .black.opacity(0.87)
    case "white": return .white
    case "white10": return .white.opacity(0.10)
    case "white12": return .white.opacity(0.12)
    case "white24": return .white.opacity(0.24)
    case "white30": return .white.opacity(0.30)
    case "white38": return .white.opacity(0.38)
    case "white54": return .white.opacity(0.54)
    case "white60": return .white.opacity(0.60)
    case "white70": return .white.opacity(0.70)
    default: return nil
    }
  }

  // MARK: - Material swatches

  /// Splits `"lightblue700"` into family and shade, then looks the pair up in
  /// the Material 2 palette below.
  private static func swatchColor(_ token: String) -> Color? {
    let digits = token.suffix(while: { $0.isNumber })
    let family = String(token.dropLast(digits.count))
    let shade = Int(digits)

    if family.hasSuffix("accent") {
      let base = String(family.dropLast("accent".count))
      guard let swatch = accents[base] else { return nil }
      return rgb(swatch[shade ?? 200] ?? swatch[200] ?? swatch.values.first!)
    }
    guard let swatch = primaries[family] else { return nil }
    return rgb(swatch[shade ?? 500] ?? swatch[500] ?? swatch.values.first!)
  }

  /// The Material Design 2 primary palette. Written out because the shades are
  /// hand-picked, not derivable from the 500 value.
  private static let primaries: [String: [Int: UInt32]] = [
    "red": [
      50: 0xffebee, 100: 0xffcdd2, 200: 0xef9a9a, 300: 0xe57373, 400: 0xef5350,
      500: 0xf44336, 600: 0xe53935, 700: 0xd32f2f, 800: 0xc62828, 900: 0xb71c1c
    ],
    "pink": [
      50: 0xfce4ec, 100: 0xf8bbd0, 200: 0xf48fb1, 300: 0xf06292, 400: 0xec407a,
      500: 0xe91e63, 600: 0xd81b60, 700: 0xc2185b, 800: 0xad1457, 900: 0x880e4f
    ],
    "purple": [
      50: 0xf3e5f5, 100: 0xe1bee7, 200: 0xce93d8, 300: 0xba68c8, 400: 0xab47bc,
      500: 0x9c27b0, 600: 0x8e24aa, 700: 0x7b1fa2, 800: 0x6a1b9a, 900: 0x4a148c
    ],
    "deeppurple": [
      50: 0xede7f6, 100: 0xd1c4e9, 200: 0xb39ddb, 300: 0x9575cd, 400: 0x7e57c2,
      500: 0x673ab7, 600: 0x5e35b1, 700: 0x512da8, 800: 0x4527a0, 900: 0x311b92
    ],
    "indigo": [
      50: 0xe8eaf6, 100: 0xc5cae9, 200: 0x9fa8da, 300: 0x7986cb, 400: 0x5c6bc0,
      500: 0x3f51b5, 600: 0x3949ab, 700: 0x303f9f, 800: 0x283593, 900: 0x1a237e
    ],
    "blue": [
      50: 0xe3f2fd, 100: 0xbbdefb, 200: 0x90caf9, 300: 0x64b5f6, 400: 0x42a5f5,
      500: 0x2196f3, 600: 0x1e88e5, 700: 0x1976d2, 800: 0x1565c0, 900: 0x0d47a1
    ],
    "lightblue": [
      50: 0xe1f5fe, 100: 0xb3e5fc, 200: 0x81d4fa, 300: 0x4fc3f7, 400: 0x29b6f6,
      500: 0x03a9f4, 600: 0x039be5, 700: 0x0288d1, 800: 0x0277bd, 900: 0x01579b
    ],
    "cyan": [
      50: 0xe0f7fa, 100: 0xb2ebf2, 200: 0x80deea, 300: 0x4dd0e1, 400: 0x26c6da,
      500: 0x00bcd4, 600: 0x00acc1, 700: 0x0097a7, 800: 0x00838f, 900: 0x006064
    ],
    "teal": [
      50: 0xe0f2f1, 100: 0xb2dfdb, 200: 0x80cbc4, 300: 0x4db6ac, 400: 0x26a69a,
      500: 0x009688, 600: 0x00897b, 700: 0x00796b, 800: 0x00695c, 900: 0x004d40
    ],
    "green": [
      50: 0xe8f5e9, 100: 0xc8e6c9, 200: 0xa5d6a7, 300: 0x81c784, 400: 0x66bb6a,
      500: 0x4caf50, 600: 0x43a047, 700: 0x388e3c, 800: 0x2e7d32, 900: 0x1b5e20
    ],
    "lightgreen": [
      50: 0xf1f8e9, 100: 0xdcedc8, 200: 0xc5e1a5, 300: 0xaed581, 400: 0x9ccc65,
      500: 0x8bc34a, 600: 0x7cb342, 700: 0x689f38, 800: 0x558b2f, 900: 0x33691e
    ],
    "lime": [
      50: 0xf9fbe7, 100: 0xf0f4c3, 200: 0xe6ee9c, 300: 0xdce775, 400: 0xd4e157,
      500: 0xcddc39, 600: 0xc0ca33, 700: 0xafb42b, 800: 0x9e9d24, 900: 0x827717
    ],
    "yellow": [
      50: 0xfffde7, 100: 0xfff9c4, 200: 0xfff59d, 300: 0xfff176, 400: 0xffee58,
      500: 0xffeb3b, 600: 0xfdd835, 700: 0xfbc02d, 800: 0xf9a825, 900: 0xf57f17
    ],
    "amber": [
      50: 0xfff8e1, 100: 0xffecb3, 200: 0xffe082, 300: 0xffd54f, 400: 0xffca28,
      500: 0xffc107, 600: 0xffb300, 700: 0xffa000, 800: 0xff8f00, 900: 0xff6f00
    ],
    "orange": [
      50: 0xfff3e0, 100: 0xffe0b2, 200: 0xffcc80, 300: 0xffb74d, 400: 0xffa726,
      500: 0xff9800, 600: 0xfb8c00, 700: 0xf57c00, 800: 0xef6c00, 900: 0xe65100
    ],
    "deeporange": [
      50: 0xfbe9e7, 100: 0xffccbc, 200: 0xffab91, 300: 0xff8a65, 400: 0xff7043,
      500: 0xff5722, 600: 0xf4511e, 700: 0xe64a19, 800: 0xd84315, 900: 0xbf360c
    ],
    "brown": [
      50: 0xefebe9, 100: 0xd7ccc8, 200: 0xbcaaa4, 300: 0xa1887f, 400: 0x8d6e63,
      500: 0x795548, 600: 0x6d4c41, 700: 0x5d4037, 800: 0x4e342e, 900: 0x3e2723
    ],
    "grey": [
      50: 0xfafafa, 100: 0xf5f5f5, 200: 0xeeeeee, 300: 0xe0e0e0, 400: 0xbdbdbd,
      500: 0x9e9e9e, 600: 0x757575, 700: 0x616161, 800: 0x424242, 900: 0x212121
    ],
    "bluegrey": [
      50: 0xeceff1, 100: 0xcfd8dc, 200: 0xb0bec5, 300: 0x90a4ae, 400: 0x78909c,
      500: 0x607d8b, 600: 0x546e7a, 700: 0x455a64, 800: 0x37474f, 900: 0x263238
    ]
  ]

  private static let accents: [String: [Int: UInt32]] = [
    "red": [100: 0xff8a80, 200: 0xff5252, 400: 0xff1744, 700: 0xd50000],
    "pink": [100: 0xff80ab, 200: 0xff4081, 400: 0xf50057, 700: 0xc51162],
    "purple": [100: 0xea80fc, 200: 0xe040fb, 400: 0xd500f9, 700: 0xaa00ff],
    "deeppurple": [100: 0xb388ff, 200: 0x7c4dff, 400: 0x651fff, 700: 0x6200ea],
    "indigo": [100: 0x8c9eff, 200: 0x536dfe, 400: 0x3d5afe, 700: 0x304ffe],
    "blue": [100: 0x82b1ff, 200: 0x448aff, 400: 0x2979ff, 700: 0x2962ff],
    "lightblue": [100: 0x80d8ff, 200: 0x40c4ff, 400: 0x00b0ff, 700: 0x0091ea],
    "cyan": [100: 0x84ffff, 200: 0x18ffff, 400: 0x00e5ff, 700: 0x00b8d4],
    "teal": [100: 0xa7ffeb, 200: 0x64ffda, 400: 0x1de9b6, 700: 0x00bfa5],
    "green": [100: 0xb9f6ca, 200: 0x69f0ae, 400: 0x00e676, 700: 0x00c853],
    "lightgreen": [100: 0xccff90, 200: 0xb2ff59, 400: 0x76ff03, 700: 0x64dd17],
    "lime": [100: 0xf4ff81, 200: 0xeeff41, 400: 0xc6ff00, 700: 0xaeea00],
    "yellow": [100: 0xffff8d, 200: 0xffff00, 400: 0xffea00, 700: 0xffd600],
    "amber": [100: 0xffe57f, 200: 0xffd740, 400: 0xffc400, 700: 0xffab00],
    "orange": [100: 0xffd180, 200: 0xffab40, 400: 0xff9100, 700: 0xff6d00],
    "deeporange": [100: 0xff9e80, 200: 0xff6e40, 400: 0xff3d00, 700: 0xdd2c00]
  ]
}

extension StringProtocol {
  /// The trailing run of characters satisfying `predicate`.
  fileprivate func suffix(while predicate: (Character) -> Bool) -> String {
    String(reversed().prefix(while: predicate).reversed())
  }
}
