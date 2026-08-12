import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `flet_spinkit` package.
///
/// Both Ruflet's variant-based compatibility control and Flet's thirty native
/// wire types are registered by this one extension product.
@MainActor
public enum RufletSpinKit: RufletExtension {
  public static let extensionName = "RufletSpinKit"

  public static func register(in _: ServiceRegistry) {
    for wireType in ["RufletSpinKit"] + RufletSpinKitConfiguration.fletWireTypes {
      ControlRegistry.register(
        descriptor: ControlDescriptor(
          wireType: wireType,
          classification: .visible,
          implementation: "RufletSpinKit.SpinKitControlView",
          rendering: .nativeView)
      ) { node, _ in
        AnyView(SpinKitControlView(node: node))
      }
    }
  }
}
