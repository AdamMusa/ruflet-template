@testable import RufletFlashlight
import RufletEngine
import RufletProtocol
import XCTest

final class FlashlightPluginParityTests: XCTestCase {
  @MainActor
  private final class RecordingBackend: RufletFlashlightBackend {
    var hasCaptureDevice: Bool
    var hasTorch: Bool
    var states: [Bool] = []
    var error: Error?

    init(hasCaptureDevice: Bool, hasTorch: Bool) {
      self.hasCaptureDevice = hasCaptureDevice
      self.hasTorch = hasTorch
    }

    func setTorchEnabled(_ enabled: Bool) throws {
      if let error { throw error }
      states.append(enabled)
    }
  }

  private struct BusyCamera: LocalizedError {
    var errorDescription: String? { "camera is already in use" }
  }

  @MainActor
  private func invoke(
    _ service: FlashlightService,
    method: String
  ) -> Result<RufletValue, Error>? {
    var reply: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: 7, callID: "test", name: method, args: .map([:])),
      node: ControlNode(id: 7, type: "Flashlight"),
      context: RufletServiceContext(store: ControlStore()) { _, _, _ in }
    ) { reply = $0 }
    return reply
  }

  @MainActor
  func testAvailabilityDistinguishesMissingCameraFromCameraWithoutTorch() throws {
    let missing = RecordingBackend(hasCaptureDevice: false, hasTorch: false)
    guard case .failure(let missingError)? = invoke(
      FlashlightService(platform: .iOS, backend: missing), method: "is_available"),
      case .failed = missingError as? RufletServiceError
    else { return XCTFail("a missing video device must preserve the plugin error") }

    let noTorch = RecordingBackend(hasCaptureDevice: true, hasTorch: false)
    XCTAssertEqual(
      try invoke(
        FlashlightService(platform: .iOS, backend: noTorch),
        method: "is_available")?.get(),
      .bool(false))

    let available = RecordingBackend(hasCaptureDevice: true, hasTorch: true)
    XCTAssertEqual(
      try invoke(
        FlashlightService(platform: .iOS, backend: available),
        method: "is_available")?.get(),
      .bool(true))
  }

  @MainActor
  func testOnAndOffReturnVoidAndDriveTheNativeTorch() throws {
    let backend = RecordingBackend(hasCaptureDevice: true, hasTorch: true)
    let service = FlashlightService(platform: .iOS, backend: backend)

    XCTAssertEqual(try invoke(service, method: "on")?.get(), .null)
    XCTAssertEqual(try invoke(service, method: "off")?.get(), .null)
    XCTAssertEqual(backend.states, [true, false])
  }

  @MainActor
  func testTorchAbsenceAndConfigurationContentionRemainFailures() {
    let noTorch = RecordingBackend(hasCaptureDevice: true, hasTorch: false)
    guard case .failure(let unavailable)? = invoke(
      FlashlightService(platform: .iOS, backend: noTorch), method: "on"),
      case .unavailable("Torch is not available") = unavailable as? RufletServiceError
    else { return XCTFail("a camera without torch must be unavailable") }

    let busy = RecordingBackend(hasCaptureDevice: true, hasTorch: true)
    busy.error = BusyCamera()
    guard case .failure(let failure)? = invoke(
      FlashlightService(platform: .iOS, backend: busy), method: "off"),
      case .failed(let message) = failure as? RufletServiceError
    else { return XCTFail("configuration contention must remain a failed command") }
    XCTAssertTrue(message.contains("camera is already in use"))
  }

  @MainActor
  func testUnknownMethodAndNonMobilePlatformFollowFletDispatchOrder() {
    let backend = RecordingBackend(hasCaptureDevice: true, hasTorch: true)
    guard case .failure(let unknown)? = invoke(
      FlashlightService(platform: .iOS, backend: backend), method: "toggle"),
      case .unsupportedMethod("Flashlight", "toggle") = unknown as? RufletServiceError
    else { return XCTFail("unknown iOS methods must be classified at the wire boundary") }

    for method in ["on", "off", "is_available", "toggle"] {
      guard case .failure(let error)? = invoke(
        FlashlightService(platform: .unsupported, backend: backend), method: method),
        case .platformUnsupported("Flashlight", method, "Apple non-mobile") =
          error as? RufletServiceError
      else { return XCTFail("\(method) must be rejected before dispatch on non-mobile Apple") }
    }
  }

  @MainActor
  func testFlashlightRemainsAnIndependentOptionalExtension() {
    let registry = ServiceRegistry()
    XCTAssertFalse(registry.handles("Flashlight"))
    registry.register(extension: RufletFlashlight.self)
    XCTAssertTrue(registry.hasExtension("RufletFlashlight"))
    XCTAssertTrue(registry.handles("Flashlight"))
  }
}
