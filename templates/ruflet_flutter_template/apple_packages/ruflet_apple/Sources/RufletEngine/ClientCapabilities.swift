import Foundation
import RufletProtocol

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// What the engine tells Ruby about itself at registration.
///
/// `Ruflet::Protocol.normalize_register_payload` lifts `route`, `width`,
/// `height`, `platform`, `platform_brightness`, `window` and `media` out of the
/// nested `page` map, and `Page#method_missing` serves them straight back to
/// application code as `page.width`, `page.platform` and so on. Getting the
/// names right here is what makes an unmodified Ruby app behave the same
/// against this engine as against the Flutter one.
public struct ClientCapabilities {
  public var sessionID: String
  public var pageName: String
  public var route: String
  public var width: Double
  public var height: Double
  public var platform: String
  public var platformBrightness: String
  public var window: [String: RufletValue]
  public var media: [String: RufletValue]

  public init(
    sessionID: String = "",
    pageName: String = "",
    route: String = "/",
    width: Double = 0,
    height: Double = 0,
    platform: String = ClientCapabilities.currentPlatform,
    platformBrightness: String = "light",
    window: [String: RufletValue] = [:],
    media: [String: RufletValue] = [:]
  ) {
    self.sessionID = sessionID
    self.pageName = pageName
    self.route = route
    self.width = width
    self.height = height
    self.platform = platform
    self.platformBrightness = platformBrightness
    self.window = window
    self.media = media
  }

  /// The value Flet reports for these platforms, so `page.platform == "ios"`
  /// keeps working in application code written against the Flutter client.
  public static var currentPlatform: String {
    #if os(iOS)
      return "ios"
    #elseif os(macOS)
      return "macos"
    #elseif os(tvOS)
      return "tvos"
    #else
      return "unknown"
    #endif
  }

  /// A snapshot of the current screen, filled in from the platform at connect
  /// time so `page.width`/`page.height` are meaningful on first render.
  public static func current(route: String = "/") -> ClientCapabilities {
    var capabilities = ClientCapabilities(route: route)

    #if os(iOS) || os(tvOS)
      let screen = UIScreen.main.bounds
      capabilities.width = Double(screen.width)
      capabilities.height = Double(screen.height)
      capabilities.platformBrightness =
        UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light"
      capabilities.media = [
        "device_pixel_ratio": .double(Double(UIScreen.main.scale))
      ]
    #elseif os(macOS)
      if let screen = NSScreen.main {
        capabilities.width = Double(screen.frame.width)
        capabilities.height = Double(screen.frame.height)
        capabilities.media = [
          "device_pixel_ratio": .double(Double(screen.backingScaleFactor))
        ]
      }
      let appearance = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
      capabilities.platformBrightness = appearance == .darkAqua ? "dark" : "light"
      capabilities.window = [
        "width": .double(capabilities.width),
        "height": .double(capabilities.height)
      ]
    #endif

    return capabilities
  }

  /// The `register_client` payload.
  public func registerPayload() -> RufletValue {
    var page: [String: RufletValue] = [
      "route": .string(route),
      "width": .double(width),
      "height": .double(height),
      "platform": .string(platform),
      "platform_brightness": .string(platformBrightness),
      "window": .map(window),
      "media": .map(media)
    ]
    // Flet clients report this; Ruflet reads it through `Page#web`, which must
    // answer false for a native shell.
    page["web"] = .bool(false)

    return .map([
      "session_id": .string(sessionID),
      "page_name": .string(pageName),
      "page": .map(page)
    ])
  }
}
