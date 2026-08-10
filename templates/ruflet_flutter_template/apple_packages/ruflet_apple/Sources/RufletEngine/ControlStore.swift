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
  public func applyPageProperties(_ properties: [String: RufletValue]) {
    var touched: Set<Int> = [RufletWireID.page]
    var page = nodes[RufletWireID.page] ?? ControlNode(id: RufletWireID.page, type: "Page")
    for (key, value) in properties {
      page.props[key] = materialize(value, touched: &touched)
    }
    nodes[RufletWireID.page] = page
    finishApply(touched: touched)
  }

  public func apply(_ patch: ControlPatch) {
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
        node.internals = value.mapValue ?? [:]
      default:
        node.props[key] = materialize(value, touched: &touched)
      }
    }

    nodes[patch.controlID] = node
    finishApply(touched: touched)
  }

  /// Writes a value the renderer produced locally, without a round trip.
  ///
  /// Native controls must feel native: a `Switch` flips under the finger and a
  /// `Slider` tracks the drag. Ruby is told through a `control_event` and, when
  /// it agrees, sends back a patch carrying the same value — which lands here
  /// as a no-op. When Ruby's handler decides otherwise, its patch wins.
  public func setLocalProperty(_ id: Int, key: String, value: RufletValue) {
    guard var node = nodes[id] else { return }
    guard node.props[key] != value else { return }
    node.props[key] = value
    nodes[id] = node
    finishApply(touched: [id])
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

  private func finishApply(touched: Set<Int>) {
    lastChangedIDs = touched
    collectGarbage()
    revision &+= 1
    objectWillChange.send()
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
}
