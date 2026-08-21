import SwiftUI

#if os(iOS)
  import UIKit

  @MainActor
  func rufletCurrentWindowSafeAreaInsets() -> RufletSafeAreaInsets {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes
      .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
      .flatMap(\.windows)
    let window = windows.first(where: \.isKeyWindow) ?? windows.first
    guard let insets = window?.safeAreaInsets else { return .zero }
    return RufletSafeAreaInsets(
      top: insets.top,
      leading: insets.left,
      bottom: insets.bottom,
      trailing: insets.right)
  }

  struct RufletWindowSafeAreaProbe: UIViewRepresentable {
    let onChange: @MainActor (RufletSafeAreaInsets) -> Void

    func makeUIView(context: Context) -> ProbeView {
      let view = ProbeView()
      view.onChange = onChange
      return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
      view.onChange = onChange
      view.publish()
    }

    @MainActor
    final class ProbeView: UIView {
      var onChange: (@MainActor (RufletSafeAreaInsets) -> Void)?

      override func didMoveToWindow() {
        super.didMoveToWindow()
        publish()
      }

      override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        publish()
      }

      func publish() {
        guard let insets = window?.safeAreaInsets else { return }
        let value = RufletSafeAreaInsets(
          top: insets.top,
          leading: insets.left,
          bottom: insets.bottom,
          trailing: insets.right)
        DispatchQueue.main.async { [weak self] in self?.onChange?(value) }
      }
    }
  }
#else
  @MainActor
  func rufletCurrentWindowSafeAreaInsets() -> RufletSafeAreaInsets { .zero }

  struct RufletWindowSafeAreaProbe: View {
    let onChange: @MainActor (RufletSafeAreaInsets) -> Void
    var body: some View { EmptyView() }
  }
#endif
