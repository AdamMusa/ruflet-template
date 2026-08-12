import RufletAds
import RufletEngine
import RufletProtocol
import RufletUI
import XCTest

final class RufletAdsContractTests: XCTestCase {
  func testPinnedAppleDefaultsMatchFletAdsSource() {
    XCTAssertEqual(
      RufletAdsContract.iOSTestAdUnitID,
      "ca-app-pub-3940256099942544/4411468910")
    XCTAssertEqual(RufletAdsContract.bannerWidth, 320)
    XCTAssertEqual(RufletAdsContract.bannerHeight, 50)
  }

  func testAdRequestPreservesEveryFletField() {
    let request = RufletAdRequest(value: .map([
      "keywords": .array(["swift", "ruby"]),
      "content_url": "https://ruflet.dev/content",
      "non_personalized_ads": true,
      "neighboring_content_urls": .array([
        "https://ruflet.dev/one", "https://ruflet.dev/two",
      ]),
      "http_timeout": 1_500,
      "extras": .map(["channel": "native", "publisher": "ruflet"]),
    ]))

    XCTAssertEqual(request.keywords, ["swift", "ruby"])
    XCTAssertEqual(request.contentURL, "https://ruflet.dev/content")
    XCTAssertEqual(request.nonPersonalizedAds, true)
    XCTAssertEqual(
      request.neighboringContentURLs,
      ["https://ruflet.dev/one", "https://ruflet.dev/two"])
    XCTAssertEqual(request.httpTimeoutMilliseconds, 1_500)
    XCTAssertEqual(
      request.extras,
      ["channel": "native", "publisher": "ruflet"])
  }

  func testAppleRequestUsesPinnedExplicitExtrasPrecedenceOverNpa() {
    let request = RufletAdRequest(value: .map([
      "non_personalized_ads": true,
      "http_timeout": 25,
      "extras": .map([
        "npa": "publisher-choice",
        "channel": "native",
        "invalid": 3,
      ]),
    ]))

    XCTAssertEqual(
      request.appleAdditionalParameters,
      ["npa": "publisher-choice", "channel": "native", "invalid": 3])
    XCTAssertEqual(request.httpTimeoutMilliseconds, 25)
    XCTAssertEqual(request.extras?["invalid"], 3)
  }

  func testAppleRequestInjectsNpaOnlyWhenRequested() {
    XCTAssertEqual(
      RufletAdRequest(value: .map(["non_personalized_ads": true]))
        .appleAdditionalParameters,
      ["npa": "1"])
    XCTAssertTrue(
      RufletAdRequest(value: .map(["non_personalized_ads": false]))
        .appleAdditionalParameters.isEmpty)
  }

  func testAbsentAdRequestUsesFletEmptyRequestDefaults() {
    XCTAssertEqual(RufletAdRequest(value: nil), RufletAdRequest(value: .null))
    XCTAssertNil(RufletAdRequest(value: nil).keywords)
  }

  func testPaidPayloadUsesExactFletKeysAndPrecisionSpelling() {
    XCTAssertEqual(
      RufletPaidAdEvent.payload(
        valueMicros: 42.5, precision: .publisherProvided, currencyCode: "USD"),
      .map([
        "value": 42.5,
        "precision": "publisherProvided",
        "currency_code": "USD",
      ]))
  }
}

@MainActor
final class RufletAdsRegistrationTests: XCTestCase {
  func testExtensionRegistersBannerAndInterstitialContracts() {
    let registry = ServiceRegistry()
    registry.register(extension: RufletAds.self)

    let banner = ControlRegistry.descriptor(for: "BannerAd")
    XCTAssertEqual(banner?.classification, .visible)
    XCTAssertEqual(banner?.implementation, "RufletAds.BannerAdControlView")
    XCTAssertEqual(
      banner?.supportedEvents,
      ["click", "close", "error", "impression", "load", "open", "paid", "will_dismiss"])

    let interstitial = ControlRegistry.descriptor(for: "InterstitialAd")
    XCTAssertEqual(interstitial?.classification, .service)
    XCTAssertEqual(interstitial?.implementation, "RufletAds.InterstitialAdService")
    XCTAssertEqual(interstitial?.supportedMethods, ["show"])
    XCTAssertEqual(
      interstitial?.supportedEvents,
      ["click", "close", "error", "impression", "load", "open"])
    XCTAssertTrue(registry.handles("InterstitialAd"))
  }

  func testManifestAndMissingServicePointToOptionalAdsProduct() {
    XCTAssertTrue(RufletExtensionManifest.packages.contains {
      $0.fletPackage == "flet_ads"
        && $0.swiftProduct == "RufletAds"
        && $0.status == .available
    })
    XCTAssertEqual(ServiceRegistry.bundleProviding("InterstitialAd"), "RufletAds")
  }

  func testInterstitialRejectsUnknownMethodsWithoutStartingAnAdRequest() {
    let service = InterstitialAdService()
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(
        controlID: 7, callID: "unknown", name: "reload", args: .null),
      node: nil,
      context: RufletServiceContext(
        store: ControlStore(), emitEvent: { _, _, _ in }),
      completion: { result = $0 })

    guard case .failure(let error) = result else {
      return XCTFail("Expected an unsupported-method failure")
    }
    XCTAssertEqual(
      error as? RufletServiceError,
      .unsupportedMethod(type: "InterstitialAd", method: "reload"))
  }

  #if os(macOS)
  func testInterstitialShowReportsTheOptionalProductsIOSBoundary() {
    let service = InterstitialAdService()
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: 7, callID: "show", name: "show", args: .null),
      node: nil,
      context: RufletServiceContext(
        store: ControlStore(), emitEvent: { _, _, _ in }),
      completion: { result = $0 })

    guard case .failure(let error) = result else {
      return XCTFail("Expected an unsupported-platform failure")
    }
    XCTAssertEqual(
      error as? RufletServiceError,
      .platformUnsupported(type: "InterstitialAd", method: "show", platform: "macOS"))
  }
  #endif
}
