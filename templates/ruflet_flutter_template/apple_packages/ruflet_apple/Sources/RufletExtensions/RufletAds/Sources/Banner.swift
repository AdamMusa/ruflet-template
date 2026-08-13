import RufletEngine
import SwiftUI

#if os(iOS)
import GoogleMobileAds
import RufletProtocol
import UIKit

struct BannerAdControl: View {
  @ObservedObject var control: RufletControl

  var body: some View {
    RufletBannerAdView(control: control)
      .frame(width: 320, height: 50)
  }
}

private struct RufletBannerAdView: UIViewRepresentable {
  let control: RufletControl

  func makeCoordinator() -> Coordinator { Coordinator(control: control) }

  func makeUIView(context: Context) -> BannerView {
    let view = BannerView(adSize: AdSizeBanner)
    view.delegate = context.coordinator
    context.coordinator.attach(view)
    context.coordinator.update(control)
    return view
  }

  func updateUIView(_ view: BannerView, context: Context) {
    context.coordinator.attach(view)
    context.coordinator.update(control)
  }

  static func dismantleUIView(_ view: BannerView, coordinator: Coordinator) {
    view.delegate = nil
    view.paidEventHandler = nil
    coordinator.detach()
  }

  @MainActor
  final class Coordinator: NSObject, BannerViewDelegate {
    private var control: RufletControl
    private weak var banner: BannerView?
    private var configuration: Configuration?

    init(control: RufletControl) { self.control = control }

    func attach(_ banner: BannerView) {
      self.banner = banner
      banner.delegate = self
    }

    func detach() {
      banner = nil
      configuration = nil
    }

    func update(_ control: RufletControl) {
      self.control = control
      let next = Configuration(control: control)
      guard configuration != next, let banner else { return }
      configuration = next
      banner.adUnitID = next.unitID
      banner.rootViewController = nil
      banner.paidEventHandler = { [weak self] value in
        Task { @MainActor in
          self?.control.triggerEvent("paid", data: rufletPaidEvent(
            value: value.value.doubleValue,
            precision: Self.precision(value.precision),
            currencyCode: value.currencyCode))
        }
      }
      banner.load(next.request.googleRequest())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
      control.triggerEvent("load")
    }

    func bannerView(
      _ bannerView: BannerView,
      didFailToReceiveAdWithError error: any Error
    ) {
      control.triggerEvent("error", data: .string(String(describing: error)))
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
      control.triggerEvent("impression")
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
      control.triggerEvent("click")
    }

    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
      control.triggerEvent("open")
    }

    func bannerViewWillDismissScreen(_ bannerView: BannerView) {
      control.triggerEvent("will_dismiss")
    }

    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
      control.triggerEvent("close")
    }

    private static func precision(_ value: AdValuePrecision) -> RufletAdPrecision {
      switch value {
      case .estimated: .estimated
      case .publisherProvided: .publisherProvided
      case .precise: .precise
      default: .unknown
      }
    }
  }

  private struct Configuration: Equatable {
    let unitID: String
    let request: RufletAdRequest

    @MainActor
    init(control: RufletControl) {
      unitID = control.string("unit_id") ?? "ca-app-pub-3940256099942544/4411468910"
      request = RufletAdRequest(control.value("request"))
    }
  }
}
#endif
