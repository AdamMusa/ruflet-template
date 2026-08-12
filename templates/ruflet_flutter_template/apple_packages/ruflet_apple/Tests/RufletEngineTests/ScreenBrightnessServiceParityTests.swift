import XCTest

import RufletEngine
import RufletProtocol

final class ScreenBrightnessServiceParityTests: XCTestCase {
  @MainActor
  private func invoke(
    _ service: ScreenBrightnessService,
    _ method: String,
    args: RufletValue = .map([:])
  ) -> Result<RufletValue, Error>? {
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: 1, callID: "test", name: method, args: args),
      node: ControlNode(id: 1, type: "ScreenBrightness"),
      context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
    ) { result = $0 }
    return result
  }

  func testBrightnessEventUsesExactFletPayload() {
    XCTAssertEqual(
      FletDeviceServiceSemantics.brightnessEvent(0.625),
      .map(["brightness": .double(0.625)]))
  }

  func testBrightnessValidationMatchesPlatformInterfaceRange() {
    XCTAssertEqual(try? FletDeviceServiceSemantics.validatedBrightness(.int(1)), 1)
    XCTAssertEqual(try? FletDeviceServiceSemantics.validatedBrightness(.double(0.25)), 0.25)
    XCTAssertThrowsError(try FletDeviceServiceSemantics.validatedBrightness(nil))
    XCTAssertThrowsError(try FletDeviceServiceSemantics.validatedBrightness(.double(-0.01)))
    XCTAssertThrowsError(try FletDeviceServiceSemantics.validatedBrightness(.double(1.01)))
  }

  @MainActor
  func testAnimateAndAutoResetDefaultsAndCommandsMatchFlet() throws {
    let service = ScreenBrightnessService()
    XCTAssertEqual(try invoke(service, "is_animate")?.get(), .bool(true))
    XCTAssertEqual(try invoke(service, "is_auto_reset")?.get(), .bool(true))

    XCTAssertEqual(
      try invoke(service, "set_animate", args: .map(["value": .bool(false)]))?.get(), .null)
    XCTAssertEqual(try invoke(service, "is_animate")?.get(), .bool(false))
    XCTAssertEqual(
      try invoke(service, "set_auto_reset", args: .map(["value": .bool(false)]))?.get(),
      .null)
    XCTAssertEqual(try invoke(service, "is_auto_reset")?.get(), .bool(false))
  }

  @MainActor
  func testBooleanCommandsRequireValueAndUnknownMethodsFail() {
    let service = ScreenBrightnessService()
    XCTAssertThrowsError(try invoke(service, "set_animate")?.get())
    XCTAssertThrowsError(try invoke(service, "set_auto_reset")?.get())
    XCTAssertThrowsError(try invoke(service, "future_method")?.get())
  }

  @MainActor
  func testAppleAdapterAdvertisesSystemBrightnessCapability() throws {
    #if os(iOS) || os(macOS)
      XCTAssertEqual(
        try invoke(ScreenBrightnessService(), "can_change_system_screen_brightness")?.get(),
        .bool(true))
    #endif
  }
}
