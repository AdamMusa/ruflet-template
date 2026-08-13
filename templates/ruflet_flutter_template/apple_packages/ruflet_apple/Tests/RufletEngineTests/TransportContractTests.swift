import Foundation
import XCTest
@testable import RufletEngine
@testable import RufletProtocol

@MainActor
final class TransportContractTests: XCTestCase {
  func testHTTPAddressUsesPinnedNonWebWebSocketPath() throws {
    XCTAssertEqual(
      try rufletWebSocketEndpoint(URL(string: "http://localhost:8550")!).absoluteString,
      "ws://localhost:8550/ws")
    XCTAssertEqual(
      try rufletWebSocketEndpoint(URL(string: "https://example.com/p/demo")!).absoluteString,
      "wss://example.com/p/demo/ws")
  }

  func testWebSocketEndpointDropsQueryAndFragmentFromPageURL() throws {
    XCTAssertEqual(
      try rufletWebSocketEndpoint(URL(string: "https://example.com/p/demo?token=secret#view")!).absoluteString,
      "wss://example.com/p/demo/ws")
  }

  func testPinnedNonWebEndpointAlwaysAppendsWebSocketSegment() throws {
    XCTAssertEqual(
      try rufletWebSocketEndpoint(URL(string: "https://example.com/ws")!).absoluteString,
      "wss://example.com/ws/ws")
  }

  func testPrivateHostRangesMatchPinnedFletNetworkingContract() {
    XCTAssertTrue(rufletIsPrivateHost("localhost"))
    XCTAssertTrue(rufletIsPrivateHost("127.0.1.1"))
    XCTAssertTrue(rufletIsPrivateHost("192.168.0.1"))
    XCTAssertTrue(rufletIsPrivateHost("172.16.0.10"))
    XCTAssertTrue(rufletIsPrivateHost("172.31.255.255"))
    XCTAssertTrue(rufletIsPrivateHost("10.0.5.100"))
    XCTAssertTrue(rufletIsPrivateHost("::1"))
    XCTAssertTrue(rufletIsPrivateHost("fe80::1"))
    XCTAssertTrue(rufletIsPrivateHost("febf::ffff"))
    XCTAssertFalse(rufletIsPrivateHost("fec0::1"))
    XCTAssertFalse(rufletIsPrivateHost("172.32.0.1"))
    XCTAssertFalse(rufletIsPrivateHost("216.34.2.201"))
    XCTAssertFalse(rufletIsPrivateHost("45.3.2.2"))
    XCTAssertFalse(rufletIsPrivateHost("example.com"))
  }

  func testPrivateHostResolutionSupportsPinnedDNSBehavior() async throws {
    let localhostIsPrivate = try await rufletIsPrivateHostResolving("localhost")
    XCTAssertTrue(localhostIsPrivate)
    do {
      _ = try await rufletIsPrivateHostResolving(
        "host-that-does-not-exist.invalid")
      XCTFail("an unresolvable host must fail instead of silently becoming public")
    } catch let error as RufletTransportError {
      XCTAssertEqual(error, .cannotResolveHost("host-that-does-not-exist.invalid"))
    }
  }

  func testWebSocketChannelInitializerPropagatesEndpointErrors() {
    let address = URL(string: "https:relative-without-authority")!
    XCTAssertThrowsError(try RufletWebSocketBackendChannel(
      address: address,
      onDisconnect: {},
      onMessage: { _ in })) {
      XCTAssertEqual($0 as? RufletTransportError, .missingHost)
    }
  }

  func testFactoryRoutesHTTPAndTCPWithoutPlatformFallbacks() throws {
    let webSocket = try RufletBackendChannelFactory.make(
      address: URL(string: "https://example.com/demo")!,
      onDisconnect: {},
      onMessage: { _ in })
    XCTAssertTrue(webSocket is RufletWebSocketBackendChannel)

    let socket = try RufletBackendChannelFactory.make(
      address: URL(string: "tcp://192.168.1.10:8550")!,
      onDisconnect: {},
      onMessage: { _ in })
    XCTAssertTrue(socket is RufletSocketBackendChannel)
    XCTAssertTrue(socket.isLocalConnection)
    XCTAssertEqual(socket.defaultReconnectIntervalMilliseconds, 200)
    socket.disconnect()
  }

  func testFactoryRejectsNonAppleRendererTransportSchemes() {
    XCTAssertThrowsError(try RufletBackendChannelFactory.make(
      address: URL(string: "ftp://example.com/app")!,
      onDisconnect: {},
      onMessage: { _ in })) {
      XCTAssertEqual(
        $0 as? RufletTransportError,
        .unsupportedAddress("ftp://example.com/app"))
    }
  }

  func testTransportFrameIsThePinnedActionPayloadPair() throws {
    let request = RufletMessage(
      action: .registerClient,
      payload: RufletRegisterClientRequestBody(
        sessionID: nil,
        pageName: "p/demo",
        page: ["route": "/"]
      ).value)
    let bytes = RufletMessagePack.encode(.array(request.list))
    guard let frame = try RufletMessagePack.decode(bytes).array else {
      return XCTFail("transport frame must decode as a list")
    }
    XCTAssertEqual(try RufletMessage(list: frame), request)
    XCTAssertEqual(frame.first, 1)
    XCTAssertEqual(frame.last?["page_name"], "p/demo")
  }
}
