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
    private var consoleBridgeInstalled = false

    func configure(node: ControlNode, events: RufletEventSink) {
      self.node = node
      self.events = events
      if let webView {
        installConsoleBridgeIfNeeded(in: webView.configuration.userContentController)
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
      installConsoleBridgeIfNeeded(in: configuration.userContentController)
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
          self?.fire(
            "url_change",
            view.url.map { .string($0.absoluteString) } ?? .null)
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
        let types = WebViewSemantics.cacheDataTypes
        WKWebsiteDataStore.default().removeData(
          ofTypes: types, modifiedSince: .distantPast
        ) { completion(.success(.null)) }
      case "clear_local_storage":
        WKWebsiteDataStore.default().removeData(
          ofTypes: WebViewSemantics.localStorageDataTypes,
          modifiedSince: .distantPast
        ) { completion(.success(.null)) }
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
        evaluate(
          value, in: webView, ignoresUnsupportedResult: true,
          completion: completion)
      case "scroll_to", "scroll_by":
        guard let x = WebViewSemantics.parseInt(call.argument("x")),
          let y = WebViewSemantics.parseInt(call.argument("y"))
        else {
          return completion(.success(.null))
        }
        scroll(
          to: CGPoint(x: Double(x), y: Double(y)),
          relative: call.name == "scroll_by", in: webView,
          completion: completion)
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
      ignoresUnsupportedResult: Bool = false,
      completion: @escaping RufletMethodCompletion
    ) {
      webView.evaluateJavaScript(script) { value, error in
        if let error {
          if ignoresUnsupportedResult,
            WebViewSemantics.isUnsupportedJavaScriptResult(error)
          {
            completion(.success(.null))
          } else {
            completion(.failure(RufletServiceError.failed(error.localizedDescription)))
          }
        } else if returnsValue, let string = value as? String {
          completion(.success(.string(string)))
        } else {
          completion(.success(.null))
        }
      }
    }

    private func setZoomEnabled(_ enabled: Bool, in webView: WKWebView) {
      // webview_flutter_wkwebview implements this with a viewport user script
      // on both Darwin platforms. Resetting the scripts when enabling removes
      // the restriction while preserving the optional console bridge.
      let controller = webView.configuration.userContentController
      controller.removeAllUserScripts()
      if consoleBridgeInstalled { controller.addUserScript(WebViewSemantics.consoleUserScript) }
      if !enabled { controller.addUserScript(WebViewSemantics.zoomDisabledUserScript) }
    }

    private func installConsoleBridgeIfNeeded(in controller: WKUserContentController) {
      guard !consoleBridgeInstalled, node?.handlesEvent("console_message") == true else { return }
      consoleBridgeInstalled = true
      controller.addUserScript(WebViewSemantics.consoleUserScript)
    }

    private func scroll(
      to point: CGPoint,
      relative: Bool,
      in webView: WKWebView,
      completion: @escaping RufletMethodCompletion
    ) {
      #if canImport(UIKit)
        let destination = relative
          ? CGPoint(
            x: webView.scrollView.contentOffset.x + point.x,
            y: webView.scrollView.contentOffset.y + point.y)
          : point
        webView.scrollView.setContentOffset(destination, animated: false)
        completion(.success(.null))
      #elseif canImport(AppKit)
        // WKWebView exposes its UIScrollView on iOS, but not its internal
        // NSScrollView on macOS. webview_flutter has the same platform gap;
        // use the DOM scroll API there so the documented Flet command remains
        // executable instead of silently succeeding without scrolling.
        let function = relative ? "scrollBy" : "scrollTo"
        evaluate(
          "window.\(function)(\(point.x), \(point.y));", in: webView,
          ignoresUnsupportedResult: true, completion: completion)
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

    func receiveConsoleMessage(name: String, body value: Any) {
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

  }

  enum WebViewSemantics {
    static let cacheDataTypes: Set<String> = [
      WKWebsiteDataTypeDiskCache,
      WKWebsiteDataTypeMemoryCache,
      WKWebsiteDataTypeOfflineWebApplicationCache,
    ]
    static let localStorageDataTypes: Set<String> = [WKWebsiteDataTypeLocalStorage]

    /// Mirrors Flet's `parseInt` for scroll commands instead of RufletValue's
    /// broader numeric/bool coercion.
    static func parseInt(_ value: RufletValue?) -> Int? {
      switch value {
      case .int(let value): return Int(exactly: value)
      case .string(let value):
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
      default: return nil
      }
    }

    static var consoleUserScript: WKUserScript {
      WKUserScript(
        source: consoleBridge, injectionTime: .atDocumentStart,
        forMainFrameOnly: true)
    }

    static var zoomDisabledUserScript: WKUserScript {
      WKUserScript(
        source: zoomDisabledScript, injectionTime: .atDocumentEnd,
        forMainFrameOnly: true)
    }

    static func isUnsupportedJavaScriptResult(_ error: Error) -> Bool {
      let nsError = error as NSError
      return nsError.domain == WKError.errorDomain
        && nsError.code == WKError.Code.javaScriptResultTypeIsUnsupported.rawValue
    }

    /// Source-compatible form of webview_flutter_wkwebview's console bridge:
    /// all five Dart severity levels, main-frame injection, object JSON, a
    /// 3000-character argument cap, and comma-separated arguments.
    static let consoleBridge = """
      (() => {
        if (window.__rufletConsoleInstalled) return;
        window.__rufletConsoleInstalled = true;
        const bridge = window.webkit && window.webkit.messageHandlers &&
          window.webkit.messageHandlers.rufletConsole;
        if (!bridge) return;
        const severity = { log: 'log', info: 'info', debug: 'debug', warn: 'warning', error: 'error' };
        const stringify = (value) => {
          if (typeof value === 'undefined') return 'undefined';
          if (typeof value !== 'object' || value === null) return String(value);
          try {
            const seen = new WeakSet();
            return JSON.stringify(value, (_, nested) => {
              if (typeof nested !== 'object' || nested === null) return nested;
              if (seen.has(nested)) return undefined;
              seen.add(nested);
              return nested;
            });
          } catch (_) { return String(value); }
        };
        ['log', 'info', 'debug', 'warn', 'error'].forEach((name) => {
          const original = console[name];
          console[name] = function(...args) {
            bridge.postMessage({
              message: args.map((value) => stringify(value).substring(0, 3000)).join(', '),
              severity_level: severity[name]
            });
            return original.apply(console, args);
          };
        });
      })();
      """

    static let zoomDisabledScript = """
      var meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      var head = document.getElementsByTagName('head')[0];
      head.appendChild(meta);
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
