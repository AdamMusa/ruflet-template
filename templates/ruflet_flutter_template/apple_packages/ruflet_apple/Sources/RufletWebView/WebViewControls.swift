import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(WebKit)
  @preconcurrency import WebKit
#endif
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// `WebView` — WKWebView, wrapped for SwiftUI.
public struct WebViewControlView: View {
  public let node: ControlNode
  @StateObject private var model = WebViewModel()
  @Environment(\.rufletEvents) private var events

  public init(node: ControlNode) { self.node = node }

  public var body: some View {
    #if canImport(WebKit)
      WebViewRepresentable(model: model)
        .onAppear { model.configure(node: node, events: events) }
        .onChange(of: node) { model.configure(node: $0, events: events) }
        .rufletCommandHandler(node.id) { call, completion in
          model.handle(call, completion: completion)
        }
    #else
      Color.clear
    #endif
  }
}

#if canImport(WebKit)
  struct WebViewRequestSpec: Equatable {
    static let defaultURL = "https://flet.dev"

    let url: URL
    let method: String

    init?(url: String?, method: String?) {
      guard let resolved = URL(string: url ?? Self.defaultURL) else { return nil }
      self.url = resolved
      self.method = method?.lowercased() == "post" ? "POST" : "GET"
    }

    var request: URLRequest {
      var request = URLRequest(url: url)
      request.httpMethod = method
      return request
    }
  }

  @MainActor
  final class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate
  {
    private(set) var webView: WKWebView?
    private var node: ControlNode?
    private var events = RufletEventSink()
    private var progressObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    private var loadedInitialRequest = false
    private var scriptProxy: WeakWebViewScriptHandler?

    func configure(node: ControlNode, events: RufletEventSink) {
      self.node = node
      self.events = events
      if let webView {
        applyBackground(to: webView)
        loadInitialRequestIfNeeded(in: webView)
      }
    }

    func makeWebView() -> WKWebView {
      if let webView { return webView }
      let configuration = WKWebViewConfiguration()
      let proxy = WeakWebViewScriptHandler(target: self)
      scriptProxy = proxy
      configuration.userContentController.add(proxy, name: "rufletConsole")
      configuration.userContentController.addUserScript(WKUserScript(
        source: Self.consoleBridge,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false))
      let view = WKWebView(frame: .zero, configuration: configuration)
      view.navigationDelegate = self
      view.uiDelegate = self
      webView = view
      progressObserver = view.observe(\.estimatedProgress, options: [.new]) {
        [weak self] view, _ in
        Task { @MainActor in
          self?.fire("progress", .int(Int64((view.estimatedProgress * 100).rounded())))
        }
      }
      urlObserver = view.observe(\.url, options: [.new]) { [weak self] view, _ in
        Task { @MainActor in
          guard let url = view.url?.absoluteString else { return }
          self?.fire("url_change", .string(url))
        }
      }
      #if canImport(UIKit)
        view.scrollView.delegate = self
      #endif
      applyBackground(to: view)
      loadInitialRequestIfNeeded(in: view)
      return view
    }

    private func loadInitialRequestIfNeeded(in webView: WKWebView) {
      guard !loadedInitialRequest, let node,
        let request = WebViewRequestSpec(
          url: node.string("url"), method: node.string("method"))?.request
      else { return }
      loadedInitialRequest = true
      webView.load(request)
    }

    private func applyBackground(to webView: WKWebView) {
      guard let colorName = node?.string("bgcolor") else { return }
      guard let color = MaterialPalette.color(colorName) else { return }
      #if canImport(UIKit)
        let native = UIColor(color)
        webView.isOpaque = native.cgColor.alpha == 1
        webView.backgroundColor = native
        webView.scrollView.backgroundColor = native
      #elseif canImport(AppKit)
        webView.setValue(NSColor(color), forKey: "underPageBackgroundColor")
      #endif
    }

    func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      guard let webView else {
        completion(.failure(RufletServiceError.unavailable("WebView is not mounted")))
        return
      }
      switch call.name {
      case "reload":
        webView.reload()
        completion(.success(.null))
      case "can_go_back":
        completion(.success(.bool(webView.canGoBack)))
      case "can_go_forward":
        completion(.success(.bool(webView.canGoForward)))
      case "go_back":
        if webView.canGoBack { webView.goBack() }
        completion(.success(.null))
      case "go_forward":
        if webView.canGoForward { webView.goForward() }
        completion(.success(.null))
      case "enable_zoom", "disable_zoom":
        setZoomEnabled(call.name == "enable_zoom", in: webView)
        completion(.success(.null))
      case "clear_cache":
        let types: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        WKWebsiteDataStore.default().removeData(
          ofTypes: types, modifiedSince: .distantPast
        ) { completion(.success(.null)) }
      case "clear_local_storage":
        evaluate("window.localStorage.clear();", in: webView, completion: completion)
      case "get_current_url":
        completion(.success(webView.url.map { .string($0.absoluteString) } ?? .null))
      case "get_title":
        completion(.success(webView.title.map(RufletValue.string) ?? .null))
      case "get_user_agent":
        evaluate("navigator.userAgent", in: webView, returnsValue: true, completion: completion)
      case "load_file":
        guard let path = call.argument("path")?.stringValue else {
          return completion(.success(.null))
        }
        let url = URL(fileURLWithPath: path)
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        completion(.success(.null))
      case "load_html":
        guard let value = call.argument("value")?.stringValue else {
          return completion(.success(.null))
        }
        let baseURL = call.argument("base_url")?.stringValue.flatMap(URL.init(string:))
        webView.loadHTMLString(value, baseURL: baseURL)
        completion(.success(.null))
      case "load_request":
        if let url = call.argument("url")?.stringValue,
          let spec = WebViewRequestSpec(
            url: url,
            method: call.argument("method")?.stringValue)
        {
          webView.load(spec.request)
        }
        completion(.success(.null))
      case "run_javascript":
        guard let value = call.argument("value")?.stringValue else {
          return completion(.success(.null))
        }
        evaluate(value, in: webView, completion: completion)
      case "scroll_to", "scroll_by":
        guard let x = call.argument("x")?.intValue, let y = call.argument("y")?.intValue else {
          return completion(.success(.null))
        }
        let function = call.name == "scroll_to" ? "scrollTo" : "scrollBy"
        evaluate("window.\(function)(\(x), \(y));", in: webView, completion: completion)
      case "set_javascript_mode":
        if let mode = call.argument("mode")?.stringValue?.lowercased(),
          ["disabled", "unrestricted"].contains(mode)
        {
          webView.configuration.defaultWebpagePreferences.allowsContentJavaScript =
            mode == "unrestricted"
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("WebView", call)))
      }
    }

    private func evaluate(
      _ script: String,
      in webView: WKWebView,
      returnsValue: Bool = false,
      completion: @escaping RufletMethodCompletion
    ) {
      webView.evaluateJavaScript(script) { value, error in
        if let error {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        } else if returnsValue, let string = value as? String {
          completion(.success(.string(string)))
        } else {
          completion(.success(.null))
        }
      }
    }

    private func setZoomEnabled(_ enabled: Bool, in webView: WKWebView) {
      #if canImport(UIKit)
        webView.scrollView.pinchGestureRecognizer?.isEnabled = enabled
      #elseif canImport(AppKit)
        webView.enclosingScrollView?.allowsMagnification = enabled
      #endif
    }

    private func shouldPreventNavigation(_ url: String) -> Bool {
      Self.preventsNavigation(
        to: url,
        prefixes: node?.array("prevent_links")?.compactMap(\.stringValue) ?? [])
    }

    static func preventsNavigation(to url: String, prefixes: [String]) -> Bool {
      prefixes.contains(where: url.hasPrefix)
    }

    private func fire(_ name: String, _ data: RufletValue) {
      guard let node else { return }
      events.fire(node, name, data: data)
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url?.absoluteString else {
        return decisionHandler(.allow)
      }
      decisionHandler(shouldPreventNavigation(url) ? .cancel : .allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      if let url = webView.url?.absoluteString { fire("page_started", .string(url)) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      if let url = webView.url?.absoluteString { fire("page_ended", .string(url)) }
    }

    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      fire("web_resource_error", .string(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      fire("web_resource_error", .string(error.localizedDescription))
    }

    func webView(
      _ webView: WKWebView,
      runJavaScriptAlertPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo,
      completionHandler: @escaping () -> Void
    ) {
      fire("javascript_alert_dialog", .map([
        "message": .string(message),
        "url": .string(frame.request.url?.absoluteString ?? "")
      ]))
      completionHandler()
    }

    fileprivate func receiveConsoleMessage(name: String, body value: Any) {
      guard name == "rufletConsole", let body = value as? [String: Any],
        let text = body["message"] as? String, let level = body["severity_level"] as? String
      else { return }
      fire("console_message", .map([
        "message": .string(text), "severity_level": .string(level)
      ]))
    }

    deinit {
      progressObserver?.invalidate()
      urlObserver?.invalidate()
    }

    private static let consoleBridge = """
      (() => {
        if (window.__rufletConsoleInstalled) return;
        window.__rufletConsoleInstalled = true;
        const bridge = window.webkit && window.webkit.messageHandlers &&
          window.webkit.messageHandlers.rufletConsole;
        if (!bridge) return;
        ['log', 'debug', 'warn', 'error'].forEach((name) => {
          const original = console[name];
          console[name] = function(...args) {
            bridge.postMessage({
              message: args.map((value) => String(value)).join(' '),
              severity_level: name === 'warn' ? 'warning' : name
            });
            return original.apply(console, args);
          };
        });
      })();
      """
  }

  private final class WeakWebViewScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebViewModel?

    init(target: WebViewModel) { self.target = target }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      Task { @MainActor [weak target] in
        target?.receiveConsoleMessage(name: message.name, body: message.body)
      }
    }
  }

  private struct WebViewRepresentable {
    let model: WebViewModel
  }

  #if canImport(UIKit)
    extension WebViewRepresentable: UIViewRepresentable {
      func makeUIView(context: Context) -> WKWebView { model.makeWebView() }
      func updateUIView(_ view: WKWebView, context: Context) {}
    }
  #elseif canImport(AppKit)
    extension WebViewRepresentable: NSViewRepresentable {
      func makeNSView(context: Context) -> WKWebView { model.makeWebView() }
      func updateNSView(_ view: WKWebView, context: Context) {}
    }
  #endif

  #if canImport(UIKit)
    extension WebViewModel: UIScrollViewDelegate {
      nonisolated func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        Task { @MainActor in
          fire("scroll", .map(["x": .double(offset.x), "y": .double(offset.y)]))
        }
      }
    }
  #endif
#endif
