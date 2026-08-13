import SwiftUI

struct AnimatedTransitionPage<Content: View>: View {
    let fadeTransition: Bool
    let duration: TimeInterval
    @ViewBuilder let content: () -> Content

    init(
        fadeTransition: Bool = false,
        duration: TimeInterval = 0.3,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.fadeTransition = fadeTransition
        self.duration = duration
        self.content = content
    }

    var body: some View {
        content()
            .transition(fadeTransition && duration > 0 ? .opacity : .identity)
            .animation(.easeIn(duration: duration), value: fadeTransition)
            .accessibilityAddTraits(.isModal)
    }
}
