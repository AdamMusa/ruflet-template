#if os(iOS)
import GoogleMobileAds
import RufletProtocol

extension RufletAdRequest {
  func googleRequest() -> Request {
    let request = Request()
    request.keywords = keywords
    request.contentURL = contentURL
    request.neighboringContentURLs = neighboringContentURLs

    var parameters: [AnyHashable: Any] = [:]
    for (key, value) in extras ?? [:] {
      parameters[key] = value.googleAdValue
    }
    if nonPersonalizedAds == true {
      // This is the Google Mobile Ads equivalent used by the Flutter plugin.
      parameters["npa"] = "1"
    }
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
    case .null: return NSNull()
    case .bool(let value): return value
    case .int(let value): return value
    case .double(let value): return value
    case .string(let value): return value
    case .binary(let value): return Data(value)
    case .array(let value): return value.map(\.googleAdValue)
    case .map(let value): return value.mapValues(\.googleAdValue)
    case .extended(_, let value): return value
    case .controlRef(let value): return value
    }
  }
}
#endif
