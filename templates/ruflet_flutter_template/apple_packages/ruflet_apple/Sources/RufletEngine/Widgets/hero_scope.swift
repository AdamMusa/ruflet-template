import SwiftUI

private struct RufletHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var rufletHeroNamespace: Namespace.ID? {
        get { self[RufletHeroNamespaceKey.self] }
        set { self[RufletHeroNamespaceKey.self] = newValue }
    }
}

/// Owns the single matched-geometry namespace shared by Ruflet's page stack.
struct RufletHeroScope<Content: View>: View {
    @Namespace private var namespace
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content().environment(\.rufletHeroNamespace, namespace)
    }
}
