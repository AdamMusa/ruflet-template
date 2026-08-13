import Foundation

public struct RufletRouteParser: Sendable {
  public init() {}

  public func parse(_ route: String) -> String {
    URL(string: route)?.absoluteString ?? route
  }
}
