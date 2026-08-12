import RufletEngine
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  import AVFoundation
#endif

/// Native Apple implementation of Ruflet's QR scanner extension package.
@MainActor
public enum RufletQRScanner: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    let descriptor = ControlDescriptor(
      wireType: "QrcodeScanner", classification: .visible,
      implementation: "RufletQRScanner.QRScannerControlView", rendering: .nativeView,
      supportedEvents: ["detect", "error"],
      supportedMethods: ["reset_zoom_scale", "set_zoom_scale", "start", "stop",
                         "switch_camera", "toggle_torch"])
    ControlRegistry.register(descriptor: descriptor) { node, _ in
      AnyView(QRScannerControlView(node: node))
    }
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "qrcode_scanner", classification: .visible,
        implementation: descriptor.implementation, rendering: .nativeView,
        supportedEvents: descriptor.supportedEvents,
        supportedMethods: descriptor.supportedMethods)
    ) { node, _ in
      AnyView(QRScannerControlView(node: node))
    }

    #if canImport(AVFoundation)
      RufletPermissions.installProbe { permission in
        permission == "camera"
          ? describe(AVCaptureDevice.authorizationStatus(for: .video))
          : nil
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
