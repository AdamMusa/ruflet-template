import Foundation
import RufletProtocol

struct RufletAdRequest: Equatable {
  let keywords: [String]?
  let contentURL: String?
  let nonPersonalizedAds: Bool?
  let neighboringContentURLs: [String]?
  let httpTimeoutMilliseconds: Int?
  let extras: [String: RufletValue]

  init(_ value: RufletValue?) {
    let map = rufletAdsStringMap(value)
    keywords = map?["keywords"]?.array?.compactMap(\.text)
    contentURL = map?["content_url"]?.text
    nonPersonalizedAds = map?["non_personalized_ads"]?.bool
    neighboringContentURLs = map?["neighboring_content_urls"]?.array?.compactMap(\.text)
    httpTimeoutMilliseconds = map?["http_timeout"]?.integer
    extras = rufletAdsStringMap(map?["extras"]) ?? [:]
  }
}

enum RufletAdPrecision: String {
  case unknown
  case estimated
  case publisherProvided
  case precise
}

func rufletPaidEvent(value: Double, precision: RufletAdPrecision, currencyCode: String) -> RufletValue {
  .map([
    "value": .double(value),
    "precision": .string(precision.rawValue),
    "currency_code": .string(currencyCode),
  ])
}

func rufletAdsStringMap(_ value: RufletValue?) -> [String: RufletValue]? {
  guard let value else { return nil }
  switch value {
  case .map(let map): return map
  case .keyedMap(let map):
    var result: [String: RufletValue] = [:]
    for (key, value) in map {
      guard case .string(let key) = key else { continue }
      result[key] = value
    }
    return result
  default: return nil
  }
}

#if os(iOS)
import GoogleMobileAds

extension RufletAdRequest {
  func googleRequest() -> Request {
    let request = Request()
    request.keywords = keywords
    request.contentURL = contentURL
    request.neighboringContentURLs = neighboringContentURLs
    request.requestAgent = "Ruflet"

    var parameters = extras.mapValues(\.googleAdValue)
    if nonPersonalizedAds == true { parameters["npa"] = "1" }
    if !parameters.isEmpty {
      let extras = Extras()
      extras.additionalParameters = parameters
      request.register(extras)
    }
    return request
  }
}

private extension RufletValue {
  var googleAdValue: Any {
    switch self {
    case .null: NSNull()
    case .bool(let value): value
    case .int(let value): value
    case .double(let value): value
    case .string(let value): value
    case .binary(let value): value
    case .array(let value): value.map(\.googleAdValue)
    case .map(let value): value.mapValues(\.googleAdValue)
    case .keyedMap(let value):
      Dictionary(uniqueKeysWithValues: value.map { key, item in
        let convertedKey: AnyHashable
        switch key {
        case .string(let value): convertedKey = value
        case .int(let value): convertedKey = value
        }
        return (convertedKey, item.googleAdValue)
      })
    case .extensionValue(let type, let payload):
      ["type": type, "payload": payload]
    }
  }
}
#endif
