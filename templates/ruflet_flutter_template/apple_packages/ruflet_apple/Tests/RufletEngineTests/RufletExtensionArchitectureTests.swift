import RufletEngine
import RufletAudioRecorder
import RufletCamera
import RufletFlashlight
import RufletProtocol
@testable import RufletUI
import XCTest

@MainActor
final class RufletExtensionArchitectureTests: XCTestCase {
  private enum ExampleExtension: RufletExtension {
    static let extensionName = "Example"
    static var registrations = 0

    static func register(in registry: ServiceRegistry) {
      registrations += 1
      registry.registerNamed("ExampleService") { ExampleService() }
    }
  }

  private final class ExampleService: RufletService {
    static let wireType = "ExampleService"
    func invoke(
      _ call: RufletMethodCall, node: ControlNode?, context: RufletServiceContext,
      completion: @escaping RufletMethodCompletion
    ) {
      completion(.success(.null))
    }
  }

  override func setUp() {
    ExampleExtension.registrations = 0
  }

  func testExtensionRegistrationIsIdempotentPerSessionRegistry() {
    let registry = ServiceRegistry()
    registry.register(extensions: [ExampleExtension.self, ExampleExtension.self])

    XCTAssertEqual(ExampleExtension.registrations, 1)
    XCTAssertTrue(registry.hasExtension("Example"))
    XCTAssertTrue(registry.handles("ExampleService"))
  }

  func testManifestMirrorsEveryRequiredVendoredFletExtensionBoundary() {
    let mapping = Dictionary(
      uniqueKeysWithValues: RufletExtensionManifest.packages.map {
        ($0.fletPackage, $0.swiftProduct)
      })
    XCTAssertEqual(mapping["flet_audio"], "RufletAudio")
    XCTAssertEqual(mapping["flet_audio_recorder"], "RufletAudioRecorder")
    XCTAssertEqual(mapping["flet_camera"], "RufletCamera")
    XCTAssertEqual(mapping["flet_charts"], "RufletCharts")
    XCTAssertEqual(mapping["flet_code_editor"], "RufletCodeEditor")
    XCTAssertEqual(mapping["flet_flashlight"], "RufletFlashlight")
    XCTAssertEqual(mapping["flet_geolocator"], "RufletGeolocator")
    XCTAssertEqual(mapping["flet_lottie"], "RufletLottie")
    XCTAssertEqual(mapping["flet_map"], "RufletMap")
    XCTAssertEqual(mapping["flet_permission_handler"], "RufletPermissionHandler")
    XCTAssertEqual(mapping["flet_rive"], "RufletRive")
    XCTAssertEqual(mapping["flet_secure_storage"], "RufletSecureStorage")
    XCTAssertEqual(mapping["flet_spinkit"], "RufletSpinKit")
    XCTAssertEqual(mapping["flet_video"], "RufletVideo")
    XCTAssertEqual(mapping["flet_webview"], "RufletWebView")
    XCTAssertEqual(mapping["ruflet_qrcode_scanner"], "RufletQRScanner")
    XCTAssertEqual(mapping.count, 16)
  }

  @MainActor
  func testCaptureExtensionsRegisterOnlyTheirOwnFletBoundary() {
    let recorder = ServiceRegistry()
    recorder.register(extension: RufletAudioRecorder.self)
    XCTAssertTrue(recorder.hasExtension("RufletAudioRecorder"))
    XCTAssertTrue(recorder.handles("AudioRecorder"))
    XCTAssertFalse(recorder.handles("Audio"))
    XCTAssertFalse(recorder.handles("Camera"))
    XCTAssertFalse(recorder.handles("Flashlight"))

    let camera = ServiceRegistry()
    camera.register(extension: RufletCamera.self)
    XCTAssertTrue(camera.hasExtension("RufletCamera"))
    XCTAssertTrue(camera.handles("Camera"))
    XCTAssertFalse(camera.handles("Audio"))
    XCTAssertFalse(camera.handles("AudioRecorder"))
    XCTAssertFalse(camera.handles("Flashlight"))

    let flashlight = ServiceRegistry()
    flashlight.register(extension: RufletFlashlight.self)
    XCTAssertTrue(flashlight.hasExtension("RufletFlashlight"))
    XCTAssertTrue(flashlight.handles("Flashlight"))
    XCTAssertFalse(flashlight.handles("Audio"))
    XCTAssertFalse(flashlight.handles("AudioRecorder"))
    XCTAssertFalse(flashlight.handles("Camera"))
  }

  func testCaptureExtensionManifestEntriesAreAvailable() {
    let packages = Dictionary(
      uniqueKeysWithValues: RufletExtensionManifest.packages.map {
        ($0.fletPackage, $0)
      })
    XCTAssertEqual(packages["flet_audio_recorder"]?.status, .available)
    XCTAssertEqual(packages["flet_camera"]?.status, .available)
    XCTAssertEqual(packages["flet_flashlight"]?.status, .available)
  }

  @MainActor
  func testCameraExtensionReplacesOnlyTheCameraFallbackDescriptor() {
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "Camera")?.rendering,
      .optionalBundle("RufletCamera"))

    let registry = ServiceRegistry()
    registry.register(extension: RufletCamera.self)
    XCTAssertEqual(ControlRegistry.descriptor(for: "Camera")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Camera")?.implementation,
      "RufletCamera.CameraControlView")
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "QrcodeScanner")?.rendering,
      .optionalBundle("RufletMedia"))
  }

  func testMissingServiceErrorsNameTheDedicatedProducts() {
    XCTAssertEqual(
      ServiceRegistry.bundleProviding("AudioRecorder"), "RufletAudioRecorder")
    XCTAssertEqual(ServiceRegistry.bundleProviding("Camera"), "RufletCamera")
    XCTAssertEqual(ServiceRegistry.bundleProviding("Flashlight"), "RufletFlashlight")
    XCTAssertEqual(ServiceRegistry.bundleProviding("Audio"), "RufletMedia")
  }
}
