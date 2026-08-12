import Foundation
import RufletApple

// The optional extension modules. `canImport` is what makes them optional: a
// target that does not link one simply compiles this file without it, so
// dropping a module from the target's dependencies is all it takes to keep
// CoreMotion, CoreLocation or AVFoundation capture — and the usage string each
// one obliges you to declare — out of the app.
#if canImport(RufletMotion)
  import RufletMotion
#endif
#if canImport(RufletGeolocator)
  import RufletGeolocator
#endif
#if canImport(RufletAudio)
  import RufletAudio
#endif
#if canImport(RufletAudioRecorder)
  import RufletAudioRecorder
#endif
#if canImport(RufletCamera)
  import RufletCamera
#endif
#if canImport(RufletFlashlight)
  import RufletFlashlight
#endif
#if canImport(RufletPermissionHandler)
  import RufletPermissionHandler
#endif
#if canImport(RufletSecureStorage)
  import RufletSecureStorage
#endif
#if canImport(RufletQRScanner)
  import RufletQRScanner
#endif
#if canImport(RufletRive)
  import RufletRive
#endif
#if canImport(RufletLottie)
  import RufletLottie
#endif
#if canImport(RufletCharts)
  import RufletCharts
#endif
#if canImport(RufletMap)
  import RufletMap
#endif
#if canImport(RufletDataTable2)
  import RufletDataTable2
#endif
#if canImport(RufletVideo)
  import RufletVideo
#endif
#if canImport(RufletWebView)
  import RufletWebView
#endif
#if canImport(RufletAds)
  import RufletAds
#endif
#if canImport(RufletCodeEditor)
  import RufletCodeEditor
#endif
#if canImport(RufletColorPickers)
  import RufletColorPickers
#endif
#if canImport(RufletSpinKit)
  import RufletSpinKit
#endif

/// Which renderer this app uses, and which extensions it carries.
///
/// The renderer is chosen by platform, and the choice is structural: this file
/// compiles only into the iOS and macOS runners, so Android, web, Linux and
/// Windows keep the Flutter (Flet) engine without a branch being taken
/// anywhere. The Ruby application is identical on all of them.
enum RufletEngineChoice {
  /// True unless the app opted out.
  ///
  /// `RufletUseFlutterEngine` in Info.plist sends an Apple build back to the
  /// Flutter client — for a Flutter-only extension, or while migrating.
  static var usesNativeRenderer: Bool {
    let optOut = Bundle.main.object(forInfoDictionaryKey: "RufletUseFlutterEngine")
    if let flag = optOut as? Bool { return !flag }
    if let flag = optOut as? NSNumber { return !flag.boolValue }
    return true
  }

  /// The optional extension modules this target links.
  ///
  /// Each Flet extension has its own Swift product. As those products are
  /// added to the app target, their `canImport` branches belong here; the core
  /// renderer never imports their SDKs.
  static var extensions: [any RufletExtension.Type] {
    var extensions: [any RufletExtension.Type] = []
    #if canImport(RufletMotion)
      extensions.append(RufletMotion.self)
    #endif
    #if canImport(RufletGeolocator)
      extensions.append(RufletGeolocator.self)
    #endif
    #if canImport(RufletAudio)
      extensions.append(RufletAudio.self)
    #endif
    #if canImport(RufletAudioRecorder)
      extensions.append(RufletAudioRecorder.self)
    #endif
    #if canImport(RufletCamera)
      extensions.append(RufletCamera.self)
    #endif
    #if canImport(RufletFlashlight)
      extensions.append(RufletFlashlight.self)
    #endif
    #if canImport(RufletPermissionHandler)
      extensions.append(RufletPermissionHandler.self)
    #endif
    #if canImport(RufletSecureStorage)
      extensions.append(RufletSecureStorage.self)
    #endif
    #if canImport(RufletQRScanner)
      extensions.append(RufletQRScanner.self)
    #endif
    #if canImport(RufletRive)
      extensions.append(RufletRive.self)
    #endif
    #if canImport(RufletLottie)
      extensions.append(RufletLottie.self)
    #endif
    #if canImport(RufletCharts)
      extensions.append(RufletCharts.self)
    #endif
    #if canImport(RufletMap)
      extensions.append(RufletMap.self)
    #endif
    #if canImport(RufletDataTable2)
      extensions.append(RufletDataTable2.self)
    #endif
    #if canImport(RufletVideo)
      extensions.append(RufletVideo.self)
    #endif
    #if canImport(RufletWebView)
      extensions.append(RufletWebView.self)
    #endif
    #if canImport(RufletAds)
      extensions.append(RufletAds.self)
    #endif
    #if canImport(RufletCodeEditor)
      extensions.append(RufletCodeEditor.self)
    #endif
    #if canImport(RufletColorPickers)
      extensions.append(RufletColorPickers.self)
    #endif
    #if canImport(RufletSpinKit)
      extensions.append(RufletSpinKit.self)
    #endif
    return extensions
  }

  @available(*, deprecated, renamed: "extensions")
  static var services: [any RufletServiceBundle.Type] { extensions }
}
