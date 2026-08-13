import Foundation
import RufletProtocol

public enum RufletServiceError: Error, Equatable, Sendable {
  case unknownMethod(service: String, method: String)
  case missingArgument(String)
  case invalidArgument(String)
  case unsupportedValue(String)
  case unavailable(String)
}

@MainActor
open class RufletInvokableService: RufletService {
  private var invokeListener: UUID?

  open override func initialize() {
    invokeListener = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { throw RufletServiceError.unavailable("Service was disposed") }
      return try await self.invoke(name, arguments: arguments.map ?? [:]) ?? .null
    }
  }

  open func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    throw RufletServiceError.unknownMethod(service: control.type, method: name)
  }

  open override func dispose() {
    if let invokeListener {
      control.removeInvokeMethodListener(invokeListener)
      self.invokeListener = nil
    }
  }
}

extension RufletValue {
  var serviceData: Data? {
    switch self {
    case .binary(let data): return data
    case .array(let values):
      let bytes = values.compactMap { value -> UInt8? in
        guard let integer = value.integer, (0 ... 255).contains(integer) else { return nil }
        return UInt8(integer)
      }
      return bytes.count == values.count ? Data(bytes) : nil
    default: return nil
    }
  }
}

func serviceStringArray(_ value: RufletValue?) -> [String]? {
  guard let values = value?.array else { return nil }
  return values.map { $0.text ?? String(describing: $0) }
}

func serviceTimestamp(_ date: Date) -> RufletValue {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  let payload = Data(formatter.string(from: date).replacingOccurrences(of: "Z", with: "+00:00").utf8)
  return .extensionValue(type: 1, payload: payload)
}

