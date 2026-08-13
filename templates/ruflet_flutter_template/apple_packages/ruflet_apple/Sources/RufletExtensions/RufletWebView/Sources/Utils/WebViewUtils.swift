import Foundation

public enum RufletWebViewLoadRequestMethod: String, Sendable {
  case get
  case post

  init(_ value: String?) {
    self = Self(rawValue: value?.lowercased() ?? "") ?? .get
  }
}

public enum RufletWebViewJavaScriptMode: String, Sendable {
  case disabled
  case unrestricted

  init?(_ value: String?) {
    guard let value, let mode = Self(rawValue: value.lowercased()) else { return nil }
    self = mode
  }
}
