import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `flet_charts` extension package.
///
/// The wire descriptors stay in core so an unlinked chart reports the exact
/// missing product. The painters and their source defaults live here, and are
/// installed only when the application links and registers `RufletCharts`.
@MainActor
public enum RufletCharts: RufletExtension {
  public static let extensionName = "RufletCharts"

  public static func register(in _: ServiceRegistry) {
    for wireType in [
      "LineChart", "BarChart", "PieChart", "ScatterChart", "RadarChart",
      "CandlestickChart",
    ] {
      ControlRegistry.register(
        descriptor: ControlDescriptor(
          wireType: wireType,
          classification: .visible,
          implementation: "RufletCharts.ChartControlView",
          rendering: .nativeView,
          supportedEvents: ["event"])
      ) { node, _ in
        AnyView(ChartControlView(node: node))
      }
    }
  }
}
