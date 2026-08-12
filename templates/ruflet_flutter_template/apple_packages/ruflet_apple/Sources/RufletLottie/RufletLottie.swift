import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `Lottie` extension control.
///
/// Register this extension through `RufletAppView(extensions:)`; applications that
/// do not use Lottie neither link nor initialize the Airbnb Lottie runtime.
@MainActor
public enum RufletLottie: RufletExtension {
  public static let extensionName = "RufletLottie"

  public static func register(in _: ServiceRegistry) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "Lottie",
        classification: .visible,
        implementation: "RufletLottie.LottieControlView",
        rendering: .nativeView,
        supportedEvents: ["error", "load"])
    ) { node, _ in
      AnyView(LottieControlView(node: node))
    }
  }
}
