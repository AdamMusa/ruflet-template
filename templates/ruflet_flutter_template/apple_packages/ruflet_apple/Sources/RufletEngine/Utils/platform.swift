import Foundation
import RufletProtocol

public enum RufletTargetPlatform: String, CaseIterable, Sendable {
  case android, fuchsia, iOS = "ios", linux, macOS = "macos", windows
}

public var rufletIsDesktopPlatform: Bool {
  #if os(macOS)
    true
  #else
    false
  #endif
}

public var rufletIsWindowsDesktop: Bool { false }
public var rufletIsMacOSDesktop: Bool { rufletIsDesktopPlatform }
public var rufletIsLinuxDesktop: Bool { false }

public var rufletIsMobilePlatform: Bool {
  #if os(iOS)
    true
  #else
    false
  #endif
}

public var rufletIsIOSMobile: Bool { rufletIsMobilePlatform }
public var rufletIsAndroidMobile: Bool { false }
public var rufletIsApplePlatform: Bool { true }
public var rufletIsWebPlatform: Bool { false }

public var rufletDefaultTargetPlatform: RufletTargetPlatform {
  #if os(macOS)
    .macOS
  #else
    .iOS
  #endif
}

public func parseTargetPlatform(
  _ value: String?,
  _ defaultValue: RufletTargetPlatform? = nil
) -> RufletTargetPlatform? {
  guard let value else { return defaultValue }
  return RufletTargetPlatform(rawValue: value.lowercased()) ?? defaultValue
}

/// Exact non-web endpoint-path rule from pinned Flet.
public func rufletWebSocketEndpointPath(_ uriPath: String) -> String {
  let pagePath = uriPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  return pagePath.isEmpty ? "ws" : "\(pagePath)/ws"
}

public var rufletIsProgressiveWebApp: Bool { false }
public var rufletRouteURLStrategy: String { "" }
public var rufletIsPyodideMode: Bool { false }
public var rufletIsMultiViewEnvironment: Bool { false }
public func rufletViewInitialData(_ viewID: Int) -> [String: RufletValue] { [:] }

/// Pinned non-web Flet intentionally implements this as a no-op.
public func rufletOpenPopupBrowserWindow(
  _ url: String,
  windowName: String,
  minWidth: Int,
  minHeight: Int
) {}
