import RufletEngine
import RufletAudio
import RufletAudioRecorder
import RufletCamera
import RufletFlashlight
import RufletGeolocator
import RufletPermissionHandler
import RufletQRScanner
import RufletProtocol
import RufletSecureStorage
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
    XCTAssertEqual(mapping["flet_datatable2"], "RufletDataTable2")
    XCTAssertEqual(mapping["flet_color_pickers"], "RufletColorPickers")
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
    XCTAssertEqual(mapping.count, 19)
  }

  @MainActor
  func testCaptureExtensionsRegisterOnlyTheirOwnFletBoundary() {
    let audio = ServiceRegistry()
    audio.register(extension: RufletAudio.self)
    XCTAssertTrue(audio.hasExtension("RufletAudio"))
    XCTAssertTrue(audio.handles("Audio"))
    XCTAssertFalse(audio.handles("AudioRecorder"))
    XCTAssertFalse(audio.handles("Camera"))
    XCTAssertFalse(audio.handles("Flashlight"))

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

  @MainActor
  func testQRScannerExtensionOwnsOnlyItsVisualControlBoundary() {
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "QrcodeScanner")?.rendering,
      .optionalBundle("RufletQRScanner"))

    let registry = ServiceRegistry()
    registry.register(extension: RufletQRScanner.self)
    XCTAssertTrue(registry.hasExtension("RufletQRScanner"))
    XCTAssertFalse(registry.handles("Audio"))
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "QrcodeScanner")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "qrcode_scanner")?.implementation,
      "RufletQRScanner.QRScannerControlView")
  }

  func testCaptureExtensionManifestEntriesAreAvailable() {
    let packages = Dictionary(
      uniqueKeysWithValues: RufletExtensionManifest.packages.map {
        ($0.fletPackage, $0)
      })
    XCTAssertEqual(packages["flet_audio_recorder"]?.status, .available)
    XCTAssertEqual(packages["flet_audio"]?.status, .available)
    XCTAssertEqual(packages["flet_camera"]?.status, .available)
    XCTAssertEqual(packages["flet_flashlight"]?.status, .available)
    XCTAssertEqual(packages["ruflet_qrcode_scanner"]?.status, .available)
  }

  func testDedicatedServiceExtensionManifestEntriesAreAvailable() {
    let packages = Dictionary(
      uniqueKeysWithValues: RufletExtensionManifest.packages.map {
        ($0.fletPackage, $0)
      })
    XCTAssertEqual(packages["flet_geolocator"]?.status, .available)
    XCTAssertEqual(packages["flet_permission_handler"]?.status, .available)
    XCTAssertEqual(packages["flet_secure_storage"]?.status, .available)
  }

  func testDedicatedServiceExtensionsRegisterOnlyTheirOwnBoundary() {
    let geolocator = ServiceRegistry()
    geolocator.register(extension: RufletGeolocator.self)
    XCTAssertTrue(geolocator.hasExtension("RufletGeolocator"))
    XCTAssertTrue(geolocator.handles("Geolocator"))
    XCTAssertFalse(geolocator.handles("PermissionHandler"))
    XCTAssertFalse(geolocator.handles("SecureStorage"))

    let permission = ServiceRegistry()
    permission.register(extension: RufletPermissionHandler.self)
    XCTAssertTrue(permission.hasExtension("RufletPermissionHandler"))
    XCTAssertTrue(permission.handles("PermissionHandler"))
    XCTAssertFalse(permission.handles("Geolocator"))
    XCTAssertFalse(permission.handles("SecureStorage"))

    let storage = ServiceRegistry()
    storage.register(extension: RufletSecureStorage.self)
    XCTAssertTrue(storage.hasExtension("RufletSecureStorage"))
    XCTAssertTrue(storage.handles("SecureStorage"))
    XCTAssertFalse(storage.handles("Geolocator"))
    XCTAssertFalse(storage.handles("PermissionHandler"))
  }

  func testCoreOmitsDedicatedServicesAndNamesTheirProducts() {
    let core = ServiceRegistry()
    core.registerDefaults()
    XCTAssertFalse(core.handles("Geolocator"))
    XCTAssertFalse(core.handles("PermissionHandler"))
    XCTAssertFalse(core.handles("SecureStorage"))
    XCTAssertEqual(ServiceRegistry.bundleProviding("Geolocator"), "RufletGeolocator")
    XCTAssertEqual(
      ServiceRegistry.bundleProviding("PermissionHandler"), "RufletPermissionHandler")
    XCTAssertEqual(ServiceRegistry.bundleProviding("SecureStorage"), "RufletSecureStorage")
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
      .optionalBundle("RufletQRScanner"))
  }

  func testMissingServiceErrorsNameTheDedicatedProducts() {
    XCTAssertEqual(
      ServiceRegistry.bundleProviding("AudioRecorder"), "RufletAudioRecorder")
    XCTAssertEqual(ServiceRegistry.bundleProviding("Camera"), "RufletCamera")
    XCTAssertEqual(ServiceRegistry.bundleProviding("Flashlight"), "RufletFlashlight")
    XCTAssertEqual(ServiceRegistry.bundleProviding("Audio"), "RufletAudio")
    XCTAssertEqual(ServiceRegistry.bundleProviding("Geolocator"), "RufletGeolocator")
    XCTAssertEqual(
      ServiceRegistry.bundleProviding("PermissionHandler"), "RufletPermissionHandler")
    XCTAssertEqual(ServiceRegistry.bundleProviding("SecureStorage"), "RufletSecureStorage")
  }
}
