import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `flet_webview` package.
@MainActor
public enum RufletWebView: RufletExtension {
  public static let extensionName = "RufletWebView"

  public static func register(in _: ServiceRegistry) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "WebView", classification: .visible,
        implementation: "RufletWebView.WebViewControlView", rendering: .nativeView,
        supportedEvents: [
          "console_message", "javascript_alert_dialog", "page_ended", "page_started",
          "progress", "scroll", "url_change", "web_resource_error",
        ],
        supportedMethods: [
          "can_go_back", "can_go_forward", "clear_cache", "clear_local_storage",
          "disable_zoom", "enable_zoom", "get_current_url", "get_title",
          "get_user_agent", "go_back", "go_forward", "load_file", "load_html",
          "load_request", "reload", "run_javascript", "scroll_by", "scroll_to",
          "set_javascript_mode",
        ])) { node, _ in
      AnyView(WebViewControlView(node: node))
    }
  }
}
