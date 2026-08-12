@testable import RufletUI
import RufletEngine
import RufletVideo
import RufletWebView
import XCTest

@MainActor
final class VideoWebViewExtensionParityTests: XCTestCase {
  func testCoreDescriptorsPreserveTheTwoFletPackageBoundaries() throws {
    let video = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "Video"))
    XCTAssertEqual(video.rendering, .optionalBundle("RufletVideo"))
    XCTAssertEqual(video.implementation, "RufletVideo.VideoControlView")

    let webView = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "WebView"))
    XCTAssertEqual(webView.rendering, .optionalBundle("RufletWebView"))
    XCTAssertEqual(webView.implementation, "RufletWebView.WebViewControlView")
  }

  func testExtensionsInstallTheirNativeRendererIndependently() {
    let services = ServiceRegistry()
    services.register(extension: RufletVideo.self)
    XCTAssertNotNil(ControlRegistry.build(
      node: ControlNode(id: 1, type: "Video"), axis: .none))

    services.register(extension: RufletWebView.self)
    XCTAssertNotNil(ControlRegistry.build(
      node: ControlNode(id: 2, type: "WebView"), axis: .none))
  }

  func testManifestMarksBothPinnedFletPackagesAvailable() {
    let packages = Dictionary(uniqueKeysWithValues:
      RufletExtensionManifest.packages.map { ($0.fletPackage, $0) })
    XCTAssertEqual(packages["flet_video"]?.swiftProduct, "RufletVideo")
    XCTAssertEqual(packages["flet_video"]?.status, .available)
    XCTAssertEqual(packages["flet_webview"]?.swiftProduct, "RufletWebView")
    XCTAssertEqual(packages["flet_webview"]?.status, .available)
  }
}
