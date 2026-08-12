import RufletEngine
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  import AVFoundation
#endif

/// Audio playback and Ruflet's QR scanner extension.
///
/// Legacy applications may keep linking this product for `Audio` and
/// `QrcodeScanner`. Flet's camera, recorder and flashlight packages are
/// independent products and deliberately are not dependencies of this module.
///
/// ```swift
/// RufletAppView(extensions: [RufletMedia.self])
/// ```
@MainActor
public enum RufletMedia: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("Audio") { AudioService() }
    // Flet services receive `update()` whenever their wire properties change.
    // Audio owns a persistent player, so it needs the same lifecycle hook for
    // source, volume, balance, rate and release-mode updates made after mount.
    registry.markStreaming(["Audio"])

    let qrDescriptor = ControlDescriptor(
      wireType: "QrcodeScanner", classification: .visible,
      implementation: "RufletMedia.QRScannerControlView", rendering: .nativeView,
      supportedEvents: ["detect", "error"],
      supportedMethods: ["reset_zoom_scale", "set_zoom_scale", "start", "stop",
                         "switch_camera", "toggle_torch"])
    ControlRegistry.register(descriptor: qrDescriptor) { node, _ in
      AnyView(QRScannerControlView(node: node))
    }
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "qrcode_scanner", classification: .visible,
        implementation: qrDescriptor.implementation, rendering: .nativeView,
        supportedEvents: qrDescriptor.supportedEvents,
        supportedMethods: qrDescriptor.supportedMethods)
    ) { node, _ in
      AnyView(QRScannerControlView(node: node))
    }

    #if canImport(AVFoundation)
      RufletPermissions.installProbe { permission in
        switch permission {
        case "camera": return describe(AVCaptureDevice.authorizationStatus(for: .video))
        default: return nil
        }
      }
      RufletPermissions.installRequest { permission, completion in
        guard permission == "camera" else { return false }
        AVCaptureDevice.requestAccess(for: .video) { granted in
          Task { @MainActor in
            completion(granted ? "granted" : "permanently_denied")
          }
        }
        return true
      }
    #endif
  }

  #if canImport(AVFoundation)
    private static func describe(_ status: AVAuthorizationStatus) -> String {
      switch status {
      case .authorized: return "granted"
      case .notDetermined: return "denied"
      default: return "permanently_denied"
      }
    }
  #endif
}
