import SwiftUI

#if os(iOS)
  import UIKit

  struct RufletSafeAreaKeyboardBridge: UIViewRepresentable {
    @Binding var keyboardOverlap: CGFloat
    @Binding var persistentBottomInset: CGFloat

    func makeCoordinator() -> Coordinator {
      Coordinator(
        keyboardOverlap: $keyboardOverlap,
        persistentBottomInset: $persistentBottomInset
      )
    }

    func makeUIView(context: Context) -> RufletSafeAreaKeyboardProbeView {
      let view = RufletSafeAreaKeyboardProbeView()
      context.coordinator.attach(to: view)
      return view
    }

    func updateUIView(_ view: RufletSafeAreaKeyboardProbeView, context: Context) {
      context.coordinator.keyboardOverlap = $keyboardOverlap
      context.coordinator.persistentBottomInset = $persistentBottomInset
      context.coordinator.attach(to: view)
      context.coordinator.refresh()
    }

    static func dismantleUIView(_ view: RufletSafeAreaKeyboardProbeView, coordinator: Coordinator) {
      coordinator.detach()
    }

    final class Coordinator {
      var keyboardOverlap: Binding<CGFloat>
      var persistentBottomInset: Binding<CGFloat>
      private weak var view: RufletSafeAreaKeyboardProbeView?
      private var observers: [NSObjectProtocol] = []
      private var keyboardFrame: CGRect?

      init(
        keyboardOverlap: Binding<CGFloat>,
        persistentBottomInset: Binding<CGFloat>
      ) {
        self.keyboardOverlap = keyboardOverlap
        self.persistentBottomInset = persistentBottomInset
      }

      func attach(to view: RufletSafeAreaKeyboardProbeView) {
        self.view = view
        view.didMoveToWindowHandler = { [weak self] in self?.refresh() }
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
          center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
          ) { [weak self] notification in
            self?.keyboardFrame =
              notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            self?.refresh()
          },
          center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
          ) { [weak self] _ in
            self?.keyboardFrame = nil
            self?.refresh()
          },
        ]
      }

      func detach() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        view?.didMoveToWindowHandler = nil
        view = nil
        keyboardFrame = nil
        setIfChanged(keyboardOverlap, to: 0)
      }

      func refresh() {
        guard let window = view?.window else {
          setIfChanged(keyboardOverlap, to: 0)
          return
        }
        setIfChanged(persistentBottomInset, to: window.safeAreaInsets.bottom)
        guard let keyboardFrame else {
          setIfChanged(keyboardOverlap, to: 0)
          return
        }
        let windowFrame = window.convert(window.bounds, to: nil)
        setIfChanged(keyboardOverlap, to: windowFrame.intersection(keyboardFrame).height)
      }

      private func setIfChanged(_ binding: Binding<CGFloat>, to value: CGFloat) {
        guard abs(binding.wrappedValue - value) > 0.5 else { return }
        binding.wrappedValue = value
      }
    }
  }

  final class RufletSafeAreaKeyboardProbeView: UIView {
    var didMoveToWindowHandler: (() -> Void)?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      didMoveToWindowHandler?()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
  }
#else
  struct RufletSafeAreaKeyboardBridge: View {
    @Binding var keyboardOverlap: CGFloat
    @Binding var persistentBottomInset: CGFloat

    var body: some View { Color.clear.frame(width: 0, height: 0) }
  }
#endif
