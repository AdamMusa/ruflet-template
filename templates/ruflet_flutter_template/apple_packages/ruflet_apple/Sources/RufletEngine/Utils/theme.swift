import MaterialColorUtilities
import SwiftUI

public enum RufletBrightness: String, CaseIterable, RufletStringEnum, Sendable {
  case light
  case dark

  public var inverted: RufletBrightness { self == .light ? .dark : .light }
}

public enum RufletVisualDensity: String, Sendable {
  case adaptivePlatformDensity = "adaptiveplatformdensity"
  case comfortable
  case compact
  case standard
}

public enum RufletPageTransition: String, Sendable {
  case fadeUpwards = "fadeupwards"
  case openUpwards = "openupwards"
  case cupertino
  case zoom
  case none
  case predictive
  case fadeForwards = "fadeforwards"
}

public struct RufletColorScheme {
  public let colors: [String: Color]
  let argbValues: [String: UInt32]

  init(colors: [String: Color], argbValues: [String: UInt32] = [:]) {
    self.colors = colors
    self.argbValues = argbValues
  }

  public subscript(_ name: String) -> Color? { colors[name] }
  func argb(_ name: String) -> UInt32? { argbValues[name] }
}

public struct RufletTextTheme {
  public let styles: [String: RufletTextStyle]
  public subscript(_ name: String) -> RufletTextStyle? { styles[name] }
}

/// Complete Apple representation of a Flet theme.
///
/// All pinned keys remain available through `raw`; Apple-rendered primitives
/// are decoded eagerly and nested component themes are retained losslessly.
public struct RufletTheme {
  public let raw: [String: Any]
  public let brightness: RufletBrightness?
  public let colorSchemeSeed: Color
  public let colorScheme: RufletColorScheme?
  public let fontFamily: String?
  public let useMaterial3WireValue: Bool?
  public let textTheme: RufletTextTheme?
  public let primaryTextTheme: RufletTextTheme?
  public let visualDensity: RufletVisualDensity?
  public let pageTransitions: [String: RufletPageTransition]
  public let systemOverlayStyle: RufletSystemUIOverlayStyle?

  public func color(_ property: String) -> Color? {
    parseColor(raw[property] as? String)
  }

  public func componentTheme(_ property: String) -> [String: Any]? {
    rufletDictionary(raw[property])
  }

  /// Native Apple accent derived from the pinned Flet theme contract.
  public var appleAccentColor: Color {
    colorScheme?["primary"] ?? colorSchemeSeed
  }

  /// Default Cupertino page surface. An explicit scaffold color has the same
  /// precedence as Flet's ThemeData before the Cupertino theme is derived.
  public var applePageBackgroundColor: Color? {
    color("scaffold_bgcolor") ?? colorScheme?["surface"]
  }

  /// Default Cupertino bar surface used by pinned `fixCupertinoTheme()`.
  public var appleBarBackgroundColor: Color? {
    colorScheme?["surface"] ?? applePageBackgroundColor
  }

  /// Default foreground applied by Cupertino's `applyThemeToAll` contract.
  public var appleContentColor: Color? {
    colorScheme?["on_surface"]
  }

  /// The Page-wide body style. Explicit control styles still take precedence.
  public var appleBodyTextStyle: RufletTextStyle? {
    textTheme?["body_medium"]
  }
}

/// Parsed light/dark Page themes with the same selection rules as pinned
/// Flet 0.80.5 `PageControl._buildApp`.
struct RufletPageThemes {
  let light: RufletTheme
  let dark: RufletTheme

  func active(themeMode: RufletThemeMode, systemColorScheme: ColorScheme) -> RufletTheme {
    switch themeMode {
    case .light:
      light
    case .dark:
      dark
    case .system:
      systemColorScheme == .dark ? dark : light
    }
  }
}

/// When Page.dark_theme is absent, pinned Flet reparses Page.theme with dark
/// brightness instead of inventing a separate theme or renderer fallback.
func parsePageThemes(theme: Any?, darkTheme: Any?) -> RufletPageThemes {
  let effectiveDarkTheme = rufletDictionary(darkTheme) == nil ? theme : darkTheme
  return RufletPageThemes(
    light: parseCupertinoTheme(theme, brightness: .light),
    dark: parseCupertinoTheme(effectiveDarkTheme, brightness: .dark))
}

public func parseBrightness(
  _ value: String?, _ defaultValue: RufletBrightness? = nil
) -> RufletBrightness? {
  parseEnum(RufletBrightness.self, value, defaultValue)
}

func parseThemeMode(
  _ value: String?, _ defaultValue: RufletThemeMode? = nil
) -> RufletThemeMode? {
  parseEnum(RufletThemeMode.self, value, defaultValue)
}

public func parseVisualDensity(
  _ value: String?, _ defaultValue: RufletVisualDensity? = nil
) -> RufletVisualDensity? {
  guard let value else { return defaultValue }
  return RufletVisualDensity(rawValue: value.lowercased()) ?? defaultValue
}

public func parseTransitionsBuilder(
  _ value: String?, _ defaultValue: RufletPageTransition? = nil
) -> RufletPageTransition? {
  guard let value else { return defaultValue }
  return RufletPageTransition(rawValue: value.lowercased()) ?? defaultValue
}

public func parsePageTransitions(
  _ value: Any?, _ defaultValue: [String: RufletPageTransition]? = nil
) -> [String: RufletPageTransition]? {
  guard let value = rufletDictionary(value) else { return defaultValue }
  // Android, Linux, web and Windows branches are intentionally not modeled by
  // the Apple renderer. Only the pinned Apple keys participate.
  return [
    "ios": parseTransitionsBuilder(value["ios"] as? String, .cupertino)!,
    "macos": parseTransitionsBuilder(value["macos"] as? String, .zoom)!,
  ]
}

public func parseColorScheme(
  _ value: Any?, _ defaultValue: RufletColorScheme? = nil
) -> RufletColorScheme? {
  guard let value = rufletDictionary(value) else { return defaultValue }
  let names = [
    "primary", "on_primary", "primary_container", "on_primary_container",
    "secondary", "on_secondary", "secondary_container", "on_secondary_container",
    "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
    "error", "on_error", "error_container", "on_error_container", "surface",
    "on_surface", "on_surface_variant", "outline", "outline_variant", "shadow",
    "scrim", "inverse_surface", "on_inverse_surface", "inverse_primary", "surface_tint",
    "on_primary_fixed", "on_secondary_fixed", "on_tertiary_fixed",
    "on_primary_fixed_variant", "on_secondary_fixed_variant", "on_tertiary_fixed_variant",
    "primary_fixed", "secondary_fixed", "tertiary_fixed", "primary_fixed_dim",
    "secondary_fixed_dim", "tertiary_fixed_dim", "surface_bright", "surface_container",
    "surface_container_high", "surface_container_highest", "surface_container_low",
    "surface_container_lowest", "surface_dim",
  ]
  var colors = defaultValue?.colors ?? [:]
  var argbValues = defaultValue?.argbValues ?? [:]
  for name in names {
    if let wireColor = value[name] as? String,
      let color = parseColor(wireColor)
    {
      colors[name] = color
      if let argb = parseColorARGB(wireColor) { argbValues[name] = argb }
    }
  }
  return RufletColorScheme(colors: colors, argbValues: argbValues)
}

func materialColorScheme(seed: UInt32, isDark: Bool) -> RufletColorScheme {
  let scheme = SchemeTonalSpot(
    sourceColorHct: Hct(Int(seed)), isDark: isDark, contrastLevel: 0)
  let values: [String: Int] = [
    "primary": scheme.primary,
    "on_primary": scheme.onPrimary,
    "primary_container": scheme.primaryContainer,
    "on_primary_container": scheme.onPrimaryContainer,
    "secondary": scheme.secondary,
    "on_secondary": scheme.onSecondary,
    "secondary_container": scheme.secondaryContainer,
    "on_secondary_container": scheme.onSecondaryContainer,
    "tertiary": scheme.tertiary,
    "on_tertiary": scheme.onTertiary,
    "tertiary_container": scheme.tertiaryContainer,
    "on_tertiary_container": scheme.onTertiaryContainer,
    "error": scheme.error,
    "on_error": scheme.onError,
    "error_container": scheme.errorContainer,
    "on_error_container": scheme.onErrorContainer,
    "surface": scheme.surface,
    "on_surface": scheme.onSurface,
    "on_surface_variant": scheme.onSurfaceVariant,
    "outline": scheme.outline,
    "outline_variant": scheme.outlineVariant,
    "shadow": scheme.shadow,
    "scrim": scheme.scrim,
    "inverse_surface": scheme.inverseSurface,
    "on_inverse_surface": scheme.inverseOnSurface,
    "inverse_primary": scheme.inversePrimary,
    "surface_tint": scheme.surfaceTint,
    "on_primary_fixed": scheme.onPrimaryFixed,
    "on_secondary_fixed": scheme.onSecondaryFixed,
    "on_tertiary_fixed": scheme.onTertiaryFixed,
    "on_primary_fixed_variant": scheme.onPrimaryFixedVariant,
    "on_secondary_fixed_variant": scheme.onSecondaryFixedVariant,
    "on_tertiary_fixed_variant": scheme.onTertiaryFixedVariant,
    "primary_fixed": scheme.primaryFixed,
    "secondary_fixed": scheme.secondaryFixed,
    "tertiary_fixed": scheme.tertiaryFixed,
    "primary_fixed_dim": scheme.primaryFixedDim,
    "secondary_fixed_dim": scheme.secondaryFixedDim,
    "tertiary_fixed_dim": scheme.tertiaryFixedDim,
    "surface_bright": scheme.surfaceBright,
    "surface_container": scheme.surfaceContainer,
    "surface_container_high": scheme.surfaceContainerHigh,
    "surface_container_highest": scheme.surfaceContainerHighest,
    "surface_container_low": scheme.surfaceContainerLow,
    "surface_container_lowest": scheme.surfaceContainerLowest,
    "surface_dim": scheme.surfaceDim,
  ]
  let argbValues = values.mapValues { UInt32(truncatingIfNeeded: $0) }
  return RufletColorScheme(
    colors: argbValues.mapValues(colorFromARGB), argbValues: argbValues)
}

public func parseTextTheme(
  _ value: Any?, _ defaultValue: RufletTextTheme? = nil
) -> RufletTextTheme? {
  guard let value = rufletDictionary(value) else { return defaultValue }
  let names = [
    "body_large", "body_medium", "body_small", "display_large", "display_medium",
    "display_small", "headline_large", "headline_medium", "headline_small", "label_large",
    "label_medium", "label_small", "title_large", "title_medium", "title_small",
  ]
  var styles = defaultValue?.styles ?? [:]
  for name in names {
    if let style = parseTextStyle(value[name]) {
      styles[name] = mergeTextStyles(styles[name], style)
    }
  }
  return RufletTextTheme(styles: styles)
}

func material3TextTheme() -> RufletTextTheme {
  let specifications: [String: (Double, Font.Weight, Double, Double)] = [
    "display_large": (57, .regular, -0.25, 1.12),
    "display_medium": (45, .regular, 0, 1.16),
    "display_small": (36, .regular, 0, 1.22),
    "headline_large": (32, .regular, 0, 1.25),
    "headline_medium": (28, .regular, 0, 1.29),
    "headline_small": (24, .regular, 0, 1.33),
    "title_large": (22, .regular, 0, 1.27),
    "title_medium": (16, .medium, 0.15, 1.50),
    "title_small": (14, .medium, 0.1, 1.43),
    "label_large": (14, .medium, 0.1, 1.43),
    "label_medium": (12, .medium, 0.5, 1.33),
    "label_small": (11, .medium, 0.5, 1.45),
    "body_large": (16, .regular, 0.5, 1.50),
    "body_medium": (14, .regular, 0.25, 1.43),
    "body_small": (12, .regular, 0.4, 1.33),
  ]
  return RufletTextTheme(styles: specifications.mapValues { specification in
    RufletTextStyle(
      size: specification.0,
      weight: specification.1,
      italic: false,
      fontFamily: nil,
      height: specification.3,
      decoration: 0,
      decorationColor: nil,
      decorationThickness: nil,
      color: nil,
      backgroundColor: nil,
      letterSpacing: specification.2,
      wordSpacing: nil,
      overflow: nil)
  })
}

public func parseTheme(
  _ value: Any?, brightness: RufletBrightness? = nil,
  parentTheme: RufletTheme? = nil
) -> RufletTheme {
  var raw = parentTheme?.raw ?? [:]
  if let updates = rufletDictionary(value) {
    for (key, value) in updates { raw[key] = value }
  }
  let effectiveBrightness = brightness ?? parentTheme?.brightness
  let seedARGB = parseColorARGB(raw["color_scheme_seed"] as? String) ?? 0xff2196f3
  let generatedColorScheme = parentTheme?.colorScheme ?? materialColorScheme(
    seed: seedARGB, isDark: effectiveBrightness == .dark)
  let generatedTextTheme = parentTheme?.textTheme ?? material3TextTheme()
  return RufletTheme(
    raw: raw,
    brightness: effectiveBrightness,
    colorSchemeSeed: parentTheme?.colorSchemeSeed ?? colorFromARGB(seedARGB),
    colorScheme: parseColorScheme(raw["color_scheme"], generatedColorScheme),
    fontFamily: raw["font_family"] as? String ?? parentTheme?.fontFamily,
    useMaterial3WireValue: parseBool(raw["use_material3"]),
    textTheme: parseTextTheme(raw["text_theme"], generatedTextTheme),
    primaryTextTheme: parseTextTheme(raw["primary_text_theme"], parentTheme?.primaryTextTheme),
    visualDensity: parseVisualDensity(
      raw["visual_density"] as? String, parentTheme?.visualDensity),
    pageTransitions: parsePageTransitions(
      raw["page_transitions"], parentTheme?.pageTransitions) ?? [
        "ios": .cupertino, "macos": .zoom,
      ],
    systemOverlayStyle: parseSystemUIOverlayStyle(
      raw["system_overlay_style"], brightness: effectiveBrightness,
      parentTheme?.systemOverlayStyle))
}

/// Cupertino is the sole Apple design system; Flet's theme wire object is
/// interpreted directly as a native Apple theme.
public func parseCupertinoTheme(
  _ value: Any?, brightness: RufletBrightness? = nil,
  parentTheme: RufletTheme? = nil
) -> RufletTheme {
  parseTheme(value, brightness: brightness, parentTheme: parentTheme)
}

@MainActor
public extension RufletControl {
  func brightness(
    _ propertyName: String, default defaultValue: RufletBrightness? = nil
  ) -> RufletBrightness? { parseBrightness(string(propertyName), defaultValue) }

  func theme(
    _ propertyName: String, brightness: RufletBrightness? = nil,
    parentTheme: RufletTheme? = nil
  ) -> RufletTheme {
    parseTheme(dynamicValue(propertyName), brightness: brightness, parentTheme: parentTheme)
  }

  func cupertinoTheme(
    _ propertyName: String, brightness: RufletBrightness? = nil,
    parentTheme: RufletTheme? = nil
  ) -> RufletTheme {
    parseCupertinoTheme(dynamicValue(propertyName), brightness: brightness, parentTheme: parentTheme)
  }

  func colorScheme(
    _ propertyName: String, default defaultValue: RufletColorScheme? = nil
  ) -> RufletColorScheme? { parseColorScheme(dynamicValue(propertyName), defaultValue) }

  func textTheme(
    _ propertyName: String, default defaultValue: RufletTextTheme? = nil
  ) -> RufletTextTheme? { parseTextTheme(dynamicValue(propertyName), defaultValue) }

  func visualDensity(
    _ propertyName: String, default defaultValue: RufletVisualDensity? = nil
  ) -> RufletVisualDensity? { parseVisualDensity(string(propertyName), defaultValue) }
}
