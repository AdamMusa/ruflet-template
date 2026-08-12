import Foundation
import RufletEngine
import RufletProtocol

#if os(iOS)
import GoogleMobileAds
#endif

@MainActor
public final class InterstitialAdService: NSObject, RufletStreamingService {
  public static let wireType = "InterstitialAd"

  private var eventNode: ControlNode?
  private var eventContext: RufletServiceContext?
  private var loadedConfiguration: Configuration?
  private var loadingConfiguration: Configuration?
  private var timeoutTask: DispatchWorkItem?

  #if os(iOS)
  // The pinned Flet service holds a static InterstitialAd reference, so a
  // successful load is shared by the service type rather than a view body.
  private static var loadedAd: InterstitialAd?
  #endif

  public override init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    eventNode = node
    eventContext = context
    let configuration = Configuration(node: node)
    guard configuration != loadedConfiguration, configuration != loadingConfiguration else {
      return
    }
    load(configuration)
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    if let node {
      eventNode = node
      eventContext = context
      activate(node: node, context: context)
    }
    guard call.name == "show" else {
      completion(.failure(
        RufletServiceError.unsupportedMethod(type: Self.wireType, method: call.name)))
      return
    }
    #if os(iOS)
    Self.loadedAd?.present(from: nil)
    completion(.success(.null))
    #else
    completion(.failure(
      RufletServiceError.platformUnsupported(
        type: Self.wireType, method: call.name, platform: "macOS")))
    #endif
  }

  private func load(_ configuration: Configuration) {
    #if os(iOS)
    loadingConfiguration = configuration
    timeoutTask?.cancel()
    InterstitialAd.load(
      with: configuration.unitID,
      request: configuration.request.googleRequest()
    ) { [weak self] ad, error in
      Task { @MainActor in
        guard let self, self.loadingConfiguration == configuration else { return }
        self.timeoutTask?.cancel()
        self.timeoutTask = nil
        self.loadingConfiguration = nil
        if let error {
          Self.loadedAd = nil
          self.fire("error", data: .string(String(describing: error)))
          return
        }
        guard let ad else { return }
        ad.fullScreenContentDelegate = self
        Self.loadedAd = ad
        self.loadedConfiguration = configuration
        self.fire("load")
      }
    }
    armTimeout(configuration.request.httpTimeoutMilliseconds, configuration: configuration)
    #endif
  }

  #if os(iOS)
  private func armTimeout(_ milliseconds: Int?, configuration: Configuration) {
    guard let milliseconds, milliseconds > 0 else { return }
    let task = DispatchWorkItem { [weak self] in
      guard let self, self.loadingConfiguration == configuration else { return }
      self.loadingConfiguration = nil
      self.fire("error", data: .string("Ad request timed out after \(milliseconds) ms"))
    }
    timeoutTask = task
    DispatchQueue.main.asyncAfter(
      deadline: .now() + .milliseconds(milliseconds), execute: task)
  }
  #endif

  private func fire(_ name: String, data: RufletValue = .null) {
    guard let eventNode, eventNode.handlesEvent(name), let eventContext else { return }
    eventContext.emitEvent(eventNode.id, name, data)
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

#if os(iOS)
extension InterstitialAdService: FullScreenContentDelegate {
  public func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
    fire("impression")
  }

  public func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
    fire("click")
  }

  public func ad(
    _ ad: any FullScreenPresentingAd,
    didFailToPresentFullScreenContentWithError error: any Error
  ) {
    fire("error", data: .string(String(describing: error)))
    Self.loadedAd = nil
  }

  public func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
    fire("open")
  }

  public func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
    fire("close")
    Self.loadedAd = nil
  }
}
#endif
