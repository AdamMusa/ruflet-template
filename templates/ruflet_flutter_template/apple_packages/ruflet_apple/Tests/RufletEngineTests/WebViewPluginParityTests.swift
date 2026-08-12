import RufletEngine
@testable import RufletUI
import XCTest

final class WebViewPluginParityTests: XCTestCase {
  func testDescriptorMatchesPinnedFletWebViewSurface() throws {
    let descriptor = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "WebView"))
    XCTAssertEqual(descriptor.supportedEvents, [
      "console_message", "javascript_alert_dialog", "page_ended", "page_started",
      "progress", "scroll", "url_change", "web_resource_error",
    ])
    XCTAssertEqual(descriptor.supportedMethods, [
      "can_go_back", "can_go_forward", "clear_cache", "clear_local_storage",
      "disable_zoom", "enable_zoom", "get_current_url", "get_title", "get_user_agent",
      "go_back", "go_forward", "load_file", "load_html", "load_request", "reload",
      "run_javascript", "scroll_by", "scroll_to", "set_javascript_mode",
    ])
  }

  #if canImport(WebKit)
    func testInitialRequestUsesFletURLAndMethodDefaults() throws {
      let request = try XCTUnwrap(WebViewRequestSpec(url: nil, method: nil))
      XCTAssertEqual(request.url.absoluteString, "https://flet.dev")
      XCTAssertEqual(request.method, "GET")
    }

    func testOnlyPostOverridesFletsGetRequestDefault() throws {
      XCTAssertEqual(
        try XCTUnwrap(WebViewRequestSpec(url: "https://example.test", method: "post")).method,
        "POST")
      XCTAssertEqual(
        try XCTUnwrap(WebViewRequestSpec(url: "https://example.test", method: "invalid")).method,
        "GET")
    }

    @MainActor
    func testPreventLinksUseFletsPrefixMatching() {
      XCTAssertTrue(WebViewModel.preventsNavigation(
        to: "https://blocked.test/path", prefixes: ["https://blocked.test"]))
      XCTAssertFalse(WebViewModel.preventsNavigation(
        to: "https://allowed.test/path", prefixes: ["https://blocked.test"]))
    }
  #endif
}
