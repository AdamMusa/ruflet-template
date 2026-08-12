import XCTest
import RufletEngine
import RufletProtocol

/// Direct translations of the pinned Flet 0.80.5 Dart tests under
/// `flet/test/utils`. These are engine conformance tests, not screenshot
/// expectations.
final class FletUpstreamParityTests: XCTestCase {
  func testControlsWithEqualIdentityTypeAndPropertiesAreEqual() {
    let properties: [String: RufletValue] = [
      "a": .int(1), "b": .int(2), "c": .map(["c_0": .string("test")])
    ]
    XCTAssertEqual(
      ControlNode(id: 1, type: "Button", props: properties),
      ControlNode(id: 1, type: "Button", props: properties)
    )
  }

  func testControlPatchUpdatesFirstAndSecondLevelValues() {
    let store = ControlStore()
    XCTAssertTrue(store.apply(ControlPatch(controlID: 1, operations: [
      .set(key: "_c", value: .string("Button")),
      .set(key: "a", value: .int(1)),
      .set(key: "b", value: .int(2)),
      .set(key: "c", value: .map([
        "c_0": .string("test"), "preserved": .string("original")
      ]))
    ])))

    let revision = store.revision
    XCTAssertTrue(store.apply(ControlPatch(controlID: 1, operations: [
      .set(key: "a", value: .int(10)),
      .set(key: "d", value: .bool(true)),
      .set(key: "c", value: .map([
        "c_0": .string("test_2"), "sub_1": .string("something")
      ]))
    ])))

    XCTAssertGreaterThan(store.revision, revision)
    XCTAssertEqual(store.node(1)?.props["a"], .int(10))
    XCTAssertEqual(store.node(1)?.props["b"], .int(2))
    XCTAssertEqual(store.node(1)?.props["d"], .bool(true))
    XCTAssertEqual(store.node(1)?.props["c"]?["c_0"], .string("test_2"))
    XCTAssertEqual(store.node(1)?.props["c"]?["sub_1"], .string("something"))
    XCTAssertEqual(store.node(1)?.props["c"]?["preserved"], .string("original"))
  }

  func testApplyingIdenticalControlPropertiesIsANoOp() {
    let store = ControlStore()
    let patch = ControlPatch(controlID: 1, operations: [
      .set(key: "_c", value: .string("Button")),
      .set(key: "a", value: .int(1)),
      .set(key: "b", value: .int(2)),
      .set(key: "c", value: .map(["c_0": .string("test")]))
    ])
    XCTAssertTrue(store.apply(patch))
    let revision = store.revision
    XCTAssertFalse(store.apply(patch))
    XCTAssertEqual(store.revision, revision)
    XCTAssertTrue(store.lastChangedIDs.isEmpty)
  }

  func testWebPageNameMatchesFletURIUtility() throws {
    XCTAssertEqual(FletURI.webPageName(try url("http://localhost:8550/p/test/")), "p/test")
    XCTAssertEqual(FletURI.webPageName(try url("http://localhost:8550/p/test")), "p/test")
    XCTAssertEqual(FletURI.webPageName(try url("http://localhost:8550/aaa")), "aaa")
    XCTAssertEqual(FletURI.webPageName(try url("http://localhost:8550/p/test/store")), "p/test")
    XCTAssertEqual(
      FletURI.webPageName(try url("http://localhost:8550/p/test/store/products/1")), "p/test"
    )
    XCTAssertEqual(FletURI.webPageName(try url("http://localhost:8550/")), "")
    XCTAssertEqual(FletURI.webPageName(try url("http://localhost:8550/#/")), "")
  }

  func testEmptyAndRelativeURIsHaveNoAuthority() {
    XCTAssertTrue(FletURI.isUDSPath(""))
    XCTAssertTrue(FletURI.isUDSPath("images/test.png"))
    XCTAssertFalse(FletURI.isUDSPath("https://flet.dev/images/test.png"))
  }

  func testPrivateIPv4RangesMatchFletNetworkingUtility() {
    XCTAssertTrue(FletNetworking.isPrivateIPAddress("127.0.1.1"))
    XCTAssertTrue(FletNetworking.isPrivateIPAddress("192.168.0.1"))
    XCTAssertTrue(FletNetworking.isPrivateIPAddress("172.16.0.10"))
    XCTAssertTrue(FletNetworking.isPrivateIPAddress("10.0.5.100"))
    XCTAssertFalse(FletNetworking.isPrivateIPAddress("216.34.2.201"))
    XCTAssertFalse(FletNetworking.isPrivateIPAddress("45.3.2.2"))
  }

  func testLocalhostResolutionMatchesFletNetworkingUtility() async throws {
    let isPrivate = try await FletNetworking.isPrivateHost("localhost")
    XCTAssertTrue(isPrivate)
  }

  func testCustomFontsAreParsedFromFletMap() {
    let fonts = FletUserFonts.parse(.map([
      "font1": .string("https://fonts.com/font1.ttf"),
      "font2": .string("https://fonts.com/font2.ttf")
    ]))
    XCTAssertEqual(fonts?.count, 2)
    XCTAssertEqual(fonts?["font1"], "https://fonts.com/font1.ttf")
    XCTAssertEqual(fonts?["font2"], "https://fonts.com/font2.ttf")
  }

  func testDisabledAndAdaptiveInheritLikeFletBaseControl() {
    let store = ControlStore()
    let child: RufletValue = .map([
      "_i": .int(100), "_c": .string("Switch"), "disabled": .bool(false)
    ])
    XCTAssertTrue(store.apply(ControlPatch(controlID: 1, operations: [
      .set(key: "_c", value: .string("Page")),
      .set(key: "disabled", value: .bool(true)),
      .set(key: "adaptive", value: .bool(true)),
      .set(key: "controls", value: .array([child]))
    ])))
    XCTAssertEqual(store.node(100)?.bool("disabled"), true)
    XCTAssertEqual(store.node(100)?.bool("adaptive"), true)

    XCTAssertTrue(store.apply(ControlPatch(controlID: 100, operations: [
      .set(key: "adaptive", value: .bool(false))
    ])))
    XCTAssertEqual(store.node(100)?.bool("adaptive"), false)
  }

  private func url(_ value: String) throws -> URL {
    try XCTUnwrap(URL(string: value))
  }
}
