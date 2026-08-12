import XCTest

import RufletEngine
import RufletPermissionHandler
import RufletProtocol

@MainActor
final class PermissionHandlerParityTests: XCTestCase {
  private final class Permissions: RufletPermissionHandling {
    var status: RufletPermissionStatus = .limited
    var requestedStatus: RufletPermissionStatus = .provisional
    var opened = false
    var calls: [String] = []

    func status(
      of permission: RufletPermissionKind,
      completion: @escaping (RufletPermissionStatus) -> Void
    ) {
      calls.append("status:\(permission.rawValue)")
      completion(status)
    }

    func request(
      _ permission: RufletPermissionKind,
      completion: @escaping (RufletPermissionStatus) -> Void
    ) {
      calls.append("request:\(permission.rawValue)")
      completion(requestedStatus)
    }

    func openAppSettings(completion: @escaping (Bool) -> Void) {
      calls.append("settings")
      completion(opened)
    }
  }

  private func invoke(
    _ service: PermissionHandlerService,
    _ name: String,
    args: RufletValue = .map([:])
  ) async -> Result<RufletValue, Error> {
    await withCheckedContinuation { continuation in
      service.invoke(
        RufletMethodCall(controlID: 7, callID: "test", name: name, args: args),
        node: ControlNode(id: 7, type: "PermissionHandler"),
        context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
      ) { continuation.resume(returning: $0) }
    }
  }

  func testPinnedPermissionNamesAndStatusNamesAreExact() {
    XCTAssertEqual(RufletPermissionKind.allCases.count, 39)
    XCTAssertEqual(
      FletPermissionHandlerSemantics.permission(.string("LOCATIONWHENINUSE")),
      .locationWhenInUse)
    XCTAssertNil(FletPermissionHandlerSemantics.permission(.string("location_when_in_use")))
    XCTAssertNil(FletPermissionHandlerSemantics.permission(.int(1)))
    XCTAssertEqual(
      FletPermissionHandlerSemantics.unsupportedStatus(requesting: false), .denied)
    XCTAssertEqual(
      FletPermissionHandlerSemantics.unsupportedStatus(requesting: true), .permanentlyDenied)
    XCTAssertEqual(RufletPermissionStatus.permanentlyDenied.rawValue, "permanentlyDenied")
    XCTAssertEqual(
      FletPermissionHandlerSemantics.status(for: .notDetermined), .denied)
    XCTAssertEqual(FletPermissionHandlerSemantics.status(for: .denied), .permanentlyDenied)
    XCTAssertEqual(FletPermissionHandlerSemantics.status(for: .restricted), .restricted)
    XCTAssertEqual(FletPermissionHandlerSemantics.status(for: .limited), .limited)
    XCTAssertEqual(FletPermissionHandlerSemantics.status(for: .provisional), .provisional)
  }

  func testPhotoPermissionsSelectPinnedAppleAccessDomains() {
    XCTAssertEqual(
      FletPermissionHandlerSemantics.photoPermissionUsesAddOnlyAccess(.photos), false)
    XCTAssertEqual(
      FletPermissionHandlerSemantics.photoPermissionUsesAddOnlyAccess(.photosAddOnly), true)
    XCTAssertNil(
      FletPermissionHandlerSemantics.photoPermissionUsesAddOnlyAccess(.camera))

    XCTAssertEqual(FletPermissionHandlerSemantics.status(for: .authorized), .granted)
    XCTAssertEqual(FletPermissionHandlerSemantics.status(for: .limited), .limited)
    XCTAssertEqual(FletPermissionHandlerSemantics.status(for: .denied), .permanentlyDenied)
  }

  func testGetStatusAndRequestUseCanonicalPermissionAndResultShapes() async throws {
    let permissions = Permissions()
    let service = PermissionHandlerService(permissions: permissions)

    let statusResult = await invoke(
      service, "get_status", args: .map(["permission": .string("Camera")]))
    XCTAssertEqual(try statusResult.get(), .string("limited"))
    let requestResult = await invoke(
      service, "request", args: .map(["permission": .string("photosAddOnly")]))
    XCTAssertEqual(try requestResult.get(), .string("provisional"))
    XCTAssertEqual(permissions.calls, ["status:camera", "request:photosAddOnly"])
  }

  func testUnknownOrMissingPermissionReturnsNullWithoutBackendCall() async throws {
    let permissions = Permissions()
    let service = PermissionHandlerService(permissions: permissions)

    let unknown = await invoke(
      service, "get_status", args: .map(["permission": .string("futurePermission")]))
    XCTAssertEqual(try unknown.get(), .null)
    let missing = await invoke(service, "request")
    XCTAssertEqual(try missing.get(), .null)
    XCTAssertTrue(permissions.calls.isEmpty)
  }

  func testOpenSettingsReturnsTheBackendBoolean() async throws {
    let permissions = Permissions()
    permissions.opened = true
    let result = await invoke(
      PermissionHandlerService(permissions: permissions), "open_app_settings")
    XCTAssertEqual(try result.get(), .bool(true))
    XCTAssertEqual(permissions.calls, ["settings"])
  }

  func testInventedAliasesAndUnknownMethodsFailStrictly() async {
    let service = PermissionHandlerService(permissions: Permissions())
    for method in ["check_permission", "request_permission", "get_service_status", "future"] {
      let result = await invoke(service, method)
      XCTAssertThrowsError(try result.get(), "\(method) must not be accepted")
    }
  }

  func testExtensionRegistersOnlyThePinnedServiceType() {
    let registry = ServiceRegistry()
    registry.register(extension: RufletPermissionHandler.self)
    XCTAssertTrue(registry.handles("PermissionHandler"))
    XCTAssertTrue(registry.hasExtension("RufletPermissionHandler"))
  }
}
