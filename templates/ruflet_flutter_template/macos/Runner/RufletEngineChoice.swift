import Foundation
import RufletApple
import RufletAppExtensions

#if canImport(RufletAds)
  import RufletAds
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
#if canImport(RufletCharts)
  import RufletCharts
#endif
#if canImport(RufletCodeEditor)
  import RufletCodeEditor
#endif
#if canImport(RufletColorPickers)
  import RufletColorPickers
#endif
#if canImport(RufletDataTable2)
  import RufletDataTable2
#endif
#if canImport(RufletFlashlight)
  import RufletFlashlight
#endif
#if canImport(RufletGeolocator)
  import RufletGeolocator
#endif
#if canImport(RufletLottie)
  import RufletLottie
#endif
#if canImport(RufletMap)
  import RufletMap
#endif
#if canImport(RufletPermissionHandler)
  import RufletPermissionHandler
#endif
#if canImport(RufletQRScanner)
  import RufletQRScanner
#endif
#if canImport(RufletRive)
  import RufletRive
#endif
#if canImport(RufletSecureStorage)
  import RufletSecureStorage
#endif
#if canImport(RufletSpinKit)
  import RufletSpinKit
#endif
#if canImport(RufletVideo)
  import RufletVideo
#endif
#if canImport(RufletWebView)
  import RufletWebView
#endif

/// Apple renderer selection and its ordered native Flet extensions.
enum RufletEngineChoice {
  /// Apple has a single rendering engine. Flutter remains alive only to own
  /// startup and plugin channels; visible Ruflet controls are always SwiftUI.
  static let usesNativeRenderer = true

  /// Keeps the resolved server address or embedded endpoint unchanged. The
  /// native backend selects its transport from this value exactly once.
  static func pageURL(from raw: String) -> URL? {
    RufletPageAddress.parse(raw)
  }

  @MainActor static var extensions: [any RufletExtension] {
    var result = RufletAppExtensionRegistry.extensions
    #if canImport(RufletAds)
      result.append(RufletAds.Extension())
    #endif
    #if canImport(RufletAudio)
      result.append(RufletAudioExtension())
    #endif
    #if canImport(RufletAudioRecorder)
      result.append(RufletAudioRecorderExtension())
    #endif
    #if canImport(RufletCamera)
      result.append(RufletCameraExtension())
    #endif
    #if canImport(RufletCharts)
      result.append(RufletChartsExtension())
    #endif
    #if canImport(RufletCodeEditor)
      result.append(RufletCodeEditorExtension())
    #endif
    #if canImport(RufletColorPickers)
      result.append(RufletColorPickersExtension())
    #endif
    #if canImport(RufletDataTable2)
      result.append(RufletDataTable2Extension())
    #endif
    #if canImport(RufletFlashlight)
      result.append(RufletFlashlightExtension())
    #endif
    #if canImport(RufletGeolocator)
      result.append(RufletGeolocatorExtension())
    #endif
    #if canImport(RufletLottie)
      result.append(RufletLottieExtension())
    #endif
    #if canImport(RufletMap)
      result.append(RufletMap.Extension())
    #endif
    #if canImport(RufletPermissionHandler)
      result.append(RufletPermissionHandlerExtension())
    #endif
    #if canImport(RufletQRScanner)
      result.append(RufletQRScannerExtension())
    #endif
    #if canImport(RufletRive)
      result.append(RufletRiveExtension())
    #endif
    #if canImport(RufletSecureStorage)
      result.append(RufletSecureStorageExtension())
    #endif
    #if canImport(RufletSpinKit)
      result.append(RufletSpinKitExtension())
    #endif
    #if canImport(RufletVideo)
      result.append(RufletVideoExtension())
    #endif
    #if canImport(RufletWebView)
      result.append(RufletWebViewExtension())
    #endif
    return result
  }
}
