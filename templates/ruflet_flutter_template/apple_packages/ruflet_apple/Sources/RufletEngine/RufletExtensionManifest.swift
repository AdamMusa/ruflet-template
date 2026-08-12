import Foundation

/// Source-driven map from the extension packages vendored with Flet 0.80.5
/// to their native Apple Swift products.
///
/// This is metadata, not a registry of implementations. An app links only the
/// products it uses and passes their `RufletExtension` types to its host. That
/// preserves the same package boundaries as Flet while keeping plugin SDKs
/// out of `RufletEngine` and `RufletUI`.
public struct RufletExtensionPackage: Equatable, Sendable {
  public enum Status: String, Equatable, Sendable {
    case available
    case pending
  }

  public let fletPackage: String
  public let swiftProduct: String
  public let status: Status

  public init(fletPackage: String, swiftProduct: String, status: Status) {
    self.fletPackage = fletPackage
    self.swiftProduct = swiftProduct
    self.status = status
  }
}

public enum RufletExtensionManifest {
  /// Update `status` when a dedicated Swift product lands; do not collapse
  /// entries into a catch-all target because that would relink unrelated SDKs.
  public static let packages: [RufletExtensionPackage] = [
    .init(fletPackage: "flet_ads", swiftProduct: "RufletAds", status: .available),
    .init(fletPackage: "flet_audio", swiftProduct: "RufletAudio", status: .available),
    .init(fletPackage: "flet_audio_recorder", swiftProduct: "RufletAudioRecorder", status: .available),
    .init(fletPackage: "flet_camera", swiftProduct: "RufletCamera", status: .available),
    .init(fletPackage: "flet_charts", swiftProduct: "RufletCharts", status: .available),
    .init(fletPackage: "flet_code_editor", swiftProduct: "RufletCodeEditor", status: .available),
    .init(fletPackage: "flet_datatable2", swiftProduct: "RufletDataTable2", status: .available),
    .init(fletPackage: "flet_color_pickers", swiftProduct: "RufletColorPickers", status: .available),
    .init(fletPackage: "flet_flashlight", swiftProduct: "RufletFlashlight", status: .available),
    .init(fletPackage: "flet_geolocator", swiftProduct: "RufletGeolocator", status: .available),
    .init(fletPackage: "flet_lottie", swiftProduct: "RufletLottie", status: .available),
    .init(fletPackage: "flet_map", swiftProduct: "RufletMap", status: .available),
    .init(fletPackage: "flet_permission_handler", swiftProduct: "RufletPermissionHandler", status: .available),
    .init(fletPackage: "flet_rive", swiftProduct: "RufletRive", status: .available),
    .init(fletPackage: "flet_secure_storage", swiftProduct: "RufletSecureStorage", status: .available),
    .init(fletPackage: "flet_spinkit", swiftProduct: "RufletSpinKit", status: .available),
    .init(fletPackage: "flet_video", swiftProduct: "RufletVideo", status: .available),
    .init(fletPackage: "flet_webview", swiftProduct: "RufletWebView", status: .available),
    .init(fletPackage: "ruflet_qrcode_scanner", swiftProduct: "RufletQRScanner", status: .available),
  ]
}
