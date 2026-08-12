import Combine
import Foundation
import RufletProtocol

/// The engine's authoritative copy of the control tree.
///
/// Flat by design: `Ruflet::Page` addresses updates by wire id, never by path,
/// so a dictionary is both the natural shape and the fast one. The tree
/// structure lives in the `.controlRef` values inside each node's props.
public final class ControlStore: ObservableObject {
  /// Bumped after every applied message. Views read it so SwiftUI has a single
  /// coarse invalidation signal rather than one publisher per control.
  @Published public private(set) var revision: Int = 0

  public private(set) var nodes: [Int: ControlNode] = [:]

  /// Ids whose props changed in the most recently applied message. A renderer
  /// may use this to scope work; correctness never depends on it.
  public private(set) var lastChangedIDs: Set<Int> = []

  public init() {}

  // MARK: - Reading

  public func node(_ id: Int) -> ControlNode? { nodes[id] }

  public var page: ControlNode? { nodes[RufletWireID.page] }

  /// The view Ruflet is currently showing: the last entry of the page's
  /// `views`, matching Flet's navigator, which renders the top of the stack.
  public var activeViewID: Int? {
    page?.controlIDs(forKey: "views").last
  }

  /// Children of `id` resolved to nodes, skipping ids that are not registered
  /// (a patch can name a child that a later op removes).
  public func children(of id: Int, key: String = RufletControlKey.children) -> [ControlNode] {
    guard let node = nodes[id] else { return [] }
    return node.controlIDs(forKey: key).compactMap { nodes[$0] }
  }

  // MARK: - Writing

  /// Applies the `page_patch` from a `register_client` acknowledgement, which
  /// is a plain property map for the page control rather than an op list.
  @discardableResult
  public func applyPageProperties(_ properties: [String: RufletValue]) -> Bool {
    let previousNodes = nodes
    var touched: Set<Int> = [RufletWireID.page]
    var page = nodes[RufletWireID.page] ?? ControlNode(id: RufletWireID.page, type: "Page")
    for (key, value) in properties {
      page.props[key] = merge(value, into: page.props[key], touched: &touched)
    }
    nodes[RufletWireID.page] = page
    return finishApply(touched: touched, previousNodes: previousNodes)
  }

  @discardableResult
  public func apply(_ patch: ControlPatch) -> Bool {
    let previousNodes = nodes
    var touched: Set<Int> = [patch.controlID]

    // A patch can arrive for a control the store has not seen when the runtime
    // patches a slot before the tree carrying it. Registering a bare node keeps
    // the props until the real control lands and merges over them.
    var node = nodes[patch.controlID]
      ?? ControlNode(id: patch.controlID, type: patch.controlID == RufletWireID.page ? "Page" : "")

    for operation in patch.operations {
      guard case .set(let key, let value) = operation else { continue }
      switch key {
      case RufletControlKey.type:
        if let name = value.stringValue { node.type = name }
      case RufletControlKey.id:
        break
      case RufletControlKey.internals:
        node.internals = mergeMap(value.mapValue ?? [:], into: node.internals, touched: &touched)
      default:
        node.props[key] = merge(value, into: node.props[key], touched: &touched)
      }
    }

    nodes[patch.controlID] = node
    return finishApply(touched: touched, previousNodes: previousNodes)
  }

  /// Writes a value the renderer produced locally, without a round trip.
  ///
  /// Native controls must feel native: a `Switch` flips under the finger and a
  /// `Slider` tracks the drag. Ruby is told through a `control_event` and, when
  /// it agrees, sends back a patch carrying the same value — which lands here
  /// as a no-op. When Ruby's handler decides otherwise, its patch wins.
  public func setLocalProperty(_ id: Int, key: String, value: RufletValue) {
    let previousNodes = nodes
    guard var node = nodes[id] else { return }
    guard node.props[key] != value else { return }
    node.props[key] = value
    nodes[id] = node
    _ = finishApply(touched: [id], previousNodes: previousNodes)
  }

  public func reset() {
    nodes.removeAll()
    lastChangedIDs = []
    revision &+= 1
    objectWillChange.send()
  }

  // MARK: - Materialization

  /// Turns nested control maps into registered nodes plus `.controlRef` values.
  private func materialize(_ value: RufletValue, touched: inout Set<Int>) -> RufletValue {
    switch value {
    case .map(let entries):
      guard let id = entries[RufletControlKey.id]?.intValue else {
        return .map(entries.mapValues { materialize($0, touched: &touched) })
      }
      register(id: id, from: entries, touched: &touched)
      return .controlRef(id)

    case .array(let items):
      return .array(items.map { materialize($0, touched: &touched) })

    default:
      return value
    }
  }

  /// Flet's `Control.update()` recursively merges map-valued properties and
  /// merges an inline control when its wire id is unchanged. Lists and scalar
  /// values are replaced. This is deliberately separate from `register`,
  /// which materializes a newly introduced control from its complete map.
  private func merge(
    _ value: RufletValue, into existing: RufletValue?, touched: inout Set<Int>
  ) -> RufletValue {
    guard case .map(let entries) = value else {
      return materialize(value, touched: &touched)
    }

    if let id = entries[RufletControlKey.id]?.intValue {
      if existing?.controlID == id, nodes[id] != nil {
        mergeControl(id: id, from: entries, touched: &touched)
      } else {
        register(id: id, from: entries, touched: &touched)
      }
      return .controlRef(id)
    }

    return .map(mergeMap(entries, into: existing?.mapValue ?? [:], touched: &touched))
  }

  private func mergeMap(
    _ updates: [String: RufletValue], into existing: [String: RufletValue],
    touched: inout Set<Int>
  ) -> [String: RufletValue] {
    var result = existing
    for (key, value) in updates {
      result[key] = merge(value, into: result[key], touched: &touched)
    }
    return result
  }

  private func mergeControl(
    id: Int, from entries: [String: RufletValue], touched: inout Set<Int>
  ) {
    guard var node = nodes[id] else {
      register(id: id, from: entries, touched: &touched)
      return
    }
    touched.insert(id)
    for (key, value) in entries {
      switch key {
      case RufletControlKey.id:
        continue
      case RufletControlKey.type:
        // Flet ignores `_c` when updating a control with the same id.
        continue
      case RufletControlKey.internals:
        node.internals = mergeMap(value.mapValue ?? [:], into: node.internals, touched: &touched)
      default:
        node.props[key] = merge(value, into: node.props[key], touched: &touched)
      }
    }
    nodes[id] = node
  }

  private func register(id: Int, from entries: [String: RufletValue], touched: inout Set<Int>) {
    touched.insert(id)

    var props: [String: RufletValue] = [:]
    props.reserveCapacity(entries.count)
    var internals: [String: RufletValue] = [:]
    var type = nodes[id]?.type ?? ""

    for (key, value) in entries {
      switch key {
      case RufletControlKey.id:
        continue
      case RufletControlKey.type:
        type = value.stringValue ?? type
      case RufletControlKey.internals:
        internals = value.mapValue ?? [:]
      default:
        props[key] = materialize(value, touched: &touched)
      }
    }

    // Props are replaced rather than merged: `Control#to_patch` always carries
    // the control's complete property set, so a key the Ruby side dropped must
    // disappear here too. The node's identity is what survives.
    nodes[id] = ControlNode(id: id, type: type, props: props, internals: internals)
  }

  // MARK: - Removal

  private func finishApply(
    touched: Set<Int>, previousNodes: [Int: ControlNode]
  ) -> Bool {
    let inheritedChanges = resolveInheritedBaseProperties()
    collectGarbage()
    guard nodes != previousNodes else {
      lastChangedIDs = []
      return false
    }
    lastChangedIDs = Set(touched.union(inheritedChanges).filter {
      previousNodes[$0] != nodes[$0]
    })
    revision &+= 1
    objectWillChange.send()
    return true
  }

  /// Drops controls no longer reachable from the page.
  ///
  /// This is how removal works in the protocol: nothing says "delete control
  /// 137", a parent simply comes back with a shorter `controls` list. Sweeping
  /// from the root is the only way to notice.
  private func collectGarbage() {
    guard nodes[RufletWireID.page] != nil else { return }

    var reachable: Set<Int> = []
    var frontier: [Int] = [RufletWireID.page]

    while let id = frontier.popLast() {
      guard reachable.insert(id).inserted, let node = nodes[id] else { continue }
      for value in node.props.values {
        appendControlIDs(in: value, to: &frontier)
      }
    }

    guard reachable.count != nodes.count else { return }
    nodes = nodes.filter { reachable.contains($0.key) }
  }

  private func appendControlIDs(in value: RufletValue, to frontier: inout [Int]) {
    switch value {
    case .controlRef(let id):
      frontier.append(id)
    case .array(let items):
      for item in items { appendControlIDs(in: item, to: &frontier) }
    case .map(let entries):
      for item in entries.values { appendControlIDs(in: item, to: &frontier) }
    default:
      break
    }
  }

  /// Flet's base Control inherits `disabled` with logical OR and `adaptive`
  /// with nearest-explicit-value semantics. Resolve those properties once per
  /// patch for the entire tree; controls then read them through ControlNode's
  /// ordinary typed accessors.
  private func resolveInheritedBaseProperties() -> Set<Int> {
    guard nodes[RufletWireID.page] != nil else { return [] }
    var changed: Set<Int> = []
    var visited: Set<Int> = []

    func visit(_ id: Int, parentDisabled: Bool, parentAdaptive: Bool?) {
      guard visited.insert(id).inserted, var node = nodes[id] else { return }

      // Component wrappers are transparent in Flet's `Control.parent` getter.
      let isComponent = node.type == "C"
      let effectiveDisabled = isComponent
        ? parentDisabled
        : (node.props["disabled"]?.boolValue == true || parentDisabled)
      let effectiveAdaptive = isComponent
        ? parentAdaptive
        : (node.props["adaptive"]?.boolValue ?? parentAdaptive)

      let oldDisabled = node.internals["_flet_resolved_disabled"]?.boolValue
      let oldAdaptive = node.internals["_flet_resolved_adaptive"]?.boolValue
      node.internals["_flet_resolved_disabled"] = .bool(effectiveDisabled)
      if let effectiveAdaptive {
        node.internals["_flet_resolved_adaptive"] = .bool(effectiveAdaptive)
      } else {
        node.internals.removeValue(forKey: "_flet_resolved_adaptive")
      }
      if oldDisabled != effectiveDisabled || oldAdaptive != effectiveAdaptive {
        nodes[id] = node
        changed.insert(id)
      }

      var children: [Int] = []
      for value in node.props.values { appendControlIDs(in: value, to: &children) }
      for childID in children {
        visit(childID, parentDisabled: effectiveDisabled, parentAdaptive: effectiveAdaptive)
      }
    }

    visit(RufletWireID.page, parentDisabled: false, parentAdaptive: nil)
    return changed
  }
}
