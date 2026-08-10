import Cocoa
import FlutterMacOS
import RufletApple
import SwiftUI

/// macOS renders through the Ruflet Apple engine.
///
/// Same split as iOS, settled the same way: this file only ever compiles for
/// macOS, so Android, web, Linux and Windows keep their Flutter runners and
/// their Flutter renderer. The Ruby application does not change.
///
/// The Flutter view controller is still created and its plugins registered,
/// because that is what starts the embedded mruby VM. It is simply not the
/// window's content.
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame

    RegisterGeneratedPlugins(registry: flutterViewController)

    if RufletEngineChoice.usesNativeRenderer {
      // Kept as a child so the engine stays alive and its plugins keep running,
      // while the window shows the native renderer.
      self.contentViewController = NSHostingController(
        rootView: RufletAppView(services: RufletEngineChoice.services))
      self.contentViewController?.addChild(flutterViewController)
    } else {
      self.contentViewController = flutterViewController
    }

    self.setFrame(windowFrame, display: true)
    super.awakeFromNib()
  }
}
