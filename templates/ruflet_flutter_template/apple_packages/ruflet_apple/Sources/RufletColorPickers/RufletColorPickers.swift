import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `flet_color_pickers` package.
@MainActor
public enum RufletColorPickers: RufletExtension {
  public static let extensionName = "RufletColorPickers"

  public static func register(in _: ServiceRegistry) {
    register("ColorPicker", events: ["color_change", "hsv_color_change", "history_change"])
    register("MaterialPicker", events: ["color_change", "primary_change"])
    register("MultipleChoiceBlockPicker", events: ["colors_change"])
    for wireType in ["HueRingPicker", "SlidePicker", "BlockPicker"] {
      register(wireType, events: ["color_change"])
    }
  }

  private static func register(_ wireType: String, events: Set<String>) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: wireType,
        classification: .visible,
        implementation: "RufletColorPickers.RufletColorPickerControlView",
        rendering: .nativeView,
        supportedEvents: events)
    ) { node, _ in
      AnyView(RufletColorPickerControlView(node: node))
    }
  }
}
