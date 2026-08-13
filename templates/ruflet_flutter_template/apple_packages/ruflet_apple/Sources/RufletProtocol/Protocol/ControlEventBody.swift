public struct RufletControlEventBody: Equatable, Sendable {
  public let target: Int
  public let name: String
  public let data: RufletValue

  public init(target: Int, name: String, data: RufletValue) {
    self.target = target
    self.name = name
    self.data = data
  }

  public var value: RufletValue {
    ["target": .int(Int64(target)), "name": .string(name), "data": data]
  }
}
