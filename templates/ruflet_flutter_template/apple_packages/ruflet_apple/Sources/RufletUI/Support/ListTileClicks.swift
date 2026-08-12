import SwiftUI

/// SwiftUI equivalent of Flet's `ListTileClicks` inherited widget.
///
/// A tile owns one notifier and installs it only when `toggle_inputs` is true.
/// Selection controls anywhere below that tile observe the same notifier, so
/// tapping the row follows the exact same path as tapping the nested control.
/// Keeping this as environment state (rather than searching the control tree)
/// also preserves Flet's scope: only descendants of that particular tile are
/// toggled.
final class RufletListTileClickNotifier: ObservableObject {
  @Published private(set) var generation = 0

  func click() { generation &+= 1 }
}

private struct RufletListTileClicksKey: EnvironmentKey {
  static let defaultValue: RufletListTileClickNotifier? = nil
}

extension EnvironmentValues {
  var rufletListTileClicks: RufletListTileClickNotifier? {
    get { self[RufletListTileClicksKey.self] }
    set { self[RufletListTileClicksKey.self] = newValue }
  }
}

/// Optional observer used by every Material and Cupertino selection control.
/// An absent inherited notifier leaves the control completely unchanged.
struct ListTileToggleListener: ViewModifier {
  let notifier: RufletListTileClickNotifier?
  let action: () -> Void

  func body(content: Content) -> some View {
    if let notifier {
      ListTileToggleObserver(notifier: notifier, action: action) { content }
    } else {
      content
    }
  }
}

private struct ListTileToggleObserver<Content: View>: View {
  @ObservedObject var notifier: RufletListTileClickNotifier
  let action: () -> Void
  @ViewBuilder let content: () -> Content
  @State private var mountedGeneration: Int?

  var body: some View {
    content()
      .onAppear { mountedGeneration = notifier.generation }
      .onChange(of: notifier.generation) { generation in
        // Installing an inherited source must not itself toggle the input.
        guard let previous = mountedGeneration else {
          mountedGeneration = generation
          return
        }
        mountedGeneration = generation
        if generation != previous { action() }
      }
  }
}
