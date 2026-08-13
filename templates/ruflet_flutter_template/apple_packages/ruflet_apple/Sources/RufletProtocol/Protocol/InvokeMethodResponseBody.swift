public struct RufletInvokeMethodResponseBody: Equatable, Sendable {
  public let controlID: Int
  public let callID: String
  public let result: RufletValue
  public let error: String?

  public init(controlID: Int, callID: String, result: RufletValue, error: String? = nil) {
    self.controlID = controlID
    self.callID = callID
    self.result = result
    self.error = error
  }

  public var value: RufletValue {
    .map([
      "control_id": .int(Int64(controlID)),
      "call_id": .string(callID),
      "result": result,
      "error": error.map(RufletValue.string) ?? .null,
    ])
  }
}
