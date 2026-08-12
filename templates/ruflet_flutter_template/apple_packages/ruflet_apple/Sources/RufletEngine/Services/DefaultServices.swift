import Foundation
import RufletProtocol

extension ServiceRegistry {
  /// Registers every service that touches no privacy-gated framework.
  ///
  /// The names are the wire types from `Ruflet::UI::Services::RufletServices`.
  /// The rest — the CoreMotion sensors, CoreLocation and AVFoundation capture —
  /// live in dedicated `Ruflet*` extension products, because
  /// linking those frameworks is what makes iOS demand a usage string and what
  /// App Store review flags. An app links the ones it uses.
  ///
  /// A service Ruby can reach but nothing implements replies "no such method",
  /// naming the bundle that provides it — which is a far better failure than a
  /// call that hangs.
  public func registerDefaults() {
    register(PageService.self) { PageService() }
    registerNamed("View") { PageService() }
    registerNamed("BasePage") { PageService() }
    registerNamed("Pagelet") { PageService() }
    markStreaming([PageService.wireType, "View", "BasePage", "Pagelet"])
    register(WindowService.self) { WindowService() }
    register(BrowserContextMenuService.self) { BrowserContextMenuService() }

    register(ClipboardService.self) { ClipboardService() }
    register(SharedPreferencesService.self) { SharedPreferencesService() }
    register(StoragePathsService.self) { StoragePathsService() }
    register(UrlLauncherService.self) { UrlLauncherService() }
    register(HapticFeedbackService.self) { HapticFeedbackService() }
    register(WakelockService.self) { WakelockService() }
    register(SemanticsAnnouncementService.self) { SemanticsAnnouncementService() }

    register(BatteryService.self) { BatteryService() }
    markStreaming([BatteryService.wireType])
    register(ConnectivityService.self) { ConnectivityService() }
    markStreaming([ConnectivityService.wireType])
    register(ScreenBrightnessService.self) { ScreenBrightnessService() }
    markStreaming([ScreenBrightnessService.wireType])

    register(FilePickerService.self) { FilePickerService() }
    register(ShareService.self) { ShareService() }
  }

  /// Which module provides a wire type the engine cannot answer, so the error
  /// tells an integrator what to link rather than only that it failed.
  public static func bundleProviding(_ wireType: String) -> String? {
    switch wireType.lowercased() {
    case "accelerometer", "useraccelerometer", "gyroscope", "magnetometer", "barometer",
      "shakedetector":
      return "RufletMotion"
    case "geolocator":
      return "RufletGeolocator"
    case "permissionhandler":
      return "RufletPermissionHandler"
    case "securestorage":
      return "RufletSecureStorage"
    case "audio":
      return "RufletAudio"
    case "interstitialad":
      return "RufletAds"
    case "audiorecorder":
      return "RufletAudioRecorder"
    case "camera":
      return "RufletCamera"
    case "flashlight":
      return "RufletFlashlight"
    default:
      return nil
    }
  }
}
