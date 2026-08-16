import SwiftUI

public enum RufletTabBarIndicatorSize: String, CaseIterable, RufletStringEnum {
  case tab
  case label
}

public enum RufletTabIndicatorAnimation: String, CaseIterable, RufletStringEnum {
  case linear
  case elastic
}

public enum RufletTabAlignment: String, CaseIterable, RufletStringEnum {
  case start
  case startOffset
  case fill
  case center
}

public struct RufletUnderlineTabIndicator {
  public let insets: EdgeInsets
  public let borderSide: RufletBorderSide
  public let borderRadius: RufletBorderRadius?
}

public func parseTabBarIndicatorSize(
  _ value: String?, _ defaultValue: RufletTabBarIndicatorSize? = nil
) -> RufletTabBarIndicatorSize? {
  parseEnum(RufletTabBarIndicatorSize.self, value, defaultValue)
}

public func parseTabIndicatorAnimation(
  _ value: String?, _ defaultValue: RufletTabIndicatorAnimation? = nil
) -> RufletTabIndicatorAnimation? {
  parseEnum(RufletTabIndicatorAnimation.self, value, defaultValue)
}

public func parseTabAlignment(
  _ value: String?, _ defaultValue: RufletTabAlignment? = nil
) -> RufletTabAlignment? {
  parseEnum(RufletTabAlignment.self, value, defaultValue)
}

public func parseUnderlineTabIndicator(
  _ value: Any?, _ defaultValue: RufletUnderlineTabIndicator? = nil
) -> RufletUnderlineTabIndicator? {
  guard let value = rufletDictionary(value) else { return defaultValue }
  return RufletUnderlineTabIndicator(
    insets: parseEdgeInsets(value["insets"], EdgeInsets())!,
    borderSide: parseBorderSide(
      value["border_side"], defaultColor: .white,
      defaultValue: RufletBorderSide(width: 2, color: .white))!,
    borderRadius: parseBorderRadius(value["border_radius"]))
}

@MainActor
public extension RufletControl {
  func tabBarIndicatorSize(
    _ propertyName: String, default defaultValue: RufletTabBarIndicatorSize? = nil
  ) -> RufletTabBarIndicatorSize? { parseTabBarIndicatorSize(string(propertyName), defaultValue) }

  func tabIndicatorAnimation(
    _ propertyName: String, default defaultValue: RufletTabIndicatorAnimation? = nil
  ) -> RufletTabIndicatorAnimation? { parseTabIndicatorAnimation(string(propertyName), defaultValue) }

  func tabAlignment(
    _ propertyName: String, default defaultValue: RufletTabAlignment? = nil
  ) -> RufletTabAlignment? { parseTabAlignment(string(propertyName), defaultValue) }

  func underlineTabIndicator(
    _ propertyName: String, default defaultValue: RufletUnderlineTabIndicator? = nil
  ) -> RufletUnderlineTabIndicator? {
    parseUnderlineTabIndicator(dynamicValue(propertyName), defaultValue)
  }
}
