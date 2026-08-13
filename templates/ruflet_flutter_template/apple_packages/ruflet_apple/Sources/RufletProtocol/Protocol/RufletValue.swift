import Foundation

/// A value in Flet's MessagePack protocol.
///
/// The cases intentionally match the wire type system. Renderer-specific
/// objects never enter this layer.
public enum RufletValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case int(Int64)
  case double(Double)
  case string(String)
  case binary(Data)
  case array([RufletValue])
  case map([String: RufletValue])
  case extensionValue(type: Int8, payload: Data)

  public var isNull: Bool {
    if case .null = self { return true }
    return false
  }

  public var bool: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }

  public var integer: Int? {
    guard case .int(let value) = self, let result = Int(exactly: value) else { return nil }
    return result
  }

  public var number: Double? {
    switch self {
    case .double(let value): return value
    case .int(let value): return Double(value)
    default: return nil
    }
  }

  public var text: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  public var array: [RufletValue]? {
    guard case .array(let value) = self else { return nil }
    return value
  }

  public var map: [String: RufletValue]? {
    guard case .map(let value) = self else { return nil }
    return value
  }

  public subscript(_ key: String) -> RufletValue? { map?[key] }
}

extension RufletValue: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) { self = .null }
}

extension RufletValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension RufletValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int64) { self = .int(value) }
}

extension RufletValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) { self = .double(value) }
}

extension RufletValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self = .string(value) }
}

extension RufletValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: RufletValue...) { self = .array(elements) }
}

extension RufletValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, RufletValue)...) {
    self = .map(Dictionary(uniqueKeysWithValues: elements))
  }
}
