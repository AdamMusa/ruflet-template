import RufletProtocol

public struct RufletMultiView: Equatable, Sendable {
  public let viewID: Int
  public let initialData: [String: RufletValue]

  public init(viewID: Int, initialData: [String: RufletValue]) {
    self.viewID = viewID
    self.initialData = initialData
  }

  public var value: RufletValue {
    ["view_id": .int(Int64(viewID)), "initial_data": .map(initialData)]
  }
}
