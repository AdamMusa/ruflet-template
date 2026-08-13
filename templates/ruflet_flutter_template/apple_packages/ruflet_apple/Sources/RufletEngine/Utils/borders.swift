import SwiftUI

public struct RufletBorderRadius: Equatable, Sendable {
    public let topLeft: Double
    public let topRight: Double
    public let bottomLeft: Double
    public let bottomRight: Double

    static let zero = RufletBorderRadius(topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0)
    var uniform: Double? {
        topLeft == topRight && topRight == bottomLeft && bottomLeft == bottomRight ? topLeft : nil
    }
}

public struct RufletBorderSide {
    public let width: Double
    public let color: Color
}

public struct RufletBorder {
    public let left: RufletBorderSide?
    public let top: RufletBorderSide?
    public let right: RufletBorderSide?
    public let bottom: RufletBorderSide?
}

public func parseBorderRadius(_ value: Any?, _ defaultValue: RufletBorderRadius? = nil) -> RufletBorderRadius? {
    if rufletDictionary(value) == nil, let radius = parseDouble(value) {
        return RufletBorderRadius(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }
    guard let value = rufletDictionary(value) else { return defaultValue }
    return RufletBorderRadius(
        topLeft: parseDouble(value["top_left"], 0)!,
        topRight: parseDouble(value["top_right"], 0)!,
        bottomLeft: parseDouble(value["bottom_left"], 0)!,
        bottomRight: parseDouble(value["bottom_right"], 0)!
    )
}

public func parseBorderSide(
    _ value: Any?,
    defaultColor: Color = .primary,
    defaultValue: RufletBorderSide? = nil
) -> RufletBorderSide? {
    guard let value = rufletDictionary(value) else { return defaultValue }
    return RufletBorderSide(
        width: parseDouble(value["width"], 1)!,
        color: parseColor(value["color"] as? String, defaultColor)!
    )
}

public func parseBorder(_ value: Any?, defaultColor: Color = .primary) -> RufletBorder? {
    guard let value = rufletDictionary(value) else { return nil }
    if value["width"] != nil || value["color"] != nil {
        let side = parseBorderSide(value, defaultColor: defaultColor)
        return RufletBorder(left: side, top: side, right: side, bottom: side)
    }
    return RufletBorder(
        left: parseBorderSide(value["left"], defaultColor: defaultColor),
        top: parseBorderSide(value["top"], defaultColor: defaultColor),
        right: parseBorderSide(value["right"], defaultColor: defaultColor),
        bottom: parseBorderSide(value["bottom"], defaultColor: defaultColor)
    )
}
