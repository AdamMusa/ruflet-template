import Flutter
import RufletApple
import SwiftUI
import UIKit

/// iOS renders through the Ruflet Apple engine.
///
/// The engine choice is settled by which runner is being built, not by a flag:
/// this file only ever compiles for iOS, and `android/`, `web/`, `linux/` and
/// `windows/` keep their Flutter runners untouched. The Ruby application is the
/// same either way — both engines speak the same Ruflet protocol.
///
/// Flutter is still initialised, because the plugins registered with it are
/// what start the embedded mruby VM. It simply never presents a view.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let handled = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if RufletEngineChoice.usesNativeRenderer {
      presentNativeRenderer()
    }
    return handled
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Replaces Flutter's root with the native renderer.
  ///
  /// `FlutterAppDelegate` has already made the window by this point, so taking
  /// it over is a matter of swapping the root controller rather than building
  /// a new one — which keeps the launch storyboard, the safe area and the
  /// status bar behaving exactly as they did.
  private func presentNativeRenderer() {
    let window = self.window ?? UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = UIHostingController(
      rootView: RufletAppView(services: RufletEngineChoice.services))
    self.window = window
    window.makeKeyAndVisible()
  }
}
