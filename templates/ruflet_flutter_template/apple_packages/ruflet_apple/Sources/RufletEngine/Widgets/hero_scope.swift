import SwiftUI

struct RufletHeroNamespaceKey: EnvironmentKey {
  static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
  var rufletHeroNamespace: Namespace.ID? {
    get { self[RufletHeroNamespaceKey.self] }
    set { self[RufletHeroNamespaceKey.self] = newValue }
  }
}

/// Shared across the native navigation controller and every hosted page.
/// UIKit reports the interactive-pop lifecycle; Hero uses it to apply Flet's
/// `transitionOnUserGestures` participation rule.
@MainActor
final class RufletHeroTransitionState: ObservableObject {
  @Published private(set) var isInteractiveNavigation = false

  func updateInteractiveNavigation(_ active: Bool) {
    guard isInteractiveNavigation != active else { return }
    isInteractiveNavigation = active
  }
}

func rufletHeroParticipatesInTransition(
  transitionOnUserGestures: Bool,
  isInteractiveNavigation: Bool
) -> Bool {
  !isInteractiveNavigation || transitionOnUserGestures
}

/// Owns the single matched-geometry namespace and interactive navigation
/// state shared by Ruflet's complete page stack.
struct RufletHeroScope<Content: View>: View {
  @Namespace private var namespace
  @StateObject private var transitionState = RufletHeroTransitionState()
  @ViewBuilder let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  var body: some View {
    content()
      .environment(\.rufletHeroNamespace, namespace)
      .environmentObject(transitionState)
  }
}
