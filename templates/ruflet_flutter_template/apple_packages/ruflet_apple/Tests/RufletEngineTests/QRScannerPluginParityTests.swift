import RufletEngine
@testable import RufletMedia
import RufletProtocol
@testable import RufletUI
import XCTest

/// Direct translations of the pinned `ruflet_qrcode_scanner` Dart tests,
/// followed by executable checks for the remaining public plug-in contract.
final class QRScannerPluginParityTests: XCTestCase {
  func testParsesScannerEnumsUsingRubySnakeCaseNames() {
    XCTAssertEqual(QRScannerConfiguration.parseCameraFacing("front"), .front)
    XCTAssertEqual(QRScannerConfiguration.parseCameraFacing("unknown"), .back)
    XCTAssertEqual(QRScannerConfiguration.parseDetectionSpeed("no_duplicates"), .noDuplicates)
    XCTAssertEqual(QRScannerConfiguration.parseDetectionSpeed("unrestricted"), .unrestricted)
  }

  func testFiltersAndDeduplicatesBarcodeFormats() {
    XCTAssertEqual(
      QRScannerConfiguration.parseFormats([
        .string("qr_code"), .string("data_matrix"), .string("qrCode"),
        .string("not_a_format")
      ]),
      [.qrCode, .dataMatrix])
  }

  func testParsesScanWindowsFromBothSupportedHashShapes() {
    XCTAssertEqual(
      QRScannerConfiguration.parseScanWindow(.map([
        "left": 10, "top": 20, "right": 110, "bottom": 220
      ])),
      QRScannerRect(x: 10, y: 20, width: 100, height: 200))
    XCTAssertEqual(
      QRScannerConfiguration.parseScanWindow(.map([
        "x": 10, "y": 20, "width": 100, "height": 200
      ])),
      QRScannerRect(x: 10, y: 20, width: 100, height: 200))
  }

  func testCreatesScannerForNormalizedAndLegacyWireTypes() throws {
    let normalized = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "QrcodeScanner"))
    let legacy = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "qrcode_scanner"))
    XCTAssertEqual(normalized.classification, .visible)
    XCTAssertEqual(legacy.classification, .visible)
    XCTAssertEqual(normalized.rendering, .optionalBundle("RufletMedia"))
    XCTAssertEqual(legacy.rendering, .optionalBundle("RufletMedia"))
  }

  func testConfigurationUsesPinnedMobileScannerDefaults() {
    let configuration = QRScannerConfiguration(
      node: ControlNode(id: 1, type: "qrcode_scanner"))
    XCTAssertTrue(configuration.autoStart)
    XCTAssertFalse(configuration.autoZoom)
    XCTAssertEqual(configuration.cameraFacing, .back)
    XCTAssertEqual(configuration.detectionSpeed, .normal)
    XCTAssertEqual(configuration.detectionTimeoutMilliseconds, 250)
    XCTAssertEqual(configuration.fit, "cover")
    XCTAssertEqual(configuration.formats, [])
    XCTAssertFalse(configuration.invertImage)
    XCTAssertFalse(configuration.returnImage)
    XCTAssertNil(configuration.scanWindow)
    XCTAssertFalse(configuration.tapToFocus)
    XCTAssertFalse(configuration.torchEnabled)
    XCTAssertEqual(configuration.zoomScale, 1)
  }

  func testDescriptorDeclaresEveryPinnedEventAndMethod() throws {
    let descriptor = try XCTUnwrap(
      ControlRegistry.builtInDescriptor(for: "qrcode_scanner"))
    XCTAssertEqual(descriptor.supportedEvents, ["detect", "error"])
    XCTAssertEqual(descriptor.supportedMethods, [
      "reset_zoom_scale", "set_zoom_scale", "start", "stop",
      "switch_camera", "toggle_torch"
    ])
  }

  @MainActor
  func testMediaBundleReplacesBothFallbacksWithNativeViews() {
    RufletMedia.register(in: ServiceRegistry())
    XCTAssertEqual(ControlRegistry.descriptor(for: "QrcodeScanner")?.rendering, .nativeView)
    XCTAssertEqual(ControlRegistry.descriptor(for: "qrcode_scanner")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "QrcodeScanner")?.implementation,
      "RufletMedia.QRScannerControlView")
  }
}
