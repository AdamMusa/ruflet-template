import Foundation

func rufletSleepNanoseconds(_ seconds: TimeInterval) -> UInt64 {
    UInt64(max(seconds, 0) * 1_000_000_000)
}

enum DurationUnit: String, CaseIterable, RufletStringEnum {
    case microseconds, milliseconds, seconds, minutes, hours, days
}

func parseDuration(
    _ value: Any?,
    _ defaultValue: TimeInterval? = nil,
    _ treatNumberAs: DurationUnit = .milliseconds
) -> TimeInterval? {
    guard let value else { return defaultValue }
    if rufletDictionary(value) == nil, let amount = parseDouble(value) {
        switch treatNumberAs {
        case .microseconds: return amount / 1_000_000
        case .milliseconds: return amount / 1_000
        case .seconds: return amount
        case .minutes: return amount * 60
        case .hours: return amount * 3_600
        case .days: return amount * 86_400
        }
    }
    guard let value = rufletDictionary(value) else { return defaultValue }
    return parseDouble(value["days"], 0)! * 86_400
        + parseDouble(value["hours"], 0)! * 3_600
        + parseDouble(value["minutes"], 0)! * 60
        + parseDouble(value["seconds"], 0)!
        + parseDouble(value["milliseconds"], 0)! / 1_000
        + parseDouble(value["microseconds"], 0)! / 1_000_000
}
