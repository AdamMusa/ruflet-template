import Foundation
import RufletProtocol

func parseDouble(_ value: Any?, _ defaultValue: Double? = nil) -> Double? {
    switch value {
    case let value as RufletValue:
        return value.number ?? value.text.flatMap(Double.init) ?? defaultValue
    case let value as Double:
        return value
    case let value as Float:
        return Double(value)
    case let value as Int:
        return Double(value)
    case let value as Int8:
        return Double(value)
    case let value as Int16:
        return Double(value)
    case let value as Int32:
        return Double(value)
    case let value as Int64:
        return Double(value)
    case let value as UInt:
        return Double(value)
    case let value as UInt8:
        return Double(value)
    case let value as UInt16:
        return Double(value)
    case let value as UInt32:
        return Double(value)
    case let value as UInt64:
        return Double(value)
    case let value as NSNumber:
        return value.doubleValue
    case let value as String where value.lowercased() == "inf":
        return .infinity
    case let value as String:
        return Double(value) ?? defaultValue
    case .none:
        return defaultValue
    case let value?:
        return Double(String(describing: value)) ?? defaultValue
    }
}

func parseInt(_ value: Any?, _ defaultValue: Int? = nil) -> Int? {
    switch value {
    case let value as RufletValue:
        return value.integer ?? value.text.flatMap(Int.init) ?? defaultValue
    case let value as Int:
        return value
    case let value as NSNumber:
        return value.intValue
    case let value as String:
        return Int(value) ?? defaultValue
    case .none:
        return defaultValue
    case let value?:
        return Int(String(describing: value)) ?? defaultValue
    }
}

func parseBool(_ value: Any?, _ defaultValue: Bool? = nil) -> Bool? {
    switch value {
    case let value as RufletValue:
        return value.bool ?? value.text.map { $0.lowercased() == "true" } ?? defaultValue
    case let value as Bool:
        return value
    case .none:
        return defaultValue
    case let value?:
        return String(describing: value).lowercased() == "true"
    }
}
