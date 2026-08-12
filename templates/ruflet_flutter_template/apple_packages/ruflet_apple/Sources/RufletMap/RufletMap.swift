import RufletEngine
import RufletUI
import SwiftUI

/// Native Apple implementation of Flet's `flet_map` package.
@MainActor
public enum RufletMap: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "Map", classification: .visible,
        implementation: "RufletMap.MapControlView", rendering: .nativeView,
        supportedEvents: [
          "event", "hover", "init", "long_press", "pointer_cancel", "pointer_down",
          "pointer_up", "position_change", "secondary_tap", "tap",
        ],
        supportedMethods: [
          "center_on", "move_to", "reset_rotation", "rotate_from", "zoom_in",
          "zoom_out", "zoom_to",
        ])
    ) { node, _ in
      AnyView(MapControlView(node: node))
    }
  }
}
