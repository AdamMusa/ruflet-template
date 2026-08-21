import RufletEngine
import RufletProtocol
@testable import RufletQRScanner
import XCTest

#if os(macOS)
  import AppKit
  import AVFoundation
  import SwiftUI
#endif

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

  func testNativeScannerFillsItsRubyBoundsAndReportsAutomaticStartErrors() throws {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let controlSource = try String(
      contentsOf: package.appendingPathComponent(
        "Sources/RufletExtensions/RufletQRScanner/Sources/QRScannerControl.swift"),
      encoding: .utf8)
    let controllerSource = try String(
      contentsOf: package.appendingPathComponent(
        "Sources/RufletExtensions/RufletQRScanner/Sources/QRScannerController.swift"),
      encoding: .utf8)

    XCTAssertTrue(controlSource.contains("GeometryReader { proxy in"))
    XCTAssertTrue(controlSource.contains("width: proxy.size.width"))
    XCTAssertTrue(controlSource.contains("height: proxy.size.height"))
    XCTAssertTrue(controllerSource.contains("private func startAndReport()"))
    XCTAssertFalse(controllerSource.contains("try? await start()"))
  }

  #if os(macOS)
    func testNativePreviewFillsAndCentersInTheRubySuppliedBounds() throws {
      let scanner = control(
        "QrcodeScanner",
        properties: ["auto_start": .bool(false)])
      let controller = QRScannerController(control: scanner)
      let size = CGSize(width: 320, height: 180)
      let hosting = NSHostingView(
        rootView: QRScannerControl(control: scanner, controller: controller)
          .frame(width: size.width, height: size.height))
      hosting.frame = CGRect(origin: .zero, size: size)
      hosting.layoutSubtreeIfNeeded()

      let preview = try XCTUnwrap(
        descendants(of: hosting).first(where: { view in
          view.layer?.sublayers?.contains(where: { $0 is AVCaptureVideoPreviewLayer }) == true
        }))
      XCTAssertEqual(preview.frame.midX, size.width / 2, accuracy: 0.5)
      XCTAssertEqual(preview.frame.midY, size.height / 2, accuracy: 0.5)
      XCTAssertEqual(preview.frame.width, size.width, accuracy: 0.5)
      XCTAssertEqual(preview.frame.height, size.height, accuracy: 0.5)
    }

    private func descendants(of view: NSView) -> [NSView] {
      view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
  #endif

  private func control(
    _ type: String,
    id: Int = 1,
    properties: [String: RufletValue] = [:]
  ) -> RufletControl {
    RufletControl(
      id: id,
      type: type,
      properties: properties,
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
