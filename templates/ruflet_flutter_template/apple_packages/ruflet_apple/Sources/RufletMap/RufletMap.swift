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

    // Flet registers every layer and attribution through flet_map's
    // Extension.createWidget(), even though those controls are ultimately
    // consumed by Map. Claim the same wire surface in this product instead of
    // leaving the metadata implementations owned by core RufletUI.
    registerMetadata("CircleLayer")
    registerMetadata("MarkerLayer")
    registerMetadata("PolygonLayer")
    registerMetadata("PolylineLayer")
    registerMetadata("TileLayer", events: ["image_error"])
    registerMetadata("SimpleAttribution", events: ["click"])
    registerMetadata("RichAttribution", events: ["click"])
  }

  private static func registerMetadata(_ wireType: String, events: Set<String> = []) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: wireType,
        classification: .structuralChild,
        implementation: "RufletMap.\(wireType)",
        rendering: .metadataOnly,
        supportedEvents: events)
    ) { _, _ in
      AnyView(EmptyView())
    }
  }
}
