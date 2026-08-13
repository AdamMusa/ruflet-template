import Foundation

/// Process-wide handoff for a URL delivered before the native Ruflet router is ready.
@MainActor
public enum RufletDeepLinkingBootstrap {
  private static var pendingInitialURL: URL?

  public static func publish(_ url: URL) {
    pendingInitialURL = url
  }

  public static func takePendingInitialURL() -> URL? {
    defer { pendingInitialURL = nil }
    return pendingInitialURL
  }
}
