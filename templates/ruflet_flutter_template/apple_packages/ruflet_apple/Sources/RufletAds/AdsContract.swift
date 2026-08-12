import Foundation
import RufletEngine
import RufletProtocol

/// The wire contract vendored with `flet_ads` 0.80.5.
public enum RufletAdsContract {
  /// Flet deliberately uses this ID for both Apple banner and interstitial
  /// controls when the application does not provide an ad unit.
  public static let iOSTestAdUnitID = "ca-app-pub-3940256099942544/4411468910"
  public static let bannerWidth = 320.0
  public static let bannerHeight = 50.0
}

/// Flet's `AdRequest` value object, preserved independently of Google's SDK
/// so the extension's wire semantics remain testable on macOS.
public struct RufletAdRequest: Equatable {
  public var keywords: [String]?
  public var contentURL: String?
  public var nonPersonalizedAds: Bool?
  public var neighboringContentURLs: [String]?
  public var httpTimeoutMilliseconds: Int?
  public var extras: [String: RufletValue]?

  public init(value: RufletValue?) {
    guard let map = value?.mapValue else { return }
    keywords = map["keywords"]?.arrayValue?.compactMap(\.stringValue)
    contentURL = map["content_url"]?.stringValue
    nonPersonalizedAds = map["non_personalized_ads"]?.boolValue
    neighboringContentURLs =
      map["neighboring_content_urls"]?.arrayValue?.compactMap(\.stringValue)
    httpTimeoutMilliseconds = map["http_timeout"]?.intValue
    extras = map["extras"]?.mapValue
  }
}

public enum RufletAdPrecision: String, Equatable {
  case unknown
  case estimated
  case publisherProvided = "publisherProvided"
  case precise
}

public enum RufletPaidAdEvent {
  public static func payload(
    valueMicros: Double,
    precision: RufletAdPrecision,
    currencyCode: String
  ) -> RufletValue {
    .map([
      "value": .double(valueMicros),
      "precision": .string(precision.rawValue),
      "currency_code": .string(currencyCode),
    ])
  }
}
