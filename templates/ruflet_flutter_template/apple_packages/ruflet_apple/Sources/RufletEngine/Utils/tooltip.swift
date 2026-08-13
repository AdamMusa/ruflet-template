import SwiftUI

public enum RufletTooltipTriggerMode: String, CaseIterable, RufletStringEnum {
  case manual
  case tap
  case longPress
}

public struct RufletTooltipConfiguration {
  public let message: String
  public let enableFeedback: Bool?
  public let tapToDismiss: Bool
  public let excludeFromSemantics: Bool?
  public let exitDuration: TimeInterval?
  public let preferBelow: Bool?
  public let padding: EdgeInsets?
  public let backgroundColor: Color?
  public let textStyle: RufletTextStyle?
  public let verticalOffset: Double?
  public let margin: EdgeInsets?
  public let textAlignment: RufletTextAlign?
  public let showDuration: TimeInterval?
  public let waitDuration: TimeInterval
  public let triggerMode: RufletTooltipTriggerMode?
}

public func parseTooltipTriggerMode(
  _ value: String?, _ defaultValue: RufletTooltipTriggerMode? = nil
) -> RufletTooltipTriggerMode? {
  parseEnum(RufletTooltipTriggerMode.self, value, defaultValue)
}

public func parseTooltip(
  _ value: Any?, _ defaultValue: RufletTooltipConfiguration? = nil
) -> RufletTooltipConfiguration? {
  if let message = value as? String {
    return RufletTooltipConfiguration(
      message: message, enableFeedback: nil, tapToDismiss: true,
      excludeFromSemantics: nil, exitDuration: nil, preferBelow: nil, padding: nil,
      backgroundColor: nil, textStyle: nil, verticalOffset: nil, margin: nil,
      textAlignment: nil, showDuration: nil, waitDuration: 0.8, triggerMode: nil)
  }
  guard let value = rufletDictionary(value), let message = value["message"] as? String else {
    return defaultValue
  }
  let decoration = rufletDictionary(value["decoration"])
  return RufletTooltipConfiguration(
    message: message,
    enableFeedback: parseBool(value["enable_feedback"]),
    tapToDismiss: parseBool(value["tap_to_dismiss"], true)!,
    excludeFromSemantics: parseBool(value["exclude_from_semantics"]),
    exitDuration: parseDuration(value["exit_duration"]),
    preferBelow: parseBool(value["prefer_below"]),
    padding: parseEdgeInsets(value["padding"]),
    backgroundColor: parseColor(
      decoration?["color"] as? String ?? value["bgcolor"] as? String),
    textStyle: parseTextStyle(value["text_style"]),
    verticalOffset: parseDouble(value["vertical_offset"]),
    margin: parseEdgeInsets(value["margin"]),
    textAlignment: parseEnum(RufletTextAlign.self, value["text_align"] as? String),
    showDuration: parseDuration(value["show_duration"]),
    waitDuration: parseDuration(value["wait_duration"], 0.8)!,
    triggerMode: parseTooltipTriggerMode(value["trigger_mode"] as? String))
}

@MainActor
public extension RufletControl {
  func tooltipTriggerMode(
    _ propertyName: String, default defaultValue: RufletTooltipTriggerMode? = nil
  ) -> RufletTooltipTriggerMode? { parseTooltipTriggerMode(string(propertyName), defaultValue) }
}
