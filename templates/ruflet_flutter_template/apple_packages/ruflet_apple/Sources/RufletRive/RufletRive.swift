import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `Rive` extension control.
///
/// Register this bundle through `RufletAppView(services:)`; applications that
/// do not use Rive neither link nor initialize the Rive runtime.
@MainActor
public enum RufletRive: RufletServiceBundle {
  public static let bundleName = "RufletRive"

  public static func register(in _: ServiceRegistry) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "Rive",
        classification: .visible,
        implementation: "RufletRive.RiveControlView",
        rendering: .nativeView)
    ) { node, _ in
      AnyView(RiveControlView(node: node))
    }
  }
}
