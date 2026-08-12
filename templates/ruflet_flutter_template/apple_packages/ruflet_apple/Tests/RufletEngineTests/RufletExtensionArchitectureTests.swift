import RufletEngine
import RufletProtocol
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
}
