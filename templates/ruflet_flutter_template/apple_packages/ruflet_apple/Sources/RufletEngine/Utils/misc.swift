import Foundation
import RufletProtocol

func rufletDictionary(_ value: Any?) -> [String: Any]? {
    if let value = value as? RufletValue, let map = value.map {
        return map.mapValues(rufletAny)
    }
    if let value = value as? [String: Any] {
        return value
    }
    if let value = value as? [AnyHashable: Any] {
        return Dictionary(uniqueKeysWithValues: value.map { (String(describing: $0.key), $0.value) })
    }
    return nil
}

func rufletArray(_ value: Any?) -> [Any]? {
    if let value = value as? RufletValue, let array = value.array {
        return array.map(rufletAny)
    }
    return value as? [Any]
}

func rufletAny(_ value: RufletValue) -> Any {
    switch value {
    case .null: return NSNull()
    case let .bool(value): return value
    case let .int(value): return value
    case let .double(value): return value
    case let .string(value): return value
    case let .binary(value): return value
    case let .array(value): return value.map(rufletAny)
    case let .map(value): return value.mapValues(rufletAny)
    case let .extensionValue(type, payload):
        return ["type": type, "payload": payload]
    }
}

@MainActor
extension RufletControl {
    func dynamicValue(_ name: String) -> Any? {
        value(name).map(rufletAny)
    }

    func skipsProperty(_ name: String) -> Bool {
        internals?["skip_properties"]?.array?.contains(.string(name)) == true
    }
}
