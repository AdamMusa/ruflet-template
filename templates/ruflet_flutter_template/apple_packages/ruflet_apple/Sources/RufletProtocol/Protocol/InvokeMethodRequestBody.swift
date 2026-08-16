import Foundation

public struct RufletInvokeMethodRequestBody: Equatable, Sendable {
  public let controlID: Int
  public let callID: String
  public let name: String
  public let arguments: RufletValue
  /// Pinned Flet wire timeout in seconds.
  ///
  /// `Duration` and `Task.sleep(for:)` require iOS 16. Keeping the protocol
  /// value as `TimeInterval` preserves the exact integer-seconds wire contract
  /// while allowing the Apple engine to remain deployable on iOS 15.
  public let timeoutSeconds: TimeInterval

  public var timeoutNanoseconds: UInt64 {
    guard timeoutSeconds > 0 else { return 0 }
    let value = timeoutSeconds * 1_000_000_000
    return value >= Double(UInt64.max) ? UInt64.max : UInt64(value)
  }

  public init(value: RufletValue) throws {
    guard let map = value.map else { throw RufletProtocolError.invalidMessage }
    guard let controlID = map["control_id"]?.integer else {
      throw RufletProtocolError.missingField("control_id")
    }
    guard let callID = map["call_id"]?.text else {
      throw RufletProtocolError.missingField("call_id")
    }
    guard let name = map["name"]?.text else {
      throw RufletProtocolError.missingField("name")
    }
    let timeoutSeconds: Int
    if let timeout = map["timeout"] {
      guard let integer = timeout.integer else {
        throw RufletProtocolError.invalidField("timeout")
      }
      timeoutSeconds = integer
    } else {
      timeoutSeconds = 10
    }
    self.controlID = controlID
    self.callID = callID
    self.name = name
    self.arguments = map["args"] ?? .null
    self.timeoutSeconds = TimeInterval(timeoutSeconds)
  }
}
