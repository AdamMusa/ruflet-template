import Foundation

/// A decoded Ruflet wire value.
///
/// The Ruby side speaks MessagePack with three extension types reserved for
/// temporal values (see `Ruflet::WireCodec`), so this mirrors the MessagePack
/// type system rather than Swift's `Codable` graph — control props are an open
/// map whose value types are only known to the control that reads them.
public enum RufletValue: Equatable {
  case null
  case bool(Bool)
  case int(Int64)
  case double(Double)
  case string(String)
  case binary([UInt8])
  case array([RufletValue])
  case map([String: RufletValue])

  /// MessagePack extension payloads. Ruflet uses type 1 for DateTime, 2 for
  /// TimeOfDay and 3 for Duration; the payload is always a UTF-8 string.
  case extended(type: Int8, string: String)

  /// A reference to another control in the `ControlStore`.
  ///
  /// Never appears on the wire: the engine substitutes it for nested control
  /// maps while materializing a patch, so a parent's props hold ids rather
  /// than copies of their children. Encoding one emits the bare id.
  case controlRef(Int)
}

// MARK: - Accessors

extension RufletValue {
  public var isNull: Bool {
    if case .null = self { return true }
    return false
  }

  public var stringValue: String? {
    switch self {
    case .string(let value): return value
    case .extended(_, let value): return value
    case .int(let value): return String(value)
    case .double(let value): return String(value)
    case .bool(let value): return String(value)
    default: return nil
    }
  }

  public var boolValue: Bool? {
    switch self {
    case .bool(let value): return value
    case .int(let value): return value != 0
    case .double(let value): return value != 0
    case .string(let value):
      switch value.lowercased() {
      case "true", "1", "yes": return true
      case "false", "0", "no": return false
      default: return nil
      }
    default: return nil
    }
  }

  public var intValue: Int? {
    switch self {
    case .int(let value): return Int(value)
    case .double(let value): return Int(value)
    case .bool(let value): return value ? 1 : 0
    case .string(let value): return Int(value)
    case .controlRef(let id): return id
    default: return nil
    }
  }

  public var doubleValue: Double? {
    switch self {
    case .double(let value): return value
    case .int(let value): return Double(value)
    case .string(let value): return Double(value)
    default: return nil
    }
  }

  public var arrayValue: [RufletValue]? {
    if case .array(let items) = self { return items }
    return nil
  }

  public var mapValue: [String: RufletValue]? {
    if case .map(let entries) = self { return entries }
    return nil
  }

  /// The control id this value points at, whether it is still an unmaterialized
  /// control map (`_i`) or an already-registered reference.
  public var controlID: Int? {
    switch self {
    case .controlRef(let id): return id
    case .map(let entries): return entries["_i"]?.intValue
    default: return nil
    }
  }

  public subscript(key: String) -> RufletValue? {
    mapValue?[key]
  }
}

// MARK: - Convenience construction

extension RufletValue {
  public init(_ value: Bool) { self = .bool(value) }
  public init(_ value: Int) { self = .int(Int64(value)) }
  public init(_ value: Double) { self = .double(value) }
  public init(_ value: String) { self = .string(value) }
  public init(_ value: [RufletValue]) { self = .array(value) }
  public init(_ value: [String: RufletValue]) { self = .map(value) }

  /// Wraps an optional, mapping `nil` onto the wire's explicit null.
  public init(optional value: RufletValue?) {
    self = value ?? .null
  }
}

extension RufletValue: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) { self = .null }
}

extension RufletValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension RufletValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) { self = .int(Int64(value)) }
}

extension RufletValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) { self = .double(value) }
}

extension RufletValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self = .string(value) }
}

extension RufletValue: CustomStringConvertible {
  public var description: String {
    switch self {
    case .null: return "null"
    case .bool(let value): return String(value)
    case .int(let value): return String(value)
    case .double(let value): return String(value)
    case .string(let value): return "\"\(value)\""
    case .binary(let bytes): return "<\(bytes.count) bytes>"
    case .array(let items): return "[" + items.map(\.description).joined(separator: ", ") + "]"
    case .map(let entries):
      let body = entries.keys.sorted()
        .map { "\($0): \(entries[$0]!.description)" }
        .joined(separator: ", ")
      return "{" + body + "}"
    case .extended(let type, let value): return "ext(\(type), \"\(value)\")"
    case .controlRef(let id): return "control(\(id))"
    }
  }
}
