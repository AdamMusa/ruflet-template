import RufletEngine
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  import AVFoundation
#endif

/// The AVFoundation services: audio playback, recording, the camera and the
/// torch — plus the camera's live preview control.
///
/// Linked separately because AVFoundation capture is what makes iOS require
/// `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`. Playback
/// alone needs neither, but the four travel together in Ruflet's service
/// surface, so they share a module rather than splitting a permission across
/// two.
///
/// ```swift
/// RufletAppView(services: [RufletMedia.self])
/// ```
@MainActor
public enum RufletMedia: RufletServiceBundle {
  public static let bundleName = "RufletMedia"

  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("Audio") { AudioService() }
    registry.registerNamed("AudioRecorder") { AudioRecorderService() }
    registry.registerNamed("Camera") { CameraService() }
    registry.registerNamed("Flashlight") { FlashlightService() }

    // Ruflet treats camera as a *visual* service, so it also has a control to
    // render. Registering the view here keeps the preview out of apps that do
    // not link this module.
    ControlRegistry.register("Camera") { node, _ in
      AnyView(CameraControlView(node: node))
    }

    #if canImport(AVFoundation)
      RufletPermissions.installProbe { permission in
        switch permission {
        case "camera": return describe(AVCaptureDevice.authorizationStatus(for: .video))
        case "microphone": return describe(AVCaptureDevice.authorizationStatus(for: .audio))
        default: return nil
        }
      }
      RufletPermissions.installRequest { permission, completion in
        let media: AVMediaType
        switch permission {
        case "camera": media = .video
        case "microphone": media = .audio
        default: return false
        }
        AVCaptureDevice.requestAccess(for: media) { granted in
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
