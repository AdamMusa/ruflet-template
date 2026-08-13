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
  public subscript(_ name: String) -> Color? { colors[name] }
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
  let colors = names.reduce(into: [String: Color]()) { result, name in
    if let color = parseColor(value[name] as? String) { result[name] = color }
  }
  return RufletColorScheme(colors: colors)
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
  let styles = names.reduce(into: [String: RufletTextStyle]()) { result, name in
    if let style = parseTextStyle(value[name]) { result[name] = style }
  }
  return RufletTextTheme(styles: styles)
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
  return RufletTheme(
    raw: raw,
    brightness: effectiveBrightness,
    colorSchemeSeed: parseColor(raw["color_scheme_seed"] as? String, .blue)!,
    colorScheme: parseColorScheme(raw["color_scheme"], parentTheme?.colorScheme),
    fontFamily: raw["font_family"] as? String ?? parentTheme?.fontFamily,
    useMaterial3WireValue: parseBool(raw["use_material3"]),
    textTheme: parseTextTheme(raw["text_theme"], parentTheme?.textTheme),
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
