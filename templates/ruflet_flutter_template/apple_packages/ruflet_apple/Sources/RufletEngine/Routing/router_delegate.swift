import Combine
import SwiftUI

/// Apple routing bridge corresponding to Flet's SimpleRouterDelegate.
@MainActor
public final class RufletSimpleRouterDelegate: ObservableObject {
  public typealias PopRouteHandler = @MainActor () async -> Bool?

  public let routeState: RufletRouteState
  private let builder: @MainActor () -> AnyView
  private let popRouteHandler: PopRouteHandler?
  private var routeSubscription: AnyCancellable?

  public init(
    routeState: RufletRouteState,
    builder: @escaping @MainActor () -> AnyView,
    popRouteHandler: PopRouteHandler? = nil
  ) {
    self.routeState = routeState
    self.builder = builder
    self.popRouteHandler = popRouteHandler
    routeSubscription = routeState.objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
    }
  }

  public var currentConfiguration: String { routeState.route }

  public func build() -> AnyView { builder() }

  public func setNewRoutePath(_ configuration: String) {
    routeState.go(configuration)
  }

  public func popRoute() async -> Bool {
    if let result = await popRouteHandler?() { return result }
    return false
  }
}
