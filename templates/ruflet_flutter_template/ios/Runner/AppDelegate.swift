import Flutter
import RufletApple
import SwiftUI
import UIKit

/// Flutter owns startup on every platform. The selected Dart entrypoint resolves
/// either the embedded or configured backend URL, then calls this Runner over a
/// method channel when iOS should present Ruflet's native Apple renderer.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativeRendererChannel: FlutterMethodChannel?

  static let supportsNativeMultiView: Bool = {
    guard
      let manifest = Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest")
        as? [String: Any]
    else { return false }
    return manifest["UIApplicationSupportsMultipleScenes"] as? Bool ?? false
  }()

  @MainActor private static var sharedNativeApplication: RufletMultiViewApplication?

  @MainActor static func nativeApplication(serverURL: URL) -> RufletMultiViewApplication {
    if let sharedNativeApplication { return sharedNativeApplication }
    let application = RufletMultiViewApplication(
      serverURL: serverURL, extensions: RufletEngineChoice.extensions)
    sharedNativeApplication = application
    return application
  }

  @MainActor static func disconnectNativeScene(sessionIdentifier: String) {
    sharedNativeApplication?.disconnect(sessionIdentifier: sessionIdentifier)
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "ruflet/native_renderer",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    nativeRendererChannel = channel
    channel.setMethodCallHandler { call, result in
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
        let shown = UIApplication.shared.connectedScenes.compactMap {
          $0.delegate as? RufletSceneDelegate
        }.reduce(false) { shown, delegate in
          delegate.showNativeRenderer(serverURL: serverURL) || shown
        }
        result(shown)
      }
    }
  }

}

/// Starts as Flutter's ordinary scene delegate. Dart calls back only after it
/// has resolved the runtime URL, at which point this swaps the visible root and
/// retains Flutter's controller so its engine and plugins stay alive.
@objc class RufletSceneDelegate: FlutterSceneDelegate {
  private var nativeSessionIdentifier: String?
  private var retainedFlutterController: UIViewController?
  private var initialData: [String: RufletValue] = [:]

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity
    initialData = (activity?.userInfo ?? [:]).reduce(into: [:]) { values, entry in
      guard let key = entry.key as? String,
        let value = RufletSceneInitialData.convert(entry.value)
      else { return }
      values[key] = value
    }
  }

  @MainActor @discardableResult
  func showNativeRenderer(serverURL: URL) -> Bool {
    guard let window else { return false }
    if retainedFlutterController != nil { return true }
    guard let flutterController = window.rootViewController else { return false }
    retainedFlutterController = flutterController

    let nativeController: UIViewController
    if AppDelegate.supportsNativeMultiView,
      let sessionIdentifier = window.windowScene?.session.persistentIdentifier
    {
      nativeSessionIdentifier = sessionIdentifier
      let application = AppDelegate.nativeApplication(serverURL: serverURL)
      let nativeScene = application.connect(
        sessionIdentifier: sessionIdentifier, initialData: initialData)
      nativeController = UIHostingController(
        rootView: RufletMultiViewAppView(application: application, scene: nativeScene))
    } else {
      nativeController = UIHostingController(
        rootView: RufletAppView(
          serverURL: serverURL, extensions: RufletEngineChoice.extensions))
    }
    window.rootViewController = nativeController
    nativeController.addChild(flutterController)
    window.makeKeyAndVisible()
    return true
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    if let nativeSessionIdentifier {
      AppDelegate.disconnectNativeScene(sessionIdentifier: nativeSessionIdentifier)
      self.nativeSessionIdentifier = nil
    }
    super.sceneDidDisconnect(scene)
  }
}
