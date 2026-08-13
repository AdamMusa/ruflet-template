import SwiftUI

public struct ImplicitAnimationDetails: Equatable, Sendable {
    public let duration: TimeInterval
    public let curve: RufletCurve

    var animation: Animation { curve.animation(duration: duration) }
}

public enum RufletCurve: String, CaseIterable, RufletStringEnum, Sendable {
    case bouncein, bounceinout, bounceout, decelerate, ease, easein, easeinback
    case easeincirc, easeincubic, easeinexpo, easeinout, easeinoutback, easeinoutcirc
    case easeinoutcubic, easeinoutcubicemphasized, easeinoutexpo, easeinoutquad
    case easeinoutquart, easeinoutquint, easeinoutsine, easeinquad, easeinquart
    case easeinquint, easeinsine, easeintolinear, easeout, easeoutback, easeoutcirc
    case easeoutcubic, easeoutexpo, easeoutquad, easeoutquart, easeoutquint, easeoutsine
    case elasticin, elasticinout, elasticout, fastlineartosloweasein, fastoutslowin
    case lineartoeaseout, slowmiddle, linear

    func animation(duration: TimeInterval) -> Animation {
        switch self {
        case .linear: return .linear(duration: duration)
        case .ease, .easeinout, .easeinoutback, .easeinoutcubic, .easeinoutcubicemphasized,
             .easeinoutcirc, .easeinoutexpo, .easeinoutquad, .easeinoutquart,
             .easeinoutquint, .easeinoutsine, .fastoutslowin, .slowmiddle:
            return .easeInOut(duration: duration)
        case .easein, .easeinback, .easeincirc, .easeincubic, .easeinexpo,
             .easeinquad, .easeinquart, .easeinquint, .easeinsine, .easeintolinear,
             .decelerate:
            return .easeIn(duration: duration)
        case .easeout, .easeoutback, .easeoutcirc, .easeoutcubic, .easeoutexpo,
             .easeoutquad, .easeoutquart, .easeoutquint, .easeoutsine,
             .fastlineartosloweasein, .lineartoeaseout:
            return .easeOut(duration: duration)
        case .bouncein, .bounceinout, .bounceout:
            return .spring(duration: duration, bounce: 0.55)
        case .elasticin, .elasticinout, .elasticout:
            return .spring(duration: duration, bounce: 0.8)
        }
    }
}

public func parseCurve(_ value: String?, _ defaultValue: RufletCurve? = nil) -> RufletCurve? {
    parseEnum(RufletCurve.self, value, defaultValue)
}

public func parseAnimation(
    _ value: Any?,
    _ defaultValue: ImplicitAnimationDetails? = nil
) -> ImplicitAnimationDetails? {
    guard let value else { return defaultValue }
    if let enabled = parseBool(value), enabled, value is Bool {
        return ImplicitAnimationDetails(duration: 1, curve: .linear)
    }
    if rufletDictionary(value) == nil, let duration = parseDuration(value, 0) {
        return ImplicitAnimationDetails(duration: duration, curve: .linear)
    }
    guard let value = rufletDictionary(value) else { return defaultValue }
    return ImplicitAnimationDetails(
        duration: parseDuration(value["duration"], 0)!,
        curve: parseCurve(value["curve"] as? String, .linear)!
    )
}
