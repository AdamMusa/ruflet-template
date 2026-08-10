import Foundation

/// The action codes of the Ruflet wire protocol.
///
/// Mirrors `Ruflet::Protocol::ACTIONS`. Ruby always sends the integer form to
/// clients; the string aliases in that table exist only for legacy JSON
/// clients talking *to* Ruby, so they have no counterpart here.
public enum RufletAction: Int, Equatable {
  case registerClient = 1
  case patchControl = 2
  case controlEvent = 3
  case updateControl = 4
  case invokeControlMethod = 5
  case sessionCrashed = 6
  /// Named `python_output` on the wire for Flet compatibility; it carries
  /// whatever the runtime wrote to stdout.
  case runtimeOutput = 7
}

/// One frame: the wire is always a two-element array of `[action, payload]`.
public struct RufletMessage: Equatable {
  public let action: RufletAction
  public let payload: RufletValue

  public init(action: RufletAction, payload: RufletValue) {
    self.action = action
    self.payload = payload
  }

  public enum DecodingError: Error, Equatable {
    case notAFrame
    case unknownAction(Int)
  }

  public static func decode(_ data: Data) throws -> RufletMessage {
    try decode(value: MessagePack.decode(data))
  }

  public static func decode(value: RufletValue) throws -> RufletMessage {
    guard let frame = value.arrayValue, frame.count >= 2 else {
      throw DecodingError.notAFrame
    }
    guard let raw = frame[0].intValue else { throw DecodingError.notAFrame }
    guard let action = RufletAction(rawValue: raw) else {
      throw DecodingError.unknownAction(raw)
    }
    return RufletMessage(action: action, payload: frame[1])
  }

  public func encoded() -> Data {
    MessagePack.encodeData(.array([.int(Int64(action.rawValue)), payload]))
  }
}
