import RufletProtocol

func fnv1aHash(_ bytes: [UInt8]) -> UInt32 {
    let fnvOffset: UInt32 = 0x811c9dc5
    let fnvPrime: UInt32 = 0x01000193
    return bytes.reduce(fnvOffset) { hash, byte in
        (hash ^ UInt32(byte)) &* fnvPrime
    }
}

/// Stable recursive identity used where Flutter accepts any wire value as a key/tag.
func rufletStableValueDescription(_ value: RufletValue) -> String {
    switch value {
    case .null: return "null"
    case let .bool(value): return value ? "true" : "false"
    case let .int(value): return "i:\(value)"
    case let .double(value): return "d:\(value.bitPattern)"
    case let .string(value): return "s:\(value.count):\(value)"
    case let .binary(value): return "b:\(value.base64EncodedString())"
    case let .array(value):
        return "[\(value.map(rufletStableValueDescription).joined(separator: ","))]"
    case let .map(value):
        let entries = value.keys.sorted().map { key in
            "\(key.count):\(key)=\(rufletStableValueDescription(value[key]!))"
        }
        return "{\(entries.joined(separator: ","))}"
    case let .extensionValue(type, payload):
        return "x:\(type):\(payload.base64EncodedString())"
    }
}
