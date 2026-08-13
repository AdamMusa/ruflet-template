import SwiftUI

public struct RufletSystemUIOverlayStyle {
  public let statusBarColor: Color?
  public let navigationBarColor: Color?
  public let navigationBarDividerColor: Color?
  public let enforceStatusBarContrast: Bool?
  public let enforceNavigationBarContrast: Bool?
  public let navigationBarIconBrightness: RufletBrightness?
  public let statusBarBrightness: RufletBrightness?
  public let statusBarIconBrightness: RufletBrightness?
}

public func parseSystemUIOverlayStyle(
  _ value: Any?, brightness: RufletBrightness? = nil,
  _ defaultValue: RufletSystemUIOverlayStyle? = nil
) -> RufletSystemUIOverlayStyle? {
  guard let value = rufletDictionary(value) else { return defaultValue }
  let inverted = brightness?.inverted
  return RufletSystemUIOverlayStyle(
    statusBarColor: parseColor(value["status_bar_color"] as? String),
    navigationBarColor: parseColor(value["system_navigation_bar_color"] as? String),
    navigationBarDividerColor: parseColor(value["system_navigation_bar_divider_color"] as? String),
    enforceStatusBarContrast: parseBool(value["enforce_system_status_bar_contrast"]),
    enforceNavigationBarContrast: parseBool(value["enforce_system_navigation_bar_contrast"]),
    navigationBarIconBrightness: parseBrightness(
      value["system_navigation_bar_icon_brightness"] as? String, inverted),
    statusBarBrightness: parseBrightness(value["status_bar_brightness"] as? String, brightness),
    statusBarIconBrightness: parseBrightness(
      value["status_bar_icon_brightness"] as? String, inverted))
}

@MainActor
public extension RufletControl {
  func systemUIOverlayStyle(
    _ propertyName: String, brightness: RufletBrightness? = nil,
    default defaultValue: RufletSystemUIOverlayStyle? = nil
  ) -> RufletSystemUIOverlayStyle? {
    parseSystemUIOverlayStyle(dynamicValue(propertyName), brightness: brightness, defaultValue)
  }
}
