import SwiftUI

struct LoadingPage: View {
    let isLoading: Bool
    let message: String

    var body: some View {
        ZStack {
            Color.rufletSystemBackground
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

extension Color {
    static var rufletSystemBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}
