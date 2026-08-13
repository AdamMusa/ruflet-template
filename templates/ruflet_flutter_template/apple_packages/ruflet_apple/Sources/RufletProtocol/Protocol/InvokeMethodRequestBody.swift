import Foundation

public struct RufletInvokeMethodRequestBody: Equatable, Sendable {
  public let controlID: Int
  public let callID: String
  public let name: String
  public let arguments: RufletValue
  public let timeout: Duration

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
    let timeoutSeconds = map["timeout"]?.integer ?? 10
    self.controlID = controlID
    self.callID = callID
    self.name = name
    self.arguments = map["args"] ?? .null
    self.timeout = .seconds(timeoutSeconds)
  }
}
