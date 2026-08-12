import RufletEngine
import RufletProtocol
import XCTest

final class AppleDeviceInfoParityTests: XCTestCase {
  @MainActor
  private func invokeDeviceInfo() -> Result<RufletValue, Error>? {
    let store = ControlStore()
    store.applyPageProperties([:])
    var reply: Result<RufletValue, Error>?
    PageService().invoke(
      RufletMethodCall(
        controlID: RufletWireID.page,
        callID: "device-info",
        name: "get_device_info",
        args: .map([:])),
      node: store.page,
      context: RufletServiceContext(store: store) { _, _, _ in }
    ) { reply = $0 }
    return reply
  }

  @MainActor
  func testPageReturnsExactPinnedAppleDeviceInfoSchema() throws {
    let value = try XCTUnwrap(invokeDeviceInfo()?.get().mapValue)
    #if canImport(UIKit)
      XCTAssertEqual(Set(value.keys), FletAppleDeviceInfoSemantics.iOSKeys)
      XCTAssertEqual(
        Set(value["utsname"]?.mapValue?.keys.map { $0 } ?? []),
        Set([
          "machine", "node_name", "release", "sys_name", "version",
        ]))
      XCTAssertNotNil(value["is_physical_device"]?.boolValue)
      XCTAssertNotNil(value["physical_ram_size"]?.intValue)
    #elseif os(macOS)
      XCTAssertEqual(Set(value.keys), FletAppleDeviceInfoSemantics.macOSKeys)
      XCTAssertFalse(value["arch"]?.stringValue?.isEmpty ?? true)
      XCTAssertFalse(value["model"]?.stringValue?.isEmpty ?? true)
      XCTAssertFalse(value["host_name"]?.stringValue?.isEmpty ?? true)
      XCTAssertNotNil(value["active_cpus"]?.intValue)
      XCTAssertNotNil(value["memory_size"]?.intValue)
      XCTAssertNotNil(value["major_version"]?.intValue)
      XCTAssertTrue(
        value["system_guid"]?.isNull == true
          || value["system_guid"]?.stringValue?.isEmpty == false)
    #endif

    XCTAssertNil(value["os"])
    XCTAssertNil(value["os_version"])
    XCTAssertNil(value["device_name"])
    XCTAssertNil(value["locale"])
    XCTAssertFalse(value["locales"]?.arrayValue?.isEmpty ?? true)
  }

  @MainActor
  func testLocalePayloadUsesFletLanguageCountryScriptShape() throws {
    let locales = try XCTUnwrap(
      FletAppleDeviceInfoSemantics.locales(["en-US", "zh-Hant-TW"]).arrayValue)
    XCTAssertEqual(locales.count, 2)
    XCTAssertEqual(
      Set(locales[0].mapValue?.keys.map { $0 } ?? []),
      Set([
        "language_code", "country_code", "script_code",
      ]))
    XCTAssertEqual(locales[0]["language_code"], .string("en"))
    XCTAssertEqual(locales[0]["country_code"], .string("US"))
    XCTAssertEqual(locales[0]["script_code"], .null)
    XCTAssertEqual(locales[1]["language_code"], .string("zh"))
    XCTAssertEqual(locales[1]["country_code"], .string("TW"))
    XCTAssertEqual(locales[1]["script_code"], .string("Hant"))
  }

  @MainActor
  func testPinnedCommercialModelMappingsAndUnknownDefaults() {
    XCTAssertEqual(
      FletAppleDeviceInfoSemantics.modelName(forMacIdentifier: "MacBookPro18,2"),
      "MacBook Pro (16-inch, 2021)")
    XCTAssertEqual(
      FletAppleDeviceInfoSemantics.modelName(forMacIdentifier: "future-mac"),
      "Unknown Model")
    XCTAssertEqual(
      FletAppleDeviceInfoSemantics.modelName(forIOSIdentifier: "iPhone17,1"),
      "iPhone 16 Pro")
    XCTAssertEqual(
      FletAppleDeviceInfoSemantics.modelName(forIOSIdentifier: "iPhone18,4"),
      "iPhone Air")
    XCTAssertEqual(
      FletAppleDeviceInfoSemantics.modelName(forIOSIdentifier: "future-ios-device"),
      "Unknown device")
  }
}
