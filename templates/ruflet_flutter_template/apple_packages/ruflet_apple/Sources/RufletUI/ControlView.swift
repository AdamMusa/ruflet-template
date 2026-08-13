import RufletEngine
import RufletProtocol
import SwiftUI

/// Renders one control by id.
///
/// Addressed by id rather than by value so a control keeps its SwiftUI identity
/// across patches: the store replaces a node's props wholesale on a full
/// re-send, but the id is stable, so scroll positions and focus survive.
public struct ControlView: View {
  public let id: Int
  /// The axis the parent lays out along, so `expand` resolves to the right one.
  public let axis: LayoutAxis

  @EnvironmentObject private var store: ControlStore

  public init(id: Int, axis: LayoutAxis = .none) {
    self.id = id
    self.axis = axis
  }

  public var body: some View {
    ObservedControlView(
      id: id, axis: axis, observation: store.observation(for: id))
  }
}

/// The retained observation boundary for one wire control.
private struct ObservedControlView: View {
  let id: Int
  let axis: LayoutAxis
  @ObservedObject var observation: ControlStore.Observation
  @EnvironmentObject private var store: ControlStore

  var body: some View {
    // Reading the token makes the dependency explicit even though the current
    // node snapshot is fetched from the non-publishing retained store.
    let _ = observation.revision
    if let node = store.node(id) {
      ControlBody(node: node, axis: axis)
        .rufletCommon(node, axis: axis)
        .id(id)
    }
  }
}

/// Renders a list of child ids, honouring a stack's spacing.
struct ControlList: View {
  let ids: [Int]
  let axis: LayoutAxis

  var body: some View {
    ForEach(ids, id: \.self) { childID in
      ControlView(id: childID, axis: axis)
    }
  }
}

/// Dispatches a node to its implementation.
///
/// Split into per-family builders because a single 170-case `switch` in one
/// `some View` body is beyond what the Swift type checker will chew through in
/// reasonable time.
struct ControlBody: View {
  let node: ControlNode
  let axis: LayoutAxis
  @Environment(\.rufletExtensions) private var extensions

  var body: some View {
    if let view = RufletExtensionRenderer.build(
      node: node, extensions: extensions)
    {
      view
    } else if let view = ControlRegistry.build(node: node, axis: axis) {
      view
    } else {
      UnmappedControlView(node: node, axis: axis)
    }
  }
}

/// Ordered application-extension dispatch, equivalent to Flet's
/// ControlWidget loop over FletBackend.extensions.
@MainActor
enum RufletExtensionRenderer {
  static func build(
    node: ControlNode,
    extensions: [any RufletExtension.Type]
  ) -> AnyView? {
    for extensionType in extensions {
      if let view = extensionType.createView(for: node) { return view }
    }
    return nil
  }

  static func buildIcon(
    code: Int,
    extensions: [any RufletExtension.Type]
  ) -> AnyView? {
    for extensionType in extensions {
      if let view = extensionType.createIcon(for: code) { return view }
    }
    return nil
  }
}

/// What a control type nobody implemented renders as.
///
/// Renders its children rather than nothing, so an unmapped wrapper (a
/// decorator, an animation host) still shows the content underneath it instead
/// of blanking a screen. The log line is how you find out it happened.
struct UnmappedControlView: View {
  let node: ControlNode
  let axis: LayoutAxis

  var body: some View {
    let children = node.childIDs
    Group {
      if children.isEmpty {
        EmptyView()
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ControlList(ids: children, axis: .vertical)
        }
      }
    }
    .onAppear {
      RufletLog.debug("No Apple renderer for control type `\(node.type)` (id \(node.id))")
    }
  }
}
