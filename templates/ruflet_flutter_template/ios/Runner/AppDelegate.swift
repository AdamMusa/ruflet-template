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
  static let supportsNativeMultiView: Bool = {
    guard
      let manifest = Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest")
        as? [String: Any]
    else { return false }
    return manifest["UIApplicationSupportsMultipleScenes"] as? Bool ?? false
  }()

  @MainActor static let nativeApplication = RufletMultiViewApplication(
    extensions: RufletEngineChoice.extensions)
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
  private var nativeSessionIdentifier: String?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard RufletEngineChoice.usesNativeRenderer else {
      super.scene(
        scene, willConnectTo: session, options: connectionOptions)
      return
    }
    guard let windowScene = scene as? UIWindowScene else { return }

    guard AppDelegate.supportsNativeMultiView else {
      let nativeWindow = UIWindow(windowScene: windowScene)
      nativeWindow.rootViewController = UIHostingController(
        rootView: RufletAppView(extensions: RufletEngineChoice.extensions))
      window = nativeWindow
      nativeWindow.makeKeyAndVisible()
      return
    }

    let identifier = session.persistentIdentifier
    nativeSessionIdentifier = identifier
    let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity
    let initialData = (activity?.userInfo ?? [:]).compactMapValues {
      RufletSceneInitialData.convert($0)
    }
    let nativeScene = AppDelegate.nativeApplication.connect(
      sessionIdentifier: identifier, initialData: initialData)

    let nativeWindow = UIWindow(windowScene: windowScene)
    nativeWindow.rootViewController = UIHostingController(
      rootView: RufletMultiViewAppView(
        application: AppDelegate.nativeApplication, scene: nativeScene))
    window = nativeWindow
    nativeWindow.makeKeyAndVisible()
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    if RufletEngineChoice.usesNativeRenderer, let nativeSessionIdentifier {
      AppDelegate.nativeApplication.disconnect(sessionIdentifier: nativeSessionIdentifier)
      self.nativeSessionIdentifier = nil
    } else {
      super.sceneDidDisconnect(scene)
    }
  }
}
