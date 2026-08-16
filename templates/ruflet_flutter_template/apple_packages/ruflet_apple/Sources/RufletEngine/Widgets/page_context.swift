import SwiftUI

enum RufletThemeMode: String, CaseIterable, RufletStringEnum {
  case system, light, dark
}

private struct RufletThemeModeKey: EnvironmentKey {
  static let defaultValue = RufletThemeMode.system
}

private struct RufletPageThemeKey: EnvironmentKey {
  static let defaultValue: RufletTheme? = nil
}

private struct RufletPageDesignKey: EnvironmentKey {
  static let defaultValue = RufletPageDesign.material
}

private struct RufletPageBackgroundColorKey: EnvironmentKey {
  static let defaultValue: Color? = nil
}

private struct RufletBarBackgroundColorKey: EnvironmentKey {
  static let defaultValue: Color? = nil
}

extension EnvironmentValues {
  var rufletThemeMode: RufletThemeMode {
    get { self[RufletThemeModeKey.self] }
    set { self[RufletThemeModeKey.self] = newValue }
  }

  public var rufletPageTheme: RufletTheme? {
    get { self[RufletPageThemeKey.self] }
    set { self[RufletPageThemeKey.self] = newValue }
  }

  var rufletPageDesign: RufletPageDesign {
    get { self[RufletPageDesignKey.self] }
    set { self[RufletPageDesignKey.self] = newValue }
  }

  var rufletPageBackgroundColor: Color? {
    get { self[RufletPageBackgroundColorKey.self] }
    set { self[RufletPageBackgroundColorKey.self] = newValue }
  }

  var rufletBarBackgroundColor: Color? {
    get { self[RufletBarBackgroundColorKey.self] }
    set { self[RufletBarBackgroundColorKey.self] = newValue }
  }
}

/// Page theme boundary matching Flet's MaterialApp/CupertinoApp design choice.
struct PageContext<Content: View>: View {
  let themeMode: RufletThemeMode
  let theme: RufletTheme?
  let design: RufletPageDesign
  @ViewBuilder let content: () -> Content

  init(
    themeMode: RufletThemeMode,
    theme: RufletTheme? = nil,
    design: RufletPageDesign,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.themeMode = themeMode
    self.theme = theme
    self.design = design
    self.content = content
  }

  var body: some View {
    content()
      .environment(\.rufletThemeMode, themeMode)
      .environment(\.rufletPageTheme, theme)
      .environment(\.rufletPageDesign, design)
      .environment(\.rufletPageBackgroundColor, theme?.applePageBackgroundColor)
      .environment(\.rufletBarBackgroundColor, theme?.appleBarBackgroundColor)
      .preferredColorScheme(themeMode.colorScheme)
      .modifier(RufletApplePageThemeModifier(theme: theme))
  }
}

private extension RufletThemeMode {
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

private struct RufletApplePageThemeModifier: ViewModifier {
  let theme: RufletTheme?

  @ViewBuilder
  func body(content: Content) -> some View {
    themedFont(
      themedForeground(
        themedBackground(
          content
            .tint(theme?.appleAccentColor)
            .accentColor(theme?.appleAccentColor))))
  }

  @ViewBuilder
  private func themedBackground<Content: View>(_ content: Content) -> some View {
    if let background = theme?.applePageBackgroundColor {
      content.background(background.ignoresSafeArea())
    } else {
      content
    }
  }

  @ViewBuilder
  private func themedForeground<Content: View>(_ content: Content) -> some View {
    if let foreground = theme?.appleContentColor {
      content.foregroundStyle(foreground)
    } else {
      content
    }
  }

  @ViewBuilder
  private func themedFont<Content: View>(_ content: Content) -> some View {
    if let family = theme?.fontFamily {
      content.font(.custom(family, size: 17, relativeTo: .body))
    } else {
      content
    }
  }
}
