import RufletEngine
import RufletProtocol
@testable import RufletSecureStorage
import Security
import XCTest

@MainActor
final class SecureStorageExtensionParityTests: XCTestCase {
  private func invoke(
    _ service: SecureStorageService,
    _ method: String,
    args: RufletValue = .map([:]),
    node: ControlNode? = nil
  ) -> Result<RufletValue, Error>? {
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: node?.id ?? 1, callID: "secure-test", name: method, args: args),
      node: node,
      context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
    ) { result = $0 }
    return result
  }

  func testCupertinoOptionParserMatchesVendoredFletDefaultsAndFields() throws {
    let defaults = AppleSecureStorageOptions(nil)
    XCTAssertEqual(defaults.accessibility, "unlocked")
    XCTAssertFalse(defaults.synchronizable)
    XCTAssertFalse(defaults.shouldReturnPersistentReference)
    XCTAssertTrue(defaults.usesDataProtectionKeychain)
    XCTAssertTrue(defaults.accessControlFlags.isEmpty)

    let options = AppleSecureStorageOptions(.map([
      "account_name": .string("account"),
      "group_id": .string("group"),
      "accessibility": .string("first_unlock_this_device"),
      "synchronizable": .bool(true),
      "label": .string("Label"),
      "description": .string("Description"),
      "comment": .string("Comment"),
      "is_invisible": .bool(true),
      "is_negative": .bool(false),
      "creation_date": .string("2026-08-11T12:00:00Z"),
      "last_modified_date": .double(1_700_000_000),
      "result_limit": .int(4),
      "is_persistent": .bool(true),
      "auth_ui_behavior": .string("fail"),
      "access_control_flags": .array([
        .string("user_presence"), .string("device_passcode"),
      ]),
      "uses_data_protection_keychain": .bool(false),
    ]))

    XCTAssertEqual(options.accountName, "account")
    XCTAssertEqual(options.groupID, "group")
    XCTAssertEqual(options.accessibility, "first_unlock_this_device")
    XCTAssertTrue(options.synchronizable)
    XCTAssertEqual(options.label, "Label")
    XCTAssertEqual(options.itemDescription, "Description")
    XCTAssertEqual(options.comment, "Comment")
    XCTAssertEqual(options.isInvisible, true)
    XCTAssertEqual(options.isNegative, false)
    XCTAssertNotNil(options.creationDate)
    XCTAssertEqual(options.lastModifiedDate, Date(timeIntervalSince1970: 1_700_000_000))
    XCTAssertEqual(options.resultLimit, 4)
    XCTAssertTrue(options.shouldReturnPersistentReference)
    XCTAssertEqual(options.authenticationUIBehavior, "fail")
    XCTAssertEqual(options.accessControlFlags, ["user_presence", "device_passcode"])
    XCTAssertFalse(options.usesDataProtectionKeychain)
  }

  func testMethodOptionsOverrideControlOptionsOnlyWhenPresent() {
    let service = SecureStorageService()
    #if os(macOS)
      let property = "macos_options"
      let argument = "macos"
    #else
      let property = "ios_options"
      let argument = "ios"
    #endif
    let node = ControlNode(
      id: 7, type: "SecureStorage",
      props: [property: .map(["account_name": .string("control-account")])])

    let inherited = service.resolvedAppleOptions(
      for: RufletMethodCall(controlID: 7, callID: "a", name: "get", args: .map([:])),
      node: node)
    XCTAssertEqual(inherited.accountName, "control-account")

    let overridden = service.resolvedAppleOptions(
      for: RufletMethodCall(
        controlID: 7, callID: "b", name: "get",
        args: .map([argument: .map(["account_name": .string("method-account")])])),
      node: node)
    XCTAssertEqual(overridden.accountName, "method-account")
  }

  func testVoidMethodsAndAvailabilityUseFletResultShapes() throws {
    let service = SecureStorageService()
    XCTAssertEqual(
      try SecureStorageService.voidMutationResult(
        status: errSecSuccess, missingIsSuccess: false).get(),
      .null)
    XCTAssertEqual(
      try SecureStorageService.voidMutationResult(
        status: errSecItemNotFound, missingIsSuccess: true).get(),
      .null)
    XCTAssertThrowsError(
      try SecureStorageService.voidMutationResult(
        status: errSecItemNotFound, missingIsSuccess: false).get())

    let availability = try invoke(service, "get_availability")?.get()
    XCTAssertNotNil(availability?.boolValue)
  }
}
