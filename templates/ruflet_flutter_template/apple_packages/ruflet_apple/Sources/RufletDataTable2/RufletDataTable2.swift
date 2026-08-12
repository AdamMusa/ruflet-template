import RufletEngine
import RufletUI
import SwiftUI

/// Native Apple implementation of the vendored `flet_datatable2` package.
@MainActor
public enum RufletDataTable2: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "DataTable2", classification: .visible,
        implementation: "RufletDataTable2.DataTable2ControlView", rendering: .nativeView,
        supportedEvents: [
          "double_tap", "long_press", "secondary_tap", "secondary_tap_down",
          "select_all", "select_change", "sort", "tap", "tap_cancel", "tap_down",
        ])
    ) { node, _ in
      AnyView(DataTable2ControlView(node: node))
    }
  }
}
