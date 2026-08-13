import RufletEngine
import RufletProtocol
@testable import RufletQRScanner
import XCTest

/// Literal translations of the executable tests in:
///
/// - `ruflet_qrcode_scanner/test/extension_test.dart`
/// - `ruflet_qrcode_scanner/test/scanner_config_test.dart`
@MainActor
final class QRScannerDartParityTests: XCTestCase {
  func testCreatesTheScannerForFletsNormalizedControlType() {
    let extensionRegistry = RufletQRScannerExtension()
    XCTAssertNotNil(extensionRegistry.createView(for: control("QrcodeScanner")))
  }

  func testKeepsAcceptingTheLegacyWireControlType() {
    let extensionRegistry = RufletQRScannerExtension()
    XCTAssertNotNil(extensionRegistry.createView(for: control("qrcode_scanner")))
  }

  func testIgnoresUnrelatedControls() {
    let extensionRegistry = RufletQRScannerExtension()
    XCTAssertNil(extensionRegistry.createView(for: control("Text")))
  }

  func testReusedWireIDReplacesControllerAndInvokeListenerWithNewControlIdentity() async throws {
    let extensionRegistry = RufletQRScannerExtension()
    let old = control("QrcodeScanner", id: 7)
    let replacement = control("QrcodeScanner", id: 7)

    XCTAssertNotNil(extensionRegistry.createView(for: old))
    XCTAssertNotNil(extensionRegistry.createView(for: replacement))
    let replacementResult = try await replacement.invokeMethod("stop", arguments: .null)
    XCTAssertEqual(replacementResult, .bool(true))

    let staleInvocation = Task { try await old.invokeMethod("stop", arguments: .null) }
    try await Task.sleep(nanoseconds: 20_000_000)
    staleInvocation.cancel()
    do {
      _ = try await staleInvocation.value
      XCTFail("The replaced control must no longer own the scanner invoke listener")
    } catch is CancellationError {
      // Expected: the removed listener causes invokeMethod to wait until cancellation.
    }
  }

  func testParsesScannerEnumsUsingRubySnakeCaseNames() {
    XCTAssertEqual(QRScannerConfiguration.parseCameraFacing("front"), .front)
    XCTAssertEqual(QRScannerConfiguration.parseCameraFacing("unknown"), .back)
    XCTAssertEqual(QRScannerConfiguration.parseDetectionSpeed("no_duplicates"), .noDuplicates)
    XCTAssertEqual(QRScannerConfiguration.parseDetectionSpeed("unrestricted"), .unrestricted)
  }

  func testFiltersAndDeduplicatesBarcodeFormats() {
    let formats = QRScannerConfiguration.parseFormats([
      "qr_code",
      "data_matrix",
      "qrCode",
      "not_a_format",
    ])

    XCTAssertEqual(formats, [.qrCode, .dataMatrix])
  }

  func testParsesScanWindowsFromBothSupportedHashShapes() {
    XCTAssertEqual(
      QRScannerConfiguration.parseScanWindow([
        "left": 10,
        "top": 20,
        "right": 110,
        "bottom": 220,
      ]),
      QRScannerRect(x: 10, y: 20, width: 100, height: 200))
    XCTAssertEqual(
      QRScannerConfiguration.parseScanWindow([
        "x": 10,
        "y": 20,
        "width": 100,
        "height": 200,
      ]),
      QRScannerRect(x: 10, y: 20, width: 100, height: 200))
  }

  private func control(_ type: String, id: Int = 1) -> RufletControl {
    RufletControl(
      id: id,
      type: type,
      properties: [:],
      backend: QRScannerDartParityBackend())
  }
}

@MainActor
private final class QRScannerDartParityBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
