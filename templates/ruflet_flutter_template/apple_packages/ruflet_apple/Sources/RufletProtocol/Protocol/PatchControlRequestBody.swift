public struct RufletPatchControlRequestBody: Equatable, Sendable {
  public let id: Int
  public let patch: [RufletValue]

  public init(value: RufletValue) throws {
    guard let map = value.map else { throw RufletProtocolError.invalidMessage }
    guard let id = map["id"]?.integer else { throw RufletProtocolError.missingField("id") }
    guard let patch = map["patch"]?.array else {
      throw RufletProtocolError.missingField("patch")
    }
    self.id = id
    self.patch = patch
  }
}
