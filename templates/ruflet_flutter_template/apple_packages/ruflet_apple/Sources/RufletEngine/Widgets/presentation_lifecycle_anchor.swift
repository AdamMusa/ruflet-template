import SwiftUI

/// Keeps a server-driven presenter mounted before it has visible content.
/// SwiftUI does not reliably deliver `onAppear` to an empty `Group`, while a
/// full-screen clear view can steal touches from the route below it.
struct RufletPresentationLifecycleAnchor: View {
  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}
