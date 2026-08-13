import Foundation
import RufletProtocol

enum ControlKeyValue: Hashable, Sendable, CustomStringConvertible {
    case integer(Int)
    case string(String)
    case boolean(Bool)
    case double(Double)

    var description: String {
        switch self {
        case let .integer(value): String(value)
        case let .string(value): value
        case let .boolean(value): String(value)
        case let .double(value): String(value)
        }
    }
}

enum ControlKey: Hashable, Sendable, CustomStringConvertible {
    case scroll(ControlKeyValue)
    case value(ControlKeyValue)

    var rawValue: ControlKeyValue {
        switch self {
        case let .scroll(value), let .value(value): value
        }
    }

    var description: String { rawValue.description }
}

func parseKey(_ value: Any?) -> ControlKey? {
    guard let value else { return nil }
    if let value = value as? RufletValue {
        if let dictionary = value.map {
            guard let rawValue = parseControlKeyValue(dictionary["value"]) else { return nil }
            switch dictionary["_type"]?.text {
            case "value": return .value(rawValue)
            case "scroll": return .scroll(rawValue)
            default: return nil
            }
        }
        return parseControlKeyValue(value).map(ControlKey.value)
    }
    if let dictionary = rufletDictionary(value) {
        guard let rawValue = parseControlKeyValue(dictionary["value"]) else { return nil }
        switch String(describing: dictionary["_type"] ?? "") {
        case "value": return .value(rawValue)
        case "scroll": return .scroll(rawValue)
        default: return nil
        }
    }
    return parseControlKeyValue(value).map(ControlKey.value)
}

private func parseControlKeyValue(_ value: Any?) -> ControlKeyValue? {
    switch value {
    case let value as RufletValue:
        switch value {
        case .bool(let value): return .boolean(value)
        case .int(let value): return Int(exactly: value).map(ControlKeyValue.integer)
        case .double(let value): return .double(value)
        case .string(let value): return .string(value)
        default: return nil
        }
    case let value as Bool: return .boolean(value)
    case let value as Int: return .integer(value)
    case let value as Double: return .double(value)
    case let value as Float: return .double(Double(value))
    case let value as String: return .string(value)
    case let value as NSNumber: return .double(value.doubleValue)
    default: return nil
    }
}
