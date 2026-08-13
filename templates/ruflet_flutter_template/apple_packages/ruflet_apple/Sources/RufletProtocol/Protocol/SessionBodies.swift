public struct RufletSessionCrashedBody: Equatable, Sendable {
  public let message: String

  public init(value: RufletValue) throws {
    guard let message = value["message"]?.text else {
      throw RufletProtocolError.missingField("message")
    }
    self.message = message
  }
}

public struct RufletSessionPayload: Equatable, Sendable {
  public let id: String
  public init(id: String) { self.id = id }
}
