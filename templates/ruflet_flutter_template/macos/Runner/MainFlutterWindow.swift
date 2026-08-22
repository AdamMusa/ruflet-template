import Cocoa
import FlutterMacOS
import RufletApple
import SwiftUI

/// Flutter starts normally. The selected Dart entrypoint resolves the embedded
/// transport endpoint or configured server address and calls this Runner when
/// macOS should switch only the visible content to Ruflet's native renderer.
class MainFlutterWindow: NSWindow {
  private var retainedFlutterViewController: FlutterViewController?
  private var nativeRendererChannel: FlutterMethodChannel?
  /// Guards against installing the native renderer more than once. Each install
  /// builds a fresh `RufletAppView`, and therefore a fresh `RufletBackend` with
  /// its own transport channel. Replacing `contentViewController` does not
  /// reliably run SwiftUI's `onDisappear`, so the displaced backend is never
  /// disposed: it keeps its reconnect loop alive and re-registers a whole new
  /// session every 500 ms forever, making the server rebuild and resend the
  /// entire page each time. That storm is what makes navigation feel frozen.
  private var nativeRendererInstalled = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame

    RegisterGeneratedPlugins(registry: flutterViewController)
    retainedFlutterViewController = flutterViewController
    self.contentViewController = flutterViewController

    let channel = FlutterMethodChannel(
      name: "ruflet/native_renderer", binaryMessenger: flutterViewController.engine.binaryMessenger)
    nativeRendererChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard RufletEngineChoice.usesNativeRenderer else {
        result(false)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let rawURL = arguments?["pageUrl"] as? String ?? ""
      guard let pageURL = RufletEngineChoice.pageURL(from: rawURL) else {
        result(
          FlutterError(
            code: "invalid_page_url", message: "Native renderer requires a valid Ruflet page URL.",
            details: rawURL))
        return
      }
      DispatchQueue.main.async {
        guard let self, self.retainedFlutterViewController != nil else {
          result(false)
          return
        }
        guard !self.nativeRendererInstalled else {
          result(true)
          return
        }
        self.nativeRendererInstalled = true
        let presentedFrame = self.frame
        let native = NSHostingController(
          rootView: RufletAppView(
            pageURL: pageURL, extensions: RufletEngineChoice.extensions))
        self.contentViewController = native
        // Installing an NSHostingController makes AppKit adopt the SwiftUI
        // fitting size. The renderer has no page yet at this point, so that
        // size collapses the window to a few points and the backend registers
        // with that bogus geometry. Keep the window the Runner already sized.
        native.view.frame = CGRect(origin: .zero, size: self.contentLayoutRect.size)
        self.setFrame(presentedFrame, display: true)
        result(true)
      }
    }

    self.setFrame(windowFrame, display: true)
    super.awakeFromNib()
  }
}
