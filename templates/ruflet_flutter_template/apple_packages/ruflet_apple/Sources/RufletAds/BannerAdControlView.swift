import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

public struct BannerAdControlView: View {
  public let node: ControlNode
  @Environment(\.rufletEvents) private var events

  public init(node: ControlNode) {
    self.node = node
  }

  public var body: some View {
    #if os(iOS)
    BannerAdRepresentable(node: node, events: events)
      .frame(
        width: RufletAdsContract.bannerWidth,
        height: RufletAdsContract.bannerHeight)
    #else
    // Google Mobile Ads is an iOS-only binary. Keeping Flet's banner extent
    // here preserves layout without pretending that an ad loaded on macOS.
    Color.clear.frame(
      width: RufletAdsContract.bannerWidth,
      height: RufletAdsContract.bannerHeight)
    #endif
  }
}

#if os(iOS)
import GoogleMobileAds
import UIKit

private struct BannerAdRepresentable: UIViewRepresentable {
  let node: ControlNode
  let events: RufletEventSink

  func makeCoordinator() -> Coordinator {
    Coordinator(node: node, events: events)
  }

  func makeUIView(context: Context) -> BannerView {
    let banner = BannerView(adSize: AdSizeBanner)
    banner.delegate = context.coordinator
    context.coordinator.attach(banner)
    context.coordinator.update(node: node, events: events)
    return banner
  }

  func updateUIView(_ banner: BannerView, context: Context) {
    context.coordinator.attach(banner)
    context.coordinator.update(node: node, events: events)
  }

  @MainActor
  final class Coordinator: NSObject, BannerViewDelegate {
    private var node: ControlNode
    private var events: RufletEventSink
    private weak var banner: BannerView?
    private var signature: Configuration?

    init(node: ControlNode, events: RufletEventSink) {
      self.node = node
      self.events = events
    }

    func attach(_ banner: BannerView) {
      self.banner = banner
      banner.delegate = self
    }

    func update(node: ControlNode, events: RufletEventSink) {
      self.node = node
      self.events = events
      let next = Configuration(node: node)
      guard next != signature else { return }
      signature = next

      guard let banner else { return }
      banner.adUnitID = next.unitID
      banner.rootViewController = nil // The SDK resolves the containing/top controller.
      banner.paidEventHandler = { [weak self] value in
        guard let self else { return }
        self.fire(
          "paid",
          data: RufletPaidAdEvent.payload(
            valueMicros: value.value.doubleValue,
            precision: Self.precision(value.precision),
            currencyCode: value.currencyCode))
      }
      banner.load(next.request.googleRequest())
    }

    private func fire(_ name: String, data: RufletValue = .null) {
      events.fire(node, name, data: data)
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
      fire("load")
    }

    func bannerView(
      _ bannerView: BannerView,
      didFailToReceiveAdWithError error: any Error
    ) {
      fire("error", data: .string(String(describing: error)))
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) { fire("impression") }
    func bannerViewDidRecordClick(_ bannerView: BannerView) { fire("click") }
    func bannerViewWillPresentScreen(_ bannerView: BannerView) { fire("open") }
    func bannerViewWillDismissScreen(_ bannerView: BannerView) { fire("will_dismiss") }
    func bannerViewDidDismissScreen(_ bannerView: BannerView) { fire("close") }

    private static func precision(_ value: AdValuePrecision) -> RufletAdPrecision {
      switch value {
      case .estimated: return .estimated
      case .publisherProvided: return .publisherProvided
      case .precise: return .precise
      default: return .unknown
      }
    }
  }

  private struct Configuration: Equatable {
    let unitID: String
    let request: RufletAdRequest

    init(node: ControlNode) {
      unitID = node.string("unit_id") ?? RufletAdsContract.iOSTestAdUnitID
      request = RufletAdRequest(value: node.value("request"))
    }
  }
}
#endif
