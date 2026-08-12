import Foundation
import RufletEngine
import RufletProtocol
import RufletUI
@testable import RufletWebView
import XCTest

#if canImport(WebKit)
  import WebKit

  @MainActor
  final class WebViewDeepParityTests: XCTestCase {
    func testInitialRequestPreservesFletDefaultsAndMethods() throws {
      let fallback = try XCTUnwrap(WebViewRequestSpec(url: nil, method: nil))
      XCTAssertEqual(fallback.url.absoluteString, "https://flet.dev")
      XCTAssertEqual(fallback.request.httpMethod, "GET")

      let post = try XCTUnwrap(
        WebViewRequestSpec(url: "https://example.test/path", method: "POST"))
      XCTAssertEqual(post.request.httpMethod, "POST")
    }

    func testPreventLinksUseLiteralURLPrefixMatching() {
      XCTAssertTrue(WebViewModel.preventsNavigation(
        to: "https://blocked.test/path", prefixes: ["https://blocked.test/"]))
      XCTAssertFalse(WebViewModel.preventsNavigation(
        to: "HTTPS://blocked.test/path", prefixes: ["https://blocked.test/"]))
      XCTAssertFalse(WebViewModel.preventsNavigation(
        to: "https://allowed.test/path", prefixes: []))
    }

    func testCacheCommandsMatchPinnedWKWebViewDataTypes() {
      XCTAssertEqual(WebViewSemantics.cacheDataTypes, [
        WKWebsiteDataTypeDiskCache,
        WKWebsiteDataTypeMemoryCache,
        WKWebsiteDataTypeOfflineWebApplicationCache,
      ])
      XCTAssertEqual(
        WebViewSemantics.localStorageDataTypes,
        [WKWebsiteDataTypeLocalStorage])
    }

    func testConsoleBridgeCoversEveryPinnedSeverityAndSerializationRule() {
      let source = WebViewSemantics.consoleBridge
      for method in ["log", "info", "debug", "warn", "error"] {
        XCTAssertTrue(source.contains("'\(method)'"), method)
      }
      XCTAssertTrue(source.contains("warn: 'warning'"))
      XCTAssertTrue(source.contains("JSON.stringify"))
      XCTAssertTrue(source.contains("substring(0, 3000)"))
      XCTAssertTrue(source.contains("join(', ')"))
      XCTAssertEqual(
        WebViewSemantics.consoleUserScript.injectionTime,
        .atDocumentStart)
      XCTAssertTrue(WebViewSemantics.consoleUserScript.isForMainFrameOnly)
    }

    func testConsoleMessageEventPreservesPinnedMapShape() {
      let model = WebViewModel()
      let node = ControlNode(
        id: 42, type: "WebView",
        props: ["on_console_message": .bool(true)])
      var events: [(Int, String, RufletValue)] = []
      model.configure(
        node: node,
        events: RufletEventSink(send: { events.append(($0, $1, $2)) }))

      model.receiveConsoleMessage(name: "rufletConsole", body: [
        "message": "hello", "severity_level": "info",
      ])
      XCTAssertEqual(events.count, 1)
      XCTAssertEqual(events.first?.0, 42)
      XCTAssertEqual(events.first?.1, "console_message")
      XCTAssertEqual(events.first?.2, .map([
        "message": .string("hello"), "severity_level": .string("info"),
      ]))
    }

    func testZoomUsesPinnedViewportScriptOnBothApplePlatforms() {
      let script = WebViewSemantics.zoomDisabledUserScript
      XCTAssertEqual(script.injectionTime, .atDocumentEnd)
      XCTAssertTrue(script.isForMainFrameOnly)
      XCTAssertTrue(script.source.contains("maximum-scale=1.0"))
      XCTAssertTrue(script.source.contains("user-scalable=no"))
    }

    func testOnlyUnsupportedJavaScriptResultErrorsAreIgnored() {
      let unsupported = NSError(
        domain: WKError.errorDomain,
        code: WKError.Code.javaScriptResultTypeIsUnsupported.rawValue)
      XCTAssertTrue(WebViewSemantics.isUnsupportedJavaScriptResult(unsupported))
      XCTAssertFalse(WebViewSemantics.isUnsupportedJavaScriptResult(NSError(
        domain: WKError.errorDomain,
        code: WKError.Code.javaScriptExceptionOccurred.rawValue)))
      XCTAssertFalse(WebViewSemantics.isUnsupportedJavaScriptResult(NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorBadURL)))
    }
  }
#endif
