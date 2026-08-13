import Foundation
import RufletEngine
import RufletProtocol

#if os(iOS)
import GoogleMobileAds

enum RufletInterstitialError: LocalizedError {
  case unknownMethod(String)

  var errorDescription: String? {
    switch self {
    case .unknownMethod(let name): "Unknown InterstitialAd method: \(name)"
    }
  }
}

@MainActor
final class InterstitialAdService: RufletService {
  private static var loadedAd: InterstitialAd?
  private var invokeToken: UUID?
  private var loadGeneration = UUID()
  private lazy var fullScreenDelegate = InterstitialFullScreenDelegate(service: self)

  required init(control: RufletControl) {
    super.init(control: control)
  }

  override func initialize() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { [weak self] name, _ in
      guard let self else { return .null }
      return try self.invoke(name)
    }
    load()
  }

  override func update() {
    // The pinned service loads once during initialization. Property updates do
    // not replace an in-flight or loaded interstitial.
  }

  override func dispose() {
    loadGeneration = UUID()
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
    Self.loadedAd = nil
  }

  private func invoke(_ name: String) throws -> RufletValue {
    guard name == "show" else { throw RufletInterstitialError.unknownMethod(name) }
    Self.loadedAd?.present(from: nil)
    return .null
  }

  private func load() {
    let generation = UUID()
    loadGeneration = generation
    let unitID = control.string("unit_id") ?? "ca-app-pub-3940256099942544/4411468910"
    let request = RufletAdRequest(control.value("request")).googleRequest()
    InterstitialAd.load(with: unitID, request: request) { [weak self] ad, error in
      Task { @MainActor in
        guard let self, self.loadGeneration == generation else { return }
        if let error {
          Self.loadedAd = nil
          self.control.triggerEvent("error", data: .string(String(describing: error)))
          return
        }
        guard let ad else { return }
        ad.fullScreenContentDelegate = self.fullScreenDelegate
        ad.paidEventHandler = { [weak self] value in
          Task { @MainActor in
            self?.control.triggerEvent("paid", data: rufletPaidEvent(
              value: value.value.doubleValue,
              precision: Self.precision(value.precision),
              currencyCode: value.currencyCode))
          }
        }
        Self.loadedAd = ad
        self.control.triggerEvent("load")
      }
    }
  }

  private static func precision(_ value: AdValuePrecision) -> RufletAdPrecision {
    switch value {
    case .estimated: .estimated
    case .publisherProvided: .publisherProvided
    case .precise: .precise
    default: .unknown
    }
  }
  fileprivate func didRecordImpression() {
    control.triggerEvent("impression")
  }

  fileprivate func didRecordClick() {
    control.triggerEvent("click")
  }

  fileprivate func didFailToPresent(_ error: any Error) {
    control.triggerEvent("error", data: .string(String(describing: error)))
    Self.loadedAd = nil
  }

  fileprivate func willPresent() {
    control.triggerEvent("open")
  }

  fileprivate func didDismiss() {
    control.triggerEvent("close")
    Self.loadedAd = nil
  }
}

@MainActor
private final class InterstitialFullScreenDelegate: NSObject, FullScreenContentDelegate {
  weak var service: InterstitialAdService?

  init(service: InterstitialAdService) { self.service = service }

  func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
    service?.didRecordImpression()
  }

  func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
    service?.didRecordClick()
  }

  func ad(
    _ ad: any FullScreenPresentingAd,
    didFailToPresentFullScreenContentWithError error: any Error
  ) {
    service?.didFailToPresent(error)
  }

  func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
    service?.willPresent()
  }

  func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
    service?.didDismiss()
  }
}
#endif
