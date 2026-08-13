import Foundation
import RufletProtocol

func rufletSleepNanoseconds(_ seconds: TimeInterval) -> UInt64 {
    UInt64(max(seconds, 0) * 1_000_000_000)
}

struct RufletTimeOfDay: Equatable, Sendable {
    let hour: Int
    let minute: Int
}

func parseRufletDate(_ value: RufletValue?, _ defaultValue: Date? = nil) -> Date? {
    guard let value else { return defaultValue }
    let text: String?
    switch value {
    case .extensionValue(let type, let payload) where type == 1:
        text = String(data: payload, encoding: .utf8)
    case .string(let value):
        text = value
    default:
        text = nil
    }
    guard let text else { return defaultValue }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: text) { return date }
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: text) ?? defaultValue
}

func parseRufletTime(_ value: RufletValue?, _ defaultValue: RufletTimeOfDay? = nil) -> RufletTimeOfDay? {
    guard let value else { return defaultValue }
    let text: String?
    switch value {
    case .extensionValue(let type, let payload) where type == 2:
        text = String(data: payload, encoding: .utf8)
    case .string(let value):
        text = value
    default:
        text = nil
    }
    guard let parts = text?.split(separator: ":"), parts.count == 2,
          let hour = Int(parts[0]), let minute = Int(parts[1]),
          (0..<24).contains(hour), (0..<60).contains(minute)
    else { return defaultValue }
    return RufletTimeOfDay(hour: hour, minute: minute)
}

func parseRufletWireDuration(
    _ value: RufletValue?,
    _ defaultValue: TimeInterval? = nil,
    numberUnit: DurationUnit = .milliseconds
) -> TimeInterval? {
    guard let value else { return defaultValue }
    if case .extensionValue(let type, let payload) = value, type == 3,
       let text = String(data: payload, encoding: .utf8), let microseconds = Double(text) {
        return microseconds / 1_000_000
    }
    return parseDuration(rufletAny(value), defaultValue, numberUnit)
}

func rufletDateValue(_ date: Date) -> RufletValue {
    RufletMessagePack.temporalDate(date)
}

func rufletTimeValue(_ time: RufletTimeOfDay) -> RufletValue {
    RufletMessagePack.temporalTime(hour: time.hour, minute: time.minute)
}

func rufletDurationValue(_ seconds: TimeInterval) -> RufletValue {
    RufletMessagePack.temporalDuration(microseconds: Int64((seconds * 1_000_000).rounded()))
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
