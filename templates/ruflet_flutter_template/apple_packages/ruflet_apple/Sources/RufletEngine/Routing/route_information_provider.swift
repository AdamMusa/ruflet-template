import Foundation
import RufletProtocol

/// Route information carried between Apple's URL delivery APIs and Ruflet's
/// path-based router.
public struct RufletRouteInformation: Equatable, Sendable {
  public let uri: URL
  public let state: RufletValue?

  public init(uri: URL, state: RufletValue? = nil) {
    self.uri = uri
    self.state = state
  }
}

/// Normalizes external URLs such as `ruflet://ruflet-host/aaa` to `/aaa`,
/// matching FletRouteInformationProvider's path, query, and fragment contract.
@MainActor
public final class RufletRouteInformationProvider: ObservableObject {
  @Published public private(set) var value: RufletRouteInformation

  public init(initialRouteInformation: RufletRouteInformation) {
    value = Self.normalize(initialRouteInformation)
  }

  public static func normalize(
    _ routeInformation: RufletRouteInformation
  ) -> RufletRouteInformation {
    let source = URLComponents(
      url: routeInformation.uri,
      resolvingAgainstBaseURL: false)
    var normalized = URLComponents()
    normalized.percentEncodedPath = source?.percentEncodedPath.isEmpty == false
      ? source!.percentEncodedPath
      : "/"
    normalized.percentEncodedQuery = source?.percentEncodedQuery
    normalized.percentEncodedFragment = source?.percentEncodedFragment
    guard let uri = normalized.url else {
      preconditionFailure("Unable to normalize Ruflet route: \(routeInformation.uri)")
    }
    return RufletRouteInformation(uri: uri, state: routeInformation.state)
  }

  @discardableResult
  public func didPushRouteInformation(
    _ routeInformation: RufletRouteInformation
  ) -> Bool {
    setValue(routeInformation)
    return true
  }

  public func routerReportsNewRouteInformation(
    _ routeInformation: RufletRouteInformation
  ) {
    setValue(routeInformation)
  }

  private func setValue(_ routeInformation: RufletRouteInformation) {
    let normalized = Self.normalize(routeInformation)
    guard normalized != value else { return }
    value = normalized
  }
}

/// Local multi-view counterpart to the platform route provider.
public typealias RufletLocalRouteInformationProvider = RufletRouteInformationProvider
