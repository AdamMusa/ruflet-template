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

/// Owns the visible iOS window when UIKit's scene lifecycle is enabled.
///
/// Flutter's current template creates the window in `FlutterSceneDelegate`
/// after `application(_:didFinishLaunchingWithOptions:)`. Installing SwiftUI
/// only from `AppDelegate` is therefore temporary: the Flutter scene replaces
/// it moments later. Make the renderer choice at the lifecycle point that owns
/// the window so every iOS release—not just older non-scene templates—actually
/// presents the native engine.
@objc class RufletSceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(
      scene, willConnectTo: session, options: connectionOptions)

    guard RufletEngineChoice.usesNativeRenderer,
      let windowScene = scene as? UIWindowScene
    else { return }

    let nativeWindow = window ?? UIWindow(windowScene: windowScene)
    nativeWindow.windowScene = windowScene
    nativeWindow.rootViewController = UIHostingController(
      rootView: RufletAppView(services: RufletEngineChoice.services))
    window = nativeWindow
    nativeWindow.makeKeyAndVisible()
  }
}
