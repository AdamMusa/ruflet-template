import Foundation

/// Initializes the Apple desktop host before the first Ruflet page is shown.
@MainActor
public func setupDesktop(hideWindowOnStart: Bool = false) async {
  #if os(macOS)
  let environmentRequestsHidden = ProcessInfo.processInfo.environment["FLET_HIDE_WINDOW_ON_START"] != nil
  guard !environmentRequestsHidden, !hideWindowOnStart else { return }
  await showWindow()
  await focusWindow()
  #endif
}
