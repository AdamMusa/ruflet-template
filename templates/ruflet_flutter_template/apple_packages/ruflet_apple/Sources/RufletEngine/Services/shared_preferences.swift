import Foundation
import RufletProtocol

@MainActor
public final class SharedPreferencesService: RufletInvokableService {
  private let defaults = UserDefaults.standard

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "set":
      guard let key = arguments["key"]?.text else { throw RufletServiceError.missingArgument("key") }
      guard let value = arguments["value"] else { throw RufletServiceError.missingArgument("value") }
      defaults.set(try propertyListValue(value), forKey: key)
      return .bool(defaults.synchronize())
    case "get":
      guard let key = arguments["key"]?.text else { throw RufletServiceError.missingArgument("key") }
      return defaults.object(forKey: key).flatMap(rufletPreferenceValue) ?? .null
    case "contains_key":
      guard let key = arguments["key"]?.text else { throw RufletServiceError.missingArgument("key") }
      return .bool(defaults.object(forKey: key) != nil)
    case "get_keys":
      guard let prefix = arguments["key_prefix"]?.text else {
        throw RufletServiceError.missingArgument("key_prefix")
      }
      let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.sorted()
      return .array(keys.map(RufletValue.string))
    case "remove":
      guard let key = arguments["key"]?.text else { throw RufletServiceError.missingArgument("key") }
      defaults.removeObject(forKey: key)
      return .bool(defaults.synchronize())
    case "clear":
      let bundleID = Bundle.main.bundleIdentifier
      if let bundleID { defaults.removePersistentDomain(forName: bundleID) }
      return .bool(defaults.synchronize())
    default: throw RufletServiceError.unknownMethod(service: "SharedPreferences", method: name)
    }
  }

  private func propertyListValue(_ value: RufletValue) throws -> Any {
    switch value {
    case .string(let value): return value
    case .bool(let value): return value
    case .int(let value): return value
    case .double(let value): return value
    case .array(let values) where values.allSatisfy({ $0.text != nil }): return values.compactMap(\.text)
    default: throw RufletServiceError.unsupportedValue("SharedPreferences value")
    }
  }
}

private func rufletPreferenceValue(_ value: Any) -> RufletValue? {
  switch value {
  case let value as String: return .string(value)
  case let value as Bool: return .bool(value)
  case let value as Int: return .int(Int64(value))
  case let value as Int64: return .int(value)
  case let value as Double: return .double(value)
  case let value as [String]: return .array(value.map(RufletValue.string))
  case let value as NSNumber:
    return CFGetTypeID(value) == CFBooleanGetTypeID() ? .bool(value.boolValue) : .double(value.doubleValue)
  default: return nil
  }
}

