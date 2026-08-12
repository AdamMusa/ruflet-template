import RufletEngine
@testable import RufletQRScanner
import RufletProtocol
@testable import RufletUI
import Vision
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

  func testDarwinPayloadTypeHeuristicMatchesPinnedMobileScanner() {
    XCTAssertEqual(QRScannerBarcodeType.detect(nil), .unknown)
    XCTAssertEqual(QRScannerBarcodeType.detect("BEGIN:VCARD\nFN:Ada"), .contactInfo)
    XCTAssertEqual(QRScannerBarcodeType.detect("WIFI:T:WPA;S:Ruflet;;"), .wifi)
    XCTAssertEqual(QRScannerBarcodeType.detect("https://flet.dev"), .url)
    XCTAssertEqual(QRScannerBarcodeType.detect("978-1-4028-9462-6"), .isbn)
    XCTAssertEqual(QRScannerBarcodeType.detect("012345678905"), .product)
    XCTAssertEqual(QRScannerBarcodeType.detect("plain text"), .text)
  }

  func testVisionCoordinatesMatchPinnedDarwinPixelTransform() {
    let corners = QRScannerVisionBarcode.pixelCorners(
      topLeft: CGPoint(x: 0.1, y: 0.9),
      topRight: CGPoint(x: 0.4, y: 0.9),
      bottomRight: CGPoint(x: 0.4, y: 0.5),
      bottomLeft: CGPoint(x: 0.1, y: 0.5),
      imageWidth: 1_000, imageHeight: 500,
      scanWindow: CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.8))
    #if os(macOS)
    let expected = [
      CGPoint(x: 400, y: 90), CGPoint(x: 250, y: 90),
      CGPoint(x: 250, y: 250), CGPoint(x: 400, y: 250)
    ]
    #else
    let expected = [
      CGPoint(x: 250, y: 90), CGPoint(x: 400, y: 90),
      CGPoint(x: 400, y: 250), CGPoint(x: 250, y: 250)
    ]
    #endif
    XCTAssertEqual(corners.count, expected.count)
    for (actual, expected) in zip(corners, expected) {
      XCTAssertEqual(actual.x, expected.x, accuracy: 0.000_001)
      XCTAssertEqual(actual.y, expected.y, accuracy: 0.000_001)
    }
  }

  func testVisionFormatNamesMatchDartBarcodeFormatNames() {
    XCTAssertEqual(QRScannerVisionBarcode.formatName(.qr), "qrCode")
    XCTAssertEqual(QRScannerVisionBarcode.formatName(.i2of5), "itf2of5")
    XCTAssertEqual(QRScannerVisionBarcode.formatName(.i2of5Checksum), "itf2of5WithChecksum")
    XCTAssertEqual(QRScannerVisionBarcode.formatName(.itf14), "itf14")
    if #available(iOS 15, macOS 12, *) {
      XCTAssertEqual(QRScannerVisionBarcode.formatName(.gs1DataBarExpanded), "dataBarExpanded")
    }
  }

  @MainActor
  func testVisionSymbologyFilterPreservesSupportedPinnedFormats() {
    let formats = QRScannerModel.visionSymbologies([
      .qrCode, .dataMatrix, .itf2of5WithChecksum, .maxiCode, .microQrCode
    ])
    XCTAssertEqual(formats, [.qr, .dataMatrix, .i2of5Checksum])
  }

  func testPlatformCapabilitiesClassifyDarwinDifferencesExplicitly() {
    #if os(iOS)
    XCTAssertTrue(QRScannerPlatformCapabilities.zoom)
    XCTAssertTrue(QRScannerPlatformCapabilities.tapToFocus)
    #else
    XCTAssertFalse(QRScannerPlatformCapabilities.zoom)
    XCTAssertFalse(QRScannerPlatformCapabilities.tapToFocus)
    #endif
  }

  func testNoDuplicatesComparesTheSortedCurrentCaptureRatherThanAllHistory() {
    var state = QRScannerDetectionState()

    XCTAssertTrue(state.accepts(["two", "one"], speed: .noDuplicates))
    XCTAssertFalse(state.accepts(["one", "two"], speed: .noDuplicates))
    XCTAssertTrue(state.accepts(["three"], speed: .noDuplicates))
    XCTAssertTrue(state.accepts(["one", "two"], speed: .noDuplicates))
    XCTAssertTrue(state.accepts(["one", "two"], speed: .normal))
  }

  func testNoDuplicatesDoesNotRecordNilOnlyCaptures() {
    var state = QRScannerDetectionState()

    XCTAssertTrue(state.accepts([nil], speed: .noDuplicates))
    XCTAssertTrue(state.accepts([nil], speed: .noDuplicates))
    XCTAssertNil(state.lastScanned)
  }

  func testOnlyNormalDetectionUsesTheConfiguredTimeout() {
    XCTAssertTrue(QRScannerDetectionState.shouldThrottle(
      speed: .normal, elapsedMilliseconds: 249, timeoutMilliseconds: 250))
    XCTAssertFalse(QRScannerDetectionState.shouldThrottle(
      speed: .normal, elapsedMilliseconds: 250, timeoutMilliseconds: 250))
    XCTAssertFalse(QRScannerDetectionState.shouldThrottle(
      speed: .noDuplicates, elapsedMilliseconds: 0, timeoutMilliseconds: 250))
    XCTAssertFalse(QRScannerDetectionState.shouldThrottle(
      speed: .unrestricted, elapsedMilliseconds: 0, timeoutMilliseconds: 250))
  }

  func testBarcodeWirePayloadOmitsEmptyCornersLikePinnedWrapper() {
    let withoutCorners = QRScannerVisionBarcode(
      rawValue: nil, displayValue: nil, format: "unknown", type: .unknown,
      corners: []).rufletValue
    XCTAssertEqual(withoutCorners, .map([
      "raw_value": .null,
      "display_value": .null,
      "format": "unknown",
      "type": "unknown",
    ]))

    let withCorners = QRScannerVisionBarcode(
      rawValue: "ruflet", displayValue: "ruflet", format: "qrCode", type: .text,
      corners: [CGPoint(x: 2, y: 3)]).rufletValue
    XCTAssertEqual(withCorners["corners"], .array([
      .map(["x": 2.0, "y": 3.0])
    ]))
  }

  func testCreatesScannerForNormalizedAndLegacyWireTypes() throws {
    let normalized = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "QrcodeScanner"))
    let legacy = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "qrcode_scanner"))
    XCTAssertEqual(normalized.classification, .visible)
    XCTAssertEqual(legacy.classification, .visible)
    XCTAssertEqual(normalized.rendering, .optionalBundle("RufletQRScanner"))
    XCTAssertEqual(legacy.rendering, .optionalBundle("RufletQRScanner"))
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
    RufletQRScanner.register(in: ServiceRegistry())
    XCTAssertEqual(ControlRegistry.descriptor(for: "QrcodeScanner")?.rendering, .nativeView)
    XCTAssertEqual(ControlRegistry.descriptor(for: "qrcode_scanner")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "QrcodeScanner")?.implementation,
      "RufletQRScanner.QRScannerControlView")
  }
}
