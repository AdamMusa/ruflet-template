import Cocoa
import FlutterMacOS
import RufletApple
import SwiftUI

/// Flutter starts normally. The selected Dart entrypoint resolves the self or
/// server backend URL and calls this Runner when macOS should switch only the
/// visible content to Ruflet's native renderer.
class MainFlutterWindow: NSWindow {
  private var retainedFlutterViewController: FlutterViewController?
  private var nativeRendererChannel: FlutterMethodChannel?

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
      guard let serverURL = RufletEngineChoice.websocketURL(from: rawURL) else {
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
        let native = NSHostingController(
          rootView: RufletAppView(
            serverURL: serverURL, extensions: RufletEngineChoice.extensions))
        self.contentViewController = native
        result(true)
      }
    }

    self.setFrame(windowFrame, display: true)
    super.awakeFromNib()
  }
}
