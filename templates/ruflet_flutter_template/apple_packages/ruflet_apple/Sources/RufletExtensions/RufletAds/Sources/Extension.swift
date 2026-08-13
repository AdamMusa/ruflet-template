import RufletEngine
import SwiftUI

#if os(iOS)
import GoogleMobileAds
#endif

@MainActor
public struct Extension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> {
    #if os(iOS)
    [RufletAdsPackage.bannerType]
    #else
    []
    #endif
  }

  public var serviceControlTypes: Set<String> {
    #if os(iOS)
    [RufletAdsPackage.interstitialType]
    #else
    []
    #endif
  }

  public func ensureInitialized() {
    #if os(iOS)
    MobileAds.shared.start(completionHandler: nil)
    #endif
  }

  public func createView(for control: RufletControl) -> AnyView? {
    #if os(iOS)
    control.type == RufletAdsPackage.bannerType
      ? AnyView(BannerAdControl(control: control))
      : nil
    #else
    nil
    #endif
  }

  public func createService(for control: RufletControl) -> RufletService? {
    #if os(iOS)
    control.type == RufletAdsPackage.interstitialType
      ? InterstitialAdService(control: control)
      : nil
    #else
    nil
    #endif
  }
}
