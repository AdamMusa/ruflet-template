import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Apple-native port of Flet's `PageMedia` widget.
@MainActor
struct RufletPageMedia: View {
  let control: RufletControl
  @Environment(\.colorScheme) private var colorScheme
  @State private var keyboardInset = 0.0
  @State private var pendingUpdate: Task<Void, Never>?

  var body: some View {
    GeometryReader { proxy in
      Color.clear
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { update(proxy: proxy, immediate: true) }
        .onChange(of: proxy.size) { _ in update(proxy: proxy, immediate: false) }
        .onChange(of: proxy.safeAreaInsets) { _ in update(proxy: proxy, immediate: false) }
        .onChange(of: colorScheme) { _ in update(proxy: proxy, immediate: true) }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
          keyboardInset = keyboardHeight(note, proxy: proxy)
          update(proxy: proxy, immediate: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
          keyboardInset = 0
          update(proxy: proxy, immediate: true)
        }
        #endif
        .onDisappear { pendingUpdate?.cancel() }
    }
  }

  private func update(proxy: GeometryProxy, immediate: Bool) {
    pendingUpdate?.cancel()
    let action = { @MainActor in
      guard let backend = control.backend as? RufletBackend else {
        preconditionFailure("RufletPageMedia requires RufletBackend")
      }
      let insets = proxy.safeAreaInsets
      let padding = RufletPaddingData(
        top: insets.top,
        right: insets.trailing,
        bottom: insets.bottom,
        left: insets.leading)
      let media = RufletPageMediaData(
        padding: padding,
        viewPadding: padding,
        viewInsets: RufletPaddingData(
          top: 0,
          right: 0,
          bottom: keyboardInset,
          left: 0),
        devicePixelRatio: defaultApplePixelRatio(),
        orientation: proxy.size.width > proxy.size.height ? .landscape : .portrait,
        alwaysUse24HourFormat: appleUses24HourTime)
      let brightness = colorScheme == .dark ? "dark" : "light"
      if backend.platformBrightness != brightness { backend.updateBrightness(brightness) }
      if backend.media != media { backend.updateMedia(media, view: control) }
      if backend.pageSize != proxy.size { backend.updatePageSize(proxy.size, view: control) }
    }
    if immediate {
      action()
    } else {
      pendingUpdate = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard !Task.isCancelled else { return }
        action()
      }
    }
  }

  #if os(iOS)
  private func keyboardHeight(_ note: Notification, proxy: GeometryProxy) -> Double {
    guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return 0 }
    return max(0, proxy.frame(in: .global).maxY - frame.minY)
  }
  #endif

  private var appleUses24HourTime: Bool {
    guard let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) else {
      return false
    }
    return !format.contains("a")
  }
}

@MainActor
enum RufletViewPopRegistry {
  typealias Handler = () async -> Bool
  private static var handlers: [ObjectIdentifier: Handler] = [:]

  static func register(control: RufletControl, handler: @escaping Handler) {
    handlers[ObjectIdentifier(control)] = handler
  }

  static func unregister(control: RufletControl) {
    handlers.removeValue(forKey: ObjectIdentifier(control))
  }

  static func confirmPop(control: RufletControl) async -> Bool {
    await handlers[ObjectIdentifier(control)]?() ?? false
  }
}
