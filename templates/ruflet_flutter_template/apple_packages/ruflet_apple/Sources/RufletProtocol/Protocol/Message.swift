import Foundation

/// Exact action numbers from `flet/lib/src/protocol/message.dart`.
public enum RufletMessageAction: Int, Equatable, Sendable {
  case registerClient = 1
  case patchControl = 2
  case controlEvent = 3
  case updateControl = 4
  case invokeControlMethod = 5
  case sessionCrashed = 6
}

public struct RufletMessage: Equatable, Sendable {
  public let action: RufletMessageAction
  public let payload: RufletValue

  public init(action: RufletMessageAction, payload: RufletValue) {
    self.action = action
    self.payload = payload
  }

  public init(list: [RufletValue]) throws {
    // Pinned Flet reads indexes 0 and 1 and ignores trailing list elements.
    // Require the same minimum shape rather than a stricter Swift-only frame.
    guard list.count >= 2,
          let rawAction = list[0].integer,
          let action = RufletMessageAction(rawValue: rawAction)
    else { throw RufletProtocolError.invalidMessage }
    self.init(action: action, payload: list[1])
  }

  public var list: [RufletValue] { [.int(Int64(action.rawValue)), payload] }
}

public enum RufletProtocolError: Error, Equatable {
  case invalidMessage
  case missingField(String)
  case invalidField(String)
  case unsupportedMessagePackMarker(UInt8)
  case truncatedMessagePack
  case invalidUTF8
}
