import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Flutter's UIKit scene host for the standard (non-native-renderer) build.
/// Info.plist names this class, so it must live in the Runner module rather
/// than referring directly to FlutterSceneDelegate in the Flutter framework.
@objc class SceneDelegate: FlutterSceneDelegate {}
