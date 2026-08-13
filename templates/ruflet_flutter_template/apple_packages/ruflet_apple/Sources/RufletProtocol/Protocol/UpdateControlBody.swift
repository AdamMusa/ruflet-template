public struct RufletUpdateControlBody: Equatable, Sendable {
  public let id: Int
  public let properties: [String: RufletValue]

  public init(id: Int, properties: [String: RufletValue]) {
    self.id = id
    self.properties = properties
  }

  public var value: RufletValue {
    ["id": .int(Int64(id)), "props": .map(properties)]
  }
}
