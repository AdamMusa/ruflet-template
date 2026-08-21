import SwiftUI

struct LoadingPage: View {
    let isLoading: Bool
    let message: String
    @Environment(\.rufletPageTheme) private var pageTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Pinned Flet paints LoadingPage with Theme.colorScheme.surface.
            // In particular, a nested FletApp inherits its parent's theme
            // while its own Page is still connecting; it must not flash a
            // UIKit system background that was never sent by the application.
            rufletLoadingSurfaceColor(pageTheme: pageTheme, colorScheme: colorScheme)
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView().controlSize(.large)
                    if !message.isEmpty {
                        Text(message).font(.footnote)
                    }
                }
            } else if !message.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 30))
                    Text(message)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .padding(20)
            }
        }
    }
}

func rufletLoadingSurfaceColor(pageTheme: RufletTheme?, colorScheme: ColorScheme) -> Color {
    let theme = pageTheme ?? parseCupertinoTheme(
        nil,
        brightness: colorScheme == .dark ? .dark : .light)
    // parseCupertinoTheme always materializes Flet's complete color scheme.
    return theme.colorScheme!["surface"]!
}

extension Color {
    static var rufletSystemBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}
