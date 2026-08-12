import RufletEngine
import RufletUI
import SwiftUI

#if os(iOS)
import GoogleMobileAds
#endif

/// Optional native Apple implementation of Flet's `flet_ads` package.
@MainActor
public enum RufletAds: RufletExtension {
  public static let extensionName = "RufletAds"

  public static func register(in registry: ServiceRegistry) {
    #if os(iOS)
    MobileAds.shared.start()
    #endif

    registry.registerNamed(InterstitialAdService.wireType) { InterstitialAdService() }
    registry.markStreaming([InterstitialAdService.wireType])

    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "BannerAd", classification: .visible,
        implementation: "RufletAds.BannerAdControlView", rendering: .nativeView,
        supportedEvents: [
          "click", "close", "error", "impression", "load", "open", "paid",
          "will_dismiss",
        ])) { node, _ in
      AnyView(BannerAdControlView(node: node))
    }

    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "InterstitialAd", classification: .service,
        implementation: "RufletAds.InterstitialAdService", rendering: .serviceOnly,
        supportedEvents: ["click", "close", "error", "impression", "load", "open"],
        supportedMethods: ["show"])) { _, _ in
      AnyView(EmptyView())
    }
  }
}
