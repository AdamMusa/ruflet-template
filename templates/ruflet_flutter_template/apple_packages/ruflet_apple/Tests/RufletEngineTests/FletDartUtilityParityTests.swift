import XCTest

@testable import RufletEngine
@testable import RufletProtocol

/// Literal translations of the executable tests in the vendored Flet ref:
///
/// - `flet/test/utils/control_test.dart`
/// - `flet/test/utils/networking_test.dart`
/// - `flet/test/utils/uri_test.dart`
/// - `flet/test/utils/user_fonts_test.dart`
///
/// Keep the fixtures and expectations aligned with Dart. Native-only edge
/// cases belong in their feature-specific test files instead.
@MainActor
final class FletDartUtilityParityTests: XCTestCase {
  // MARK: flet/test/utils/control_test.dart

  func testBothControlsMustBeEqual() {
    let backend = FletDartParityBackend()
    let properties: [String: RufletValue] = [
      "a": 1,
      "b": 2,
      "c": ["c_0": "test"],
    ]
    let first = RufletControl(
      id: 1, type: "Button", properties: properties, backend: backend)
    let second = RufletControl(
      id: 1, type: "Button", properties: properties, backend: backend)

    XCTAssertEqual(first, second)
  }

  func testUpdateControlWithAMap() {
    let control = makeControl(properties: [
      "a": 1,
      "b": 2,
      "c": ["c_0": "test"],
    ])

    let changed = control.update([
      "a": 10,
      "d": true,
      "c": ["c_0": "test_2", "sub_1": "something"],
    ])

    XCTAssertTrue(changed)
    XCTAssertEqual(control.value("a"), 10)
    XCTAssertEqual(control.value("b"), 2)
    XCTAssertEqual(control.value("d"), true)
    XCTAssertEqual(control.value("c")?["c_0"], "test_2")
    XCTAssertEqual(control.value("c")?["sub_1"], "something")
  }

  func testUpdateControlDidNotChangeControl() {
    let control = makeControl(properties: [
      "a": 1,
      "b": 2,
      "c": ["c_0": "test"],
    ])

    XCTAssertFalse(
      control.update([
        "a": 1,
        "b": 2,
        "c": ["c_0": "test"],
      ]))
  }

  func testUpdateControlOnFirstLevelChangedControl() {
    let control = makeControl(properties: ["a": 1])
    XCTAssertTrue(control.update(["a": 2]))
  }

  func testUpdateControlOnSecondLevelChangedControl() {
    let control = makeControl(properties: [
      "a": 1,
      "c": ["c_0": "test"],
    ])
    XCTAssertTrue(control.update(["c": ["c_0": "changed!"]]))
  }

  // MARK: flet/test/utils/networking_test.dart

  func testLocalhostAddressIsPrivate() async throws {
    let result = try await isPrivateHost("localhost")
    XCTAssertTrue(result)
  }

  func test1270011AddressIsPrivate() async throws {
    let result = try await isPrivateHost("127.0.1.1")
    XCTAssertTrue(result)
  }

  func test19216801AddressIsPrivate() async throws {
    let result = try await isPrivateHost("192.168.0.1")
    XCTAssertTrue(result)
  }

  func test17216010AddressIsPrivate() async throws {
    let result = try await isPrivateHost("172.16.0.10")
    XCTAssertTrue(result)
  }

  func test1005100AddressIsPrivate() async throws {
    let result = try await isPrivateHost("10.0.5.100")
    XCTAssertTrue(result)
  }

  func test216342201AddressIsPublic() async throws {
    let result = try await isPrivateHost("216.34.2.201")
    XCTAssertFalse(result)
  }

  func test45322AddressIsPublic() async throws {
    let result = try await isPrivateHost("45.3.2.2")
    XCTAssertFalse(result)
  }

  func testFlutterDevAddressIsPublic() async throws {
    let result = try await isPrivateHost("flutter.dev")
    XCTAssertFalse(result)
  }

  // MARK: flet/test/utils/uri_test.dart

  func testEmptyURICanBeParsed() throws {
    let components = try XCTUnwrap(URLComponents(string: ""))
    XCTAssertNil(components.host)
  }

  func testRelativeURICanBeParsed() throws {
    let components = try XCTUnwrap(URLComponents(string: "images/test.png"))
    XCTAssertNil(components.host)
  }

  func testGetWebPageNameReturnsCorrectNameFromURI() throws {
    XCTAssertEqual(getWebPageName(try url("http://localhost:8550/p/test/")), "p/test")
    XCTAssertEqual(getWebPageName(try url("http://localhost:8550/p/test")), "p/test")
    XCTAssertEqual(getWebPageName(try url("http://localhost:8550/aaa")), "aaa")
    XCTAssertEqual(getWebPageName(try url("http://localhost:8550/p/test/store")), "p/test")
    XCTAssertEqual(
      getWebPageName(try url("http://localhost:8550/p/test/store/products/1")),
      "p/test")
    XCTAssertEqual(getWebPageName(try url("http://localhost:8550/")), "")
    XCTAssertEqual(getWebPageName(try url("http://localhost:8550/#/")), "")
  }

  // MARK: flet/test/utils/user_fonts_test.dart

  func testCustomFontsAreParsedFromJSON() throws {
    let fonts = try XCTUnwrap(
      parseFonts([
        "font1": "https://fonts.com/font1.ttf",
        "font2": "https://fonts.com/font2.ttf",
      ]))

    XCTAssertEqual(fonts.count, 2)
    XCTAssertEqual(fonts["font1"], "https://fonts.com/font1.ttf")
    XCTAssertEqual(fonts["font2"], "https://fonts.com/font2.ttf")
  }

  func testPrimitiveAccessorsUseGeneratedPinnedFletDefaults() {
    let backend = FletDartParityBackend()
    let appBar = RufletControl(id: 2, type: "AppBar", properties: [:], backend: backend)
    let explicit = RufletControl(
      id: 3, type: "AppBar",
      properties: ["automatically_imply_leading": .bool(false)], backend: backend)
    let nulled = RufletControl(
      id: 4, type: "AppBar",
      properties: ["automatically_imply_leading": .null], backend: backend)

    XCTAssertTrue(appBar.boolean("automatically_imply_leading") == true)
    XCTAssertFalse(explicit.boolean("automatically_imply_leading") == true)
    XCTAssertTrue(nulled.boolean("automatically_imply_leading") == true)
    XCTAssertNil(appBar.value("automatically_imply_leading"), "raw wire access must stay raw")
  }

  private func makeControl(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "Button",
      properties: properties,
      backend: FletDartParityBackend())
  }

  private func url(_ value: String) throws -> URL {
    try XCTUnwrap(URL(string: value))
  }
}

@MainActor
private final class FletDartParityBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
