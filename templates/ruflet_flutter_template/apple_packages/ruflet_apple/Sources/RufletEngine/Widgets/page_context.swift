import SwiftUI

enum RufletThemeMode: String, CaseIterable, RufletStringEnum {
    case system, light, dark
}

private struct RufletThemeModeKey: EnvironmentKey {
    static let defaultValue = RufletThemeMode.system
}

extension EnvironmentValues {
    var rufletThemeMode: RufletThemeMode {
        get { self[RufletThemeModeKey.self] }
        set { self[RufletThemeModeKey.self] = newValue }
    }
}

struct PageContext<Content: View>: View {
    let themeMode: RufletThemeMode
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.rufletThemeMode, themeMode)
            .preferredColorScheme(themeMode.colorScheme)
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
