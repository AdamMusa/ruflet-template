import SwiftUI

func parseEdgeInsets(_ value: Any?, _ defaultValue: EdgeInsets? = nil) -> EdgeInsets? {
    if let amount = parseDouble(value), !(value is [AnyHashable: Any]), !(value is [String: Any]) {
        return EdgeInsets(top: amount, leading: amount, bottom: amount, trailing: amount)
    }
    guard let value = rufletDictionary(value) else { return defaultValue }
    return EdgeInsets(
        top: parseDouble(value["top"], 0)!,
        leading: parseDouble(value["left"], 0)!,
        bottom: parseDouble(value["bottom"], 0)!,
        trailing: parseDouble(value["right"], 0)!
    )
}

func parseMargin(_ value: Any?, _ defaultValue: EdgeInsets? = nil) -> EdgeInsets? {
    parseEdgeInsets(value, defaultValue)
}

func parsePadding(_ value: Any?, _ defaultValue: EdgeInsets? = nil) -> EdgeInsets? {
    parseEdgeInsets(value, defaultValue)
}
