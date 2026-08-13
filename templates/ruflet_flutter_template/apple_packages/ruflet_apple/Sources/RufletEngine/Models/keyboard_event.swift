import RufletProtocol

public struct RufletKeyboardEvent: Equatable, Sendable {
  public let key: String
  public let isShiftPressed: Bool
  public let isControlPressed: Bool
  public let isAltPressed: Bool
  public let isMetaPressed: Bool

  public var value: RufletValue {
    [
      "key": .string(key),
      "shift": .bool(isShiftPressed),
      "ctrl": .bool(isControlPressed),
      "alt": .bool(isAltPressed),
      "meta": .bool(isMetaPressed),
    ]
  }
}
