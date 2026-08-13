import SwiftUI
import XCTest
@testable import RufletEngine
@testable import RufletProtocol

@MainActor
final class RoutingContractTests: XCTestCase {
  func testExternalURLNormalizesToPathQueryAndFragment() {
    let original = RufletRouteInformation(
      uri: URL(string: "ruflet://ruflet-host/aaa/bbb?tab=2#details")!,
      state: ["source": "deep-link"])
    let normalized = RufletRouteInformationProvider.normalize(original)
    XCTAssertEqual(normalized.uri.absoluteString, "/aaa/bbb?tab=2#details")
    XCTAssertEqual(normalized.state, ["source": "deep-link"])
  }

  func testEmptyExternalPathNormalizesToRoot() {
    let normalized = RufletRouteInformationProvider.normalize(.init(
      uri: URL(string: "ruflet://ruflet-host")!))
    XCTAssertEqual(normalized.uri.absoluteString, "/")
  }

  func testLocalProviderNormalizesInitialAndPushedRoutes() {
    let provider = RufletLocalRouteInformationProvider(
      initialRouteInformation: .init(
        uri: URL(string: "ruflet://ruflet-host/initial")!))
    XCTAssertEqual(provider.value.uri.absoluteString, "/initial")

    XCTAssertTrue(provider.didPushRouteInformation(.init(
      uri: URL(string: "ruflet://ruflet-host/next?q=1")!)))
    XCTAssertEqual(provider.value.uri.absoluteString, "/next?q=1")
  }

  func testRouteStateSuppressesDuplicateRouteChanges() {
    let state = RufletRouteState()
    var updates = 0
    let token = state.objectWillChange.sink { updates += 1 }
    state.go("/same")
    state.go("/same")
    XCTAssertEqual(state.route, "/same")
    XCTAssertEqual(updates, 1)
    withExtendedLifetime(token) {}
  }

  func testSimpleRouterDelegateBridgesConfigurationAndPopHandler() async {
    let state = RufletRouteState()
    let delegate = RufletSimpleRouterDelegate(
      routeState: state,
      builder: { AnyView(Text("Ruflet")) },
      popRouteHandler: { true })
    delegate.setNewRoutePath("/products/1")
    XCTAssertEqual(delegate.currentConfiguration, "/products/1")
    let popped = await delegate.popRoute()
    XCTAssertTrue(popped)
  }

  func testDeepLinkBootstrapHandsOffAndClearsPendingURL() {
    _ = RufletDeepLinkingBootstrap.takePendingInitialURL()
    let link = URL(string: "ruflet://ruflet-host/cold-start")!
    RufletDeepLinkingBootstrap.publish(link)
    XCTAssertEqual(RufletDeepLinkingBootstrap.takePendingInitialURL(), link)
    XCTAssertNil(RufletDeepLinkingBootstrap.takePendingInitialURL())
  }
}
