import SwiftUI

/// Exact Cupertino color wire names accepted by the pinned Flet client.
public let rufletCupertinoColorNames: Set<String> = [
  "activeblue", "activegreen", "activeorange", "cupertinowhite", "cupertinoblack",
  "lightbackgroundgray", "extralightbackgroundgray", "darkbackgroundgray", "inactivegray",
  "destructivered", "systemblue", "systemgreen", "systemmint", "systemindigo",
  "systemorange", "systempink", "systembrown", "systempurple", "systemred", "systemteal",
  "systemcyan", "systemyellow", "systemgrey", "systemgrey2", "systemgrey3", "systemgrey4",
  "systemgrey5", "systemgrey6", "label", "secondarylabel", "tertiarylabel",
  "quaternarylabel", "systemfill", "secondarysystemfill", "tertiarysystemfill",
  "quaternarysystemfill", "placeholdertext", "systembackground",
  "secondarysystembackground", "tertiarysystembackground", "systemgroupedbackground",
  "secondarysystemgroupedbackground", "tertiarysystemgroupedbackground", "separator",
  "opaqueseparator", "link",
]

public func parseCupertinoColor(_ value: String?, _ defaultColor: Color? = nil) -> Color? {
  guard let value else { return defaultColor }
  let normalized = value.lowercased().replacingOccurrences(
    of: #"[_\-\s]+"#, with: "", options: .regularExpression)
  guard rufletCupertinoColorNames.contains(normalized) else { return defaultColor }
  return parseColor(normalized, defaultColor)
}
