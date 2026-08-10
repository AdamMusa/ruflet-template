import Foundation

/// A decoded `patch_control` message.
///
/// The payload shape produced by `Ruflet::Page` is
///
/// ```ruby
/// { "id" => wire_id, "patch" => [[0], [0, 0, key, value], ...] }
/// ```
///
/// The first element is the patch's path header — Ruflet always addresses the
/// control named by `id` directly, so it is always the single-element `[0]`.
/// Each following element is an operation whose leading `0` is the opcode
/// ("set property") and whose second slot is a reserved index that Ruflet
/// always emits as `0`.
public struct ControlPatch: Equatable {
  public enum Operation: Equatable {
    /// Set `key` on the target control to `value`. The only operation
    /// `Ruflet::Page` emits.
    case set(key: String, value: RufletValue)
    /// Anything else. Kept rather than dropped so a host can log the shape of
    /// a message from a newer runtime instead of silently mis-rendering.
    case unsupported(RufletValue)
  }

  public let controlID: Int
  public let operations: [Operation]

  public init(controlID: Int, operations: [Operation]) {
    self.controlID = controlID
    self.operations = operations
  }

  public enum DecodingError: Error, Equatable {
    case missingControlID
  }

  public static func decode(payload: RufletValue) throws -> ControlPatch {
    guard let controlID = payload["id"]?.intValue else {
      throw DecodingError.missingControlID
    }
    let raw = payload["patch"]?.arrayValue ?? []
    var operations: [Operation] = []
    operations.reserveCapacity(raw.count)

    for (index, element) in raw.enumerated() {
      // Skip the leading path header.
      if index == 0, let path = element.arrayValue, path.allSatisfy({ $0.intValue != nil }) {
        continue
      }
      operations.append(decodeOperation(element))
    }
    return ControlPatch(controlID: controlID, operations: operations)
  }

  private static func decodeOperation(_ element: RufletValue) -> Operation {
    guard
      let parts = element.arrayValue,
      parts.count >= 4,
      parts[0].intValue == 0,
      let key = parts[2].stringValue
    else {
      return .unsupported(element)
    }
    return .set(key: key, value: parts[3])
  }
}

/// The reserved wire ids `Ruflet::Page` hands out before any control gets one.
public enum RufletWireID {
  public static let page = 1
  public static let window = 2
  public static let view = 20
  /// `Page#initialize` starts application controls here.
  public static let firstControl = 100
}

/// Well-known keys inside a serialized control.
public enum RufletControlKey {
  /// Wire type name, e.g. `"Text"`.
  public static let type = "_c"
  /// Wire id.
  public static let id = "_i"
  /// Renderer hints such as `host_expanded` and `host_positioned`.
  public static let internals = "_internals"
  /// Ordered children.
  public static let children = "controls"
}
