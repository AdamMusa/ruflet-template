import Foundation
import RufletProtocol

/// One control in the tree, as the engine holds it.
///
/// Nested controls are *not* stored inline: while materializing a patch the
/// store replaces every nested control map with a `.controlRef(id)`, so a
/// parent's props hold ids and the tree is reachable only through
/// `ControlStore`. That keeps patch-by-id O(1) and lets a control keep its
/// identity — and therefore its SwiftUI state — across a full re-send.
public struct ControlNode: Equatable {
  /// Wire id (`_i`). Unique within a session.
  public let id: Int
  /// Wire type name (`_c`), e.g. `"Text"`, `"ElevatedButton"`.
  public var type: String
  /// Every property except `_c`, `_i` and `_internals`.
  public var props: [String: RufletValue]
  /// Renderer hints the Ruby side attaches under `_internals`.
  public var internals: [String: RufletValue]

  public init(
    id: Int,
    type: String,
    props: [String: RufletValue] = [:],
    internals: [String: RufletValue] = [:]
  ) {
    self.id = id
    self.type = type
    self.props = props
    self.internals = internals
  }

  // MARK: - Children

  /// Ids of the controls under `controls`, in order.
  public var childIDs: [Int] {
    controlIDs(forKey: RufletControlKey.children)
  }

  /// Ids of the controls held by `key`, whether it holds one control or a list.
  public func controlIDs(forKey key: String) -> [Int] {
    guard let value = props[key] else { return [] }
    switch value {
    case .controlRef(let id):
      return [id]
    case .array(let items):
      return items.compactMap(\.controlID)
    default:
      return value.controlID.map { [$0] } ?? []
    }
  }

  /// The single control held by `key`, for slot props such as a button's
  /// `content` or a view's `appbar`.
  public func controlID(forKey key: String) -> Int? {
    controlIDs(forKey: key).first
  }

  // MARK: - Property access

  public subscript(key: String) -> RufletValue? {
    props[key]
  }

  /// Reads an explicit wire value first, then the generated default used by
  /// the pinned Flet Dart renderer for this exact control type. This mirrors
  /// `control.getBool/getDouble/getString(..., default)` without duplicating
  /// fallback literals throughout RufletUI.
  public func value(_ key: String) -> RufletValue? {
    if let explicit = props[key], !explicit.isNull { return explicit }
    return RufletControlDefaults.value(for: type, property: key)
  }

  public func string(_ key: String) -> String? { value(key)?.stringValue }
  public func bool(_ key: String) -> Bool? { value(key)?.boolValue }
  public func int(_ key: String) -> Int? { value(key)?.intValue }
  public func double(_ key: String) -> Double? { value(key)?.doubleValue }
  public func map(_ key: String) -> [String: RufletValue]? { props[key]?.mapValue }
  public func array(_ key: String) -> [RufletValue]? { props[key]?.arrayValue }

  /// Reads a property whose absence is defined by the generated Flet
  /// contract. Foundational layout controls use these accessors so a lost
  /// upstream default fails at generation/test time instead of being replaced
  /// by a view-local literal.
  public func rufletString(_ key: String) -> String {
    guard let result = string(key) else { return missingFletDefault(key, expected: "String") }
    return result
  }

  public func rufletBool(_ key: String) -> Bool {
    guard let result = bool(key) else { return missingFletDefault(key, expected: "Bool") }
    return result
  }

  public func fletDouble(_ key: String) -> Double {
    guard let result = double(key) else { return missingFletDefault(key, expected: "Double") }
    return result
  }

  private func missingFletDefault<T>(_ key: String, expected: String) -> T {
    preconditionFailure("Flet contract has no \(expected) default for \(type).\(key)")
  }

  /// Whether Ruby attached a handler for `name`.
  ///
  /// `Ruflet::Control#extract_handlers` replaces the block with `true` under
  /// `on_<name>`, so this is the only signal the renderer gets — and the only
  /// one it needs, since reporting an event nobody listens to is just wasted
  /// traffic.
  public func handlesEvent(_ name: String) -> Bool {
    props["on_\(name)"]?.boolValue ?? false
  }

  /// Returns the event name Ruby actually registered for a canonical Flet
  /// event. Ruflet historically exposed a few past-tense aliases; choosing the
  /// attached spelling here keeps that compatibility out of every renderer.
  public func handledEventName(_ canonicalName: String) -> String? {
    if handlesEvent(canonicalName) { return canonicalName }
    for alias in Self.eventAliases[canonicalName] ?? [] where handlesEvent(alias) {
      return alias
    }
    return nil
  }

  private static let eventAliases: [String: [String]] = [
    "complete": ["completed"],
    "track_change": ["track_changed"]
  ]

  /// True when the Ruby side asked the host to wrap expanding children, which
  /// `Ruflet::Control#to_patch` sets on `view`, `row` and `column`.
  public var hostExpanded: Bool {
    internals["host_expanded"]?.boolValue ?? false
  }

  /// Set on `stack`, whose children position themselves.
  public var hostPositioned: Bool {
    internals["host_positioned"]?.boolValue ?? false
  }
}
