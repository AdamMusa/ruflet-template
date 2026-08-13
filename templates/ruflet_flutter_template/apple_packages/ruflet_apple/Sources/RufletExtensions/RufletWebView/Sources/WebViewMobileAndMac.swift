import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI
import WebKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum RufletWebViewError: Error, Equatable, Sendable {
  case invalidURL(String)
  case missingArgument(String)
  case unknownMethod(String)
  case javascriptFailure(String)
}

private final class RufletWeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  weak var target: WKScriptMessageHandler?

  init(target: WKScriptMessageHandler) {
    self.target = target
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    target?.userContentController(userContentController, didReceive: message)
  }
}

@MainActor
final class RufletWebViewController: NSObject, ObservableObject {
  let control: RufletControl
  let webView: WKWebView
  private var invokeToken: UUID?
  private var progressObservation: NSKeyValueObservation?
  private var urlObservation: NSKeyValueObservation?
  private var lastURL: String?

  init(control: RufletControl) {
    self.control = control
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    let scripts = WKUserContentController()
    configuration.userContentController = scripts
    webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()

    webView.navigationDelegate = self
    webView.uiDelegate = self
    scripts.add(RufletWeakScriptMessageHandler(target: self), name: "rufletScroll")
    scripts.add(RufletWeakScriptMessageHandler(target: self), name: "rufletConsole")
    scripts.addUserScript(WKUserScript(
      source: Self.bridgeScript,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false))
    observeWebView()
    applyProperties()
    loadInitialRequest()
  }

  deinit {
    progressObservation?.invalidate()
    urlObservation?.invalidate()
  }

  func attach() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { throw RufletWebViewError.unknownMethod(name) }
      return try await self.invoke(name, arguments: arguments.map ?? [:])
    }
  }

  func detach() {
    if let invokeToken {
      control.removeInvokeMethodListener(invokeToken)
      self.invokeToken = nil
    }
  }

  func applyProperties() {
    if let color = parseColor(control.string("bgcolor")) {
      #if os(iOS)
      webView.isOpaque = false
      webView.underPageBackgroundColor = UIColor(color)
      #elseif os(macOS)
      webView.underPageBackgroundColor = NSColor(color)
      #endif
    }
  }

  private func observeWebView() {
    progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
      Task { @MainActor [weak self] in
        self?.control.triggerEvent("progress", data: .int(Int64((webView.estimatedProgress * 100).rounded())))
      }
    }
    urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
      Task { @MainActor [weak self] in
        guard let self, let url = webView.url?.absoluteString, url != self.lastURL else { return }
        self.lastURL = url
        self.control.triggerEvent("url_change", data: .string(url))
      }
    }
  }

  private func loadInitialRequest() {
    let rawURL = control.string("url", default: "https://flet.dev") ?? "https://flet.dev"
    guard let url = URL(string: rawURL) else {
      control.triggerEvent("web_resource_error", data: .string("Invalid URL: \(rawURL)"))
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = RufletWebViewLoadRequestMethod(control.string("method")).rawValue.uppercased()
    webView.load(request)
  }

  private func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue {
    switch name {
    case "reload":
      webView.reload()
      return .null
    case "can_go_back":
      return .bool(webView.canGoBack)
    case "can_go_forward":
      return .bool(webView.canGoForward)
    case "go_back":
      if webView.canGoBack { webView.goBack() }
      return .null
    case "go_forward":
      if webView.canGoForward { webView.goForward() }
      return .null
    case "enable_zoom":
      setZoomEnabled(true)
      return .null
    case "disable_zoom":
      setZoomEnabled(false)
      return .null
    case "clear_cache":
      await clearCache()
      return .null
    case "clear_local_storage":
      _ = try await evaluateJavaScript("window.localStorage.clear(); window.sessionStorage.clear();")
      return .null
    case "get_current_url":
      return webView.url.map { .string($0.absoluteString) } ?? .null
    case "get_title":
      return webView.title.map(RufletValue.string) ?? .null
    case "get_user_agent":
      let value = try await evaluateJavaScript("navigator.userAgent")
      return value.map { .string(String(describing: $0)) } ?? .null
    case "load_file":
      guard let path = arguments["path"]?.text else { throw RufletWebViewError.missingArgument("path") }
      let fileURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
      webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
      return .null
    case "load_html":
      guard let html = arguments["value"]?.text else { throw RufletWebViewError.missingArgument("value") }
      let baseURL = arguments["base_url"]?.text.flatMap(URL.init(string:))
      webView.loadHTMLString(html, baseURL: baseURL)
      return .null
    case "load_request":
      guard let rawURL = arguments["url"]?.text else { throw RufletWebViewError.missingArgument("url") }
      guard let url = URL(string: rawURL) else { throw RufletWebViewError.invalidURL(rawURL) }
      var request = URLRequest(url: url)
      request.httpMethod = RufletWebViewLoadRequestMethod(arguments["method"]?.text).rawValue.uppercased()
      webView.load(request)
      return .null
    case "run_javascript":
      guard let source = arguments["value"]?.text else { throw RufletWebViewError.missingArgument("value") }
      _ = try await evaluateJavaScript(source)
      return .null
    case "scroll_to":
      let x = arguments["x"]?.number ?? 0
      let y = arguments["y"]?.number ?? 0
      _ = try await evaluateJavaScript("window.scrollTo(\(x), \(y));")
      return .null
    case "scroll_by":
      let x = arguments["x"]?.number ?? 0
      let y = arguments["y"]?.number ?? 0
      _ = try await evaluateJavaScript("window.scrollBy(\(x), \(y));")
      return .null
    case "set_javascript_mode":
      guard let mode = RufletWebViewJavaScriptMode(arguments["mode"]?.text) else {
        throw RufletWebViewError.missingArgument("mode")
      }
      webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = mode == .unrestricted
      return .null
    default:
      throw RufletWebViewError.unknownMethod(name)
    }
  }

  private func setZoomEnabled(_ enabled: Bool) {
    #if os(iOS)
    webView.scrollView.pinchGestureRecognizer?.isEnabled = enabled
    #elseif os(macOS)
    webView.allowsMagnification = enabled
    #endif
  }

  private func clearCache() async {
    let store = WKWebsiteDataStore.default()
    await withCheckedContinuation { continuation in
      store.removeData(
        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
        modifiedSince: .distantPast,
        completionHandler: { continuation.resume() })
    }
  }

  private func evaluateJavaScript(_ source: String) async throws -> Any? {
    try await withCheckedThrowingContinuation { continuation in
      webView.evaluateJavaScript(source) { value, error in
        if let error {
          continuation.resume(throwing: RufletWebViewError.javascriptFailure(error.localizedDescription))
        } else {
          continuation.resume(returning: value)
        }
      }
    }
  }

  private func shouldPreventNavigation(_ url: String) -> Bool {
    let links = control.value("prevent_links")?.array?.compactMap(\.text) ?? []
    return links.contains(where: url.hasPrefix)
  }

  private static let bridgeScript = #"""
  (() => {
    if (window.__rufletWebViewBridgeInstalled) return;
    window.__rufletWebViewBridgeInstalled = true;
    window.addEventListener('scroll', () => {
      window.webkit.messageHandlers.rufletScroll.postMessage({x: window.scrollX, y: window.scrollY});
    }, {passive: true});
    for (const level of ['log', 'info', 'warn', 'error', 'debug']) {
      const original = console[level];
      console[level] = function(...values) {
        try {
          window.webkit.messageHandlers.rufletConsole.postMessage({
            message: values.map(value => String(value)).join(' '),
            severity_level: level
          });
        } finally {
          original.apply(console, values);
        }
      };
    }
  })();
  """#
}

extension RufletWebViewController: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = navigationAction.request.url?.absoluteString else {
      decisionHandler(.cancel)
      return
    }
    decisionHandler(shouldPreventNavigation(url) ? .cancel : .allow)
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
    control.triggerEvent("page_started", data: webView.url.map { .string($0.absoluteString) } ?? .null)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
    control.triggerEvent("page_ended", data: webView.url.map { .string($0.absoluteString) } ?? .null)
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation?,
    withError error: Error
  ) {
    control.triggerEvent("web_resource_error", data: .string(error.localizedDescription))
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation?,
    withError error: Error
  ) {
    control.triggerEvent("web_resource_error", data: .string(error.localizedDescription))
  }
}

extension RufletWebViewController: WKUIDelegate {
  func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping () -> Void
  ) {
    control.triggerEvent("javascript_alert_dialog", data: .map([
      "message": .string(message),
      "url": webView.url.map { .string($0.absoluteString) } ?? .null,
    ]))
    completionHandler()
  }
}

extension RufletWebViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let payload = message.body as? [String: Any] else { return }
    if message.name == "rufletScroll", control.hasEventHandler("scroll") {
      control.triggerEvent("scroll", data: .map([
        "x": .double((payload["x"] as? NSNumber)?.doubleValue ?? 0),
        "y": .double((payload["y"] as? NSNumber)?.doubleValue ?? 0),
      ]))
    } else if message.name == "rufletConsole", control.hasEventHandler("console_message") {
      control.triggerEvent("console_message", data: .map([
        "message": .string(payload["message"] as? String ?? ""),
        "severity_level": .string(payload["severity_level"] as? String ?? "log"),
      ]))
    }
  }
}

#if os(iOS)
struct WebViewMobileAndMac: UIViewRepresentable {
  @ObservedObject var controller: RufletWebViewController

  func makeUIView(context: Context) -> WKWebView { controller.webView }
  func updateUIView(_ webView: WKWebView, context: Context) { controller.applyProperties() }
}
#elseif os(macOS)
struct WebViewMobileAndMac: NSViewRepresentable {
  @ObservedObject var controller: RufletWebViewController

  func makeNSView(context: Context) -> WKWebView { controller.webView }
  func updateNSView(_ webView: WKWebView, context: Context) { controller.applyProperties() }
}
#endif
