import SwiftUI

@MainActor
struct ControlInheritedNotifier<Content: View>: View {
  @ObservedObject var control: RufletControl
  @Environment(\.rufletThemeMode) private var inheritedThemeMode
  @Environment(\.rufletPageTheme) private var inheritedTheme
  @ViewBuilder let content: () -> Content

  @ViewBuilder
  var body: some View {
    if let themeContext {
      content()
        .environment(\.rufletThemeMode, themeContext.mode)
        .environment(\.rufletPageTheme, themeContext.theme)
        .environment(\.rufletPageBackgroundColor, themeContext.theme.applePageBackgroundColor)
        .environment(\.rufletBarBackgroundColor, themeContext.theme.appleBarBackgroundColor)
        .environment(\.colorScheme, themeContext.brightness.colorScheme)
        .modifier(RufletControlThemeModifier(theme: themeContext.theme))
    } else {
      content()
    }
  }

  private var themeContext: RufletControlThemeContext? {
    let platformBrightness =
      (control.backend as? RufletBackend)
      .flatMap { parseBrightness($0.platformBrightness) } ?? .light
    return rufletControlThemeContext(
      control: control,
      inheritedMode: inheritedThemeMode,
      inheritedTheme: inheritedTheme,
      platformBrightness: platformBrightness)
  }
}

@MainActor
extension RufletControl {
  var skipsInheritedNotifier: Bool {
    internals?["skip_inherited_notifier"]?.bool == true
  }
}

struct RufletControlThemeContext {
  let mode: RufletThemeMode
  let brightness: RufletBrightness
  let theme: RufletTheme
}

@MainActor
func rufletControlThemeContext(
  control: RufletControl,
  inheritedMode: RufletThemeMode,
  inheritedTheme: RufletTheme?,
  platformBrightness: RufletBrightness
) -> RufletControlThemeContext? {
  guard control.type != "Page", !control.skipsInheritedNotifier else { return nil }
  let explicitMode = parseThemeMode(control.string("theme_mode"))
  let hasTheme = control.value("theme").map { $0 != .null } ?? false
  let hasDarkTheme = control.value("dark_theme").map { $0 != .null } ?? false
  guard explicitMode != nil || hasTheme || hasDarkTheme else { return nil }

  let mode = explicitMode ?? inheritedMode
  let brightness: RufletBrightness
  switch mode {
  case .light:
    brightness = .light
  case .dark:
    brightness = .dark
  case .system:
    brightness = platformBrightness
  }

  // Pinned Flet inherits the ambient Theme only when theme_mode is omitted.
  // An explicit mode starts a fresh theme at that brightness.
  let parentTheme = explicitMode == nil ? inheritedTheme : nil
  let rawTheme = control.dynamicValue(brightness == .dark ? "dark_theme" : "theme")
  return RufletControlThemeContext(
    mode: mode,
    brightness: brightness,
    theme: parseCupertinoTheme(rawTheme, brightness: brightness, parentTheme: parentTheme))
}

extension RufletBrightness {
  fileprivate var colorScheme: ColorScheme { self == .dark ? .dark : .light }
}

private struct RufletControlThemeModifier: ViewModifier {
  let theme: RufletTheme

  @ViewBuilder
  func body(content: Content) -> some View {
    themedFont(themedForeground(content.tint(theme.appleAccentColor)))
  }

  @ViewBuilder
  private func themedForeground<Content: View>(_ content: Content) -> some View {
    if let color = theme.appleContentColor {
      content.foregroundStyle(color)
    } else {
      content
    }
  }

  @ViewBuilder
  private func themedFont<Content: View>(_ content: Content) -> some View {
    if let family = theme.fontFamily {
      content.font(.custom(family, size: 17, relativeTo: .body))
    } else {
      content
    }
  }
}
