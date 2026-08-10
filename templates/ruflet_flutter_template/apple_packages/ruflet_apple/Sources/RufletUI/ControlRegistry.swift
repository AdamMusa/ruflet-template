import RufletEngine
import RufletProtocol
import SwiftUI

/// Maps a wire type onto its native implementation.
///
/// One entry per Ruflet control, grouped the way the Ruby side groups them
/// (shared, material, cupertino, …). Adding a control is a case in the right
/// family plus its view; nothing else in the engine changes.
///
/// The families are plain functions returning an optional `AnyView` rather than
/// one large `switch` so the Swift type checker sees ten small problems instead
/// of one 170-case one, and so a family can be worked on in isolation.
public enum ControlRegistry {
  /// Extra types a host registers at runtime, mirroring
  /// `ControlFactory::EXTENSION_CLASS_MAP` on the Ruby side.
  private static var extensions: [String: (ControlNode, LayoutAxis) -> AnyView] = [:]

  public static func register(
    _ wireType: String,
    builder: @escaping (ControlNode, LayoutAxis) -> AnyView
  ) {
    extensions[wireType.lowercased()] = builder
  }

  static func build(node: ControlNode, axis: LayoutAxis) -> AnyView? {
    if let custom = extensions[node.type.lowercased()] {
      return custom(node, axis)
    }
    // Written as a loop rather than a chain of `??` so the type checker sees
    // ten identical calls instead of one deeply nested optional expression.
    let families: [(ControlNode, LayoutAxis) -> AnyView?] = [
      layout, buttons, inputs, display, collections,
      chrome, overlays, gestures, cupertino, media
    ]
    for family in families {
      if let view = family(node, axis) { return view }
    }
    return nil
  }
}
