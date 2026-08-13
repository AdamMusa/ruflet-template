import Foundation
import RufletProtocol
#if os(iOS)
import SafariServices
import UIKit
#elseif os(macOS)
import AppKit
import WebKit
#endif

@MainActor
public final class UrlLauncherService: RufletInvokableService {
  #if os(iOS)
  private weak var safariController: SFSafariViewController?
  #elseif os(macOS)
  private var windows: [NSWindowController] = []
  #endif

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "launch_url":
      let url = try parseServiceURL(arguments["url"])
      try await launch(url, mode: arguments["mode"]?.text ?? "platformDefault",
                       configuration: arguments["web_view_configuration"]?.map)
      return nil
    case "can_launch_url":
      let url = try parseServiceURL(arguments["url"])
      #if os(iOS)
      return .bool(UIApplication.shared.canOpenURL(url))
      #elseif os(macOS)
      return .bool(NSWorkspace.shared.urlForApplication(toOpen: url) != nil)
      #endif
    case "close_in_app_web_view":
      #if os(iOS)
      safariController?.dismiss(animated: true)
      safariController = nil
      #elseif os(macOS)
      windows.last?.close()
      if !windows.isEmpty { windows.removeLast() }
      #endif
      return nil
    case "open_window":
      let url = try parseServiceURL(arguments["url"])
      #if os(iOS)
      try await launch(url, mode: "externalApplication", configuration: nil)
      #elseif os(macOS)
      openWindow(
        url, title: arguments["title"]?.text ?? "Ruflet",
        width: arguments["width"]?.number ?? 1_200,
        height: arguments["height"]?.number ?? 800)
      #endif
      return nil
    case "supports_launch_mode":
      return .bool(supports(arguments["mode"]?.text ?? "platformDefault"))
    case "supports_close_for_launch_mode":
      let mode = arguments["mode"]?.text ?? "platformDefault"
      return .bool(mode == "inAppBrowserView" || mode == "inAppWebView")
    default: throw RufletServiceError.unknownMethod(service: "UrlLauncher", method: name)
    }
  }

  private func parseServiceURL(_ value: RufletValue?) throws -> URL {
    let string: String?
    switch value {
    case .string(let value): string = value
    case .map(let value): string = value["url"]?.text
    default: string = nil
    }
    guard let string, let url = URL(string: string) else { throw RufletServiceError.invalidArgument("url") }
    return url
  }

  private func supports(_ mode: String) -> Bool {
    ["platformDefault", "inAppWebView", "inAppBrowserView", "externalApplication",
     "externalNonBrowserApplication"].contains(mode)
  }

  private func launch(
    _ url: URL,
    mode: String,
    configuration: [String: RufletValue]?
  ) async throws {
    guard supports(mode) else { throw RufletServiceError.invalidArgument("mode") }
    #if os(iOS)
    if mode == "inAppWebView" || mode == "inAppBrowserView" {
      let controller = SFSafariViewController(url: url)
      safariController = controller
      try servicePresentationController().present(controller, animated: true)
      return
    }
    guard await UIApplication.shared.open(url) else { throw RufletServiceError.unavailable(url.absoluteString) }
    #elseif os(macOS)
    if mode == "inAppWebView" || mode == "inAppBrowserView" {
      openWindow(url, title: url.host ?? "Ruflet", width: 1_200, height: 800)
      return
    }
    guard NSWorkspace.shared.open(url) else { throw RufletServiceError.unavailable(url.absoluteString) }
    #endif
  }

  #if os(macOS)
  private func openWindow(_ url: URL, title: String, width: Double, height: Double) {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.load(URLRequest(url: url))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: width, height: height),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = title
    window.contentView = webView
    window.center()
    let controller = NSWindowController(window: window)
    controller.showWindow(nil)
    windows.append(controller)
  }
  #endif

  public override func dispose() {
    #if os(macOS)
    windows.forEach { $0.close() }
    windows.removeAll()
    #endif
    super.dispose()
  }
}
