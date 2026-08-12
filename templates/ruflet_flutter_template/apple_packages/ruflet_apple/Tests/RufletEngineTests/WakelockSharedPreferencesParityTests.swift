import Foundation
import RufletEngine
import RufletProtocol
import XCTest

final class WakelockSharedPreferencesParityTests: XCTestCase {
  private func call(_ method: String, _ args: [String: RufletValue] = [:])
    -> RufletMethodCall
  {
    RufletMethodCall(controlID: 1, callID: "test", name: method, args: .map(args))
  }

  @MainActor
  private func invoke(
    _ service: RufletService, method: String, args: [String: RufletValue] = [:]
  ) -> Result<RufletValue, Error>? {
    var result: Result<RufletValue, Error>?
    service.invoke(
      call(method, args), node: nil,
      context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
    ) { result = $0 }
    return result
  }

  func testSharedPreferencesMethodsAndAppleNamespaceMatchPinnedFlet() throws {
    XCTAssertEqual(
      Set(FletSharedPreferencesSemantics.Method.allCases.map(\.rawValue)),
      ["set", "get", "contains_key", "get_keys", "remove", "clear"])
    XCTAssertEqual(FletSharedPreferencesSemantics.storagePrefix, "flutter.")
    XCTAssertEqual(FletSharedPreferencesSemantics.storageKey("theme"), "flutter.theme")
    XCTAssertThrowsError(try FletSharedPreferencesSemantics.method("keys"))
  }

  func testSharedPreferencesRequiresExactStringKeysValuesAndPrefixes() throws {
    XCTAssertEqual(
      try FletSharedPreferencesSemantics.requiredString(.string(""), name: "key"), "")
    XCTAssertThrowsError(try FletSharedPreferencesSemantics.requiredString(nil, name: "key"))
    XCTAssertThrowsError(
      try FletSharedPreferencesSemantics.requiredString(.int(7), name: "value"))
  }

  func testVisibleKeysStripOnlyTheSharedPreferencesPluginNamespace() {
    XCTAssertEqual(
      Set(FletSharedPreferencesSemantics.visibleKeys(
        ["flutter.app.theme", "flutter.app.locale", "flutter.other", "host"],
        prefix: "app.")),
      ["app.theme", "app.locale"])
  }

  @MainActor
  func testSharedPreferencesPersistWithExactReturnShapes() throws {
    let suite = "ruflet.shared-preferences.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("host-value", forKey: "host.key")
    let service = SharedPreferencesService(defaults: defaults)

    XCTAssertEqual(try invoke(service, method: "set", args: [
      "key": .string("app.theme"), "value": .string("")
    ])?.get(), .bool(true))
    XCTAssertEqual(try invoke(service, method: "get", args: [
      "key": .string("app.theme")
    ])?.get(), .string(""))
    XCTAssertEqual(try invoke(service, method: "contains_key", args: [
      "key": .string("app.theme")
    ])?.get(), .bool(true))
    XCTAssertEqual(Set(try XCTUnwrap(invoke(service, method: "get_keys", args: [
      "key_prefix": .string("app.")
    ])?.get().arrayValue?.compactMap(\.stringValue))), ["app.theme"])

    XCTAssertEqual(try invoke(service, method: "clear")?.get(), .bool(true))
    XCTAssertEqual(try invoke(service, method: "get", args: [
      "key": .string("app.theme")
    ])?.get(), .null)
    XCTAssertEqual(defaults.string(forKey: "host.key"), "host-value")
  }

  @MainActor
  func testSharedPreferencesRejectsMalformedWireValues() {
    let service = SharedPreferencesService()
    for (method, args) in [
      ("set", ["key": RufletValue.int(1), "value": .string("v")]),
      ("set", ["key": RufletValue.string("k"), "value": .int(1)]),
      ("get", ["key": RufletValue.bool(true)]),
      ("get_keys", [:]),
    ] {
      guard case .failure(let error)? = invoke(service, method: method, args: args) else {
        return XCTFail("\(method) should reject malformed args")
      }
      guard case .invalidArguments = error as? RufletServiceError else {
        return XCTFail("unexpected error: \(error)")
      }
    }
  }

  func testWakelockMethodsAndIdempotentStateTransitionsMatchFlet() throws {
    XCTAssertEqual(
      Set(FletWakelockSemantics.Method.allCases.map(\.rawValue)),
      ["enable", "disable", "is_enabled"])
    XCTAssertTrue(FletWakelockSemantics.nextEnabledState(current: false, method: .enable))
    XCTAssertTrue(FletWakelockSemantics.nextEnabledState(current: true, method: .enable))
    XCTAssertFalse(FletWakelockSemantics.nextEnabledState(current: true, method: .disable))
    XCTAssertTrue(FletWakelockSemantics.nextEnabledState(current: true, method: .isEnabled))
    XCTAssertThrowsError(try FletWakelockSemantics.method("toggle"))
  }

  @MainActor
  func testUnknownWakelockMethodFailsOnEveryApplePlatform() {
    guard case .failure(let error)? = invoke(WakelockService(), method: "toggle") else {
      return XCTFail("unknown wakelock method must fail")
    }
    XCTAssertEqual(
      error as? RufletServiceError,
      .unsupportedMethod(type: "Wakelock", method: "toggle"))
  }
}
