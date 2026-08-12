import Foundation

/// A decoded Flet `patch_control` message.
///
/// Flet patches are not limited to setting properties on the addressed
/// control. The first patch element is a compact tree index which maps integer
/// target ids to paths below that control. The remaining elements replace,
/// add, remove, or move values in the indexed maps/lists.
public struct ControlPatch: Equatable {
  public enum Operation: Equatable {
    /// Ruflet's in-process convenience operation. Unlike Flet's wire-level
    /// replace operation, map-valued properties merge recursively. Keeping it
    /// distinct preserves `Control.update()` semantics for local services.
    case set(key: String, value: RufletValue)

    case replace(target: Int, key: RufletValue, value: RufletValue)
    case add(target: Int, key: RufletValue, value: RufletValue)
    case remove(target: Int, key: RufletValue)
    case move(fromTarget: Int, fromKey: RufletValue, toTarget: Int, toKey: RufletValue)

    /// Kept for source compatibility with callers that construct a patch by
    /// hand. The store rejects the entire patch atomically.
    case unsupported(RufletValue)
  }

  public let controlID: Int

  /// Target id -> path components relative to the addressed control's
  /// properties. MessagePack map keys are normalized to strings by
  /// `MessagePack`; list traversal interprets numeric strings as indices.
  public let pathIndex: [Int: [String]]
  public let operations: [Operation]

  public init(
    controlID: Int,
    pathIndex: [Int: [String]] = [0: []],
    operations: [Operation]
  ) {
    self.controlID = controlID
    self.pathIndex = pathIndex
    self.operations = operations
  }

  public enum DecodingError: Error, Equatable {
    case missingControlID
    case malformedTreeIndex
    case malformedOperation(Int)
    case unknownOperation(Int)
  }

  public static func decode(payload: RufletValue) throws -> ControlPatch {
    guard let controlID = payload["id"]?.intValue else {
      throw DecodingError.missingControlID
    }

    let raw = payload["patch"]?.arrayValue ?? []
    guard let tree = raw.first else {
      // An absent operation list is a valid no-op for a reconnecting client.
      return ControlPatch(controlID: controlID, operations: [])
    }

    var pathIndex: [Int: [String]] = [:]
    try buildPathIndex(tree, path: [], result: &pathIndex)

    var operations: [Operation] = []
    operations.reserveCapacity(max(0, raw.count - 1))
    for (offset, element) in raw.dropFirst().enumerated() {
      operations.append(try decodeOperation(element, index: offset + 1))
    }
    return ControlPatch(controlID: controlID, pathIndex: pathIndex, operations: operations)
  }

  private static func buildPathIndex(
    _ value: RufletValue,
    path: [String],
    result: inout [Int: [String]]
  ) throws {
    guard
      let node = value.arrayValue,
      let target = node.first?.intValue,
      node.count <= 2
    else {
      throw DecodingError.malformedTreeIndex
    }

    result[target] = path
    guard node.count == 2 else { return }
    guard let children = node[1].mapValue else {
      throw DecodingError.malformedTreeIndex
    }
    for (component, child) in children {
      try buildPathIndex(child, path: path + [component], result: &result)
    }
  }

  private static func decodeOperation(_ element: RufletValue, index: Int) throws -> Operation {
    guard
      let parts = element.arrayValue,
      let opcode = parts.first?.intValue
    else {
      throw DecodingError.malformedOperation(index)
    }

    switch opcode {
    case 0, 1:
      guard parts.count == 4, let target = parts[1].intValue else {
        throw DecodingError.malformedOperation(index)
      }
      return opcode == 0
        ? .replace(target: target, key: parts[2], value: parts[3])
        : .add(target: target, key: parts[2], value: parts[3])

    case 2:
      guard parts.count == 3, let target = parts[1].intValue else {
        throw DecodingError.malformedOperation(index)
      }
      return .remove(target: target, key: parts[2])

    case 3:
      guard
        parts.count == 5,
        let fromTarget = parts[1].intValue,
        let toTarget = parts[3].intValue
      else {
        throw DecodingError.malformedOperation(index)
      }
      return .move(
        fromTarget: fromTarget,
        fromKey: parts[2],
        toTarget: toTarget,
        toKey: parts[4])

    default:
      throw DecodingError.unknownOperation(opcode)
    }
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
