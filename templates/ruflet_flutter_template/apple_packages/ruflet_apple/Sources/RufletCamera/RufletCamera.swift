import RufletEngine
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  import AVFoundation
#endif

/// Native Apple implementation of Flet's `flet_camera` package.
@MainActor
public enum RufletCamera: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("Camera") { CameraService() }

    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "Camera", classification: .visible,
        implementation: "RufletCamera.CameraControlView", rendering: .nativeView,
        supportedEvents: ["state_change", "stream_image"],
        supportedMethods: [
          "get_available_cameras", "get_exposure_offset_step_size",
          "get_max_exposure_offset", "get_max_zoom_level",
          "get_min_exposure_offset", "get_min_zoom_level", "initialize",
          "lock_capture_orientation", "pause_preview", "pause_video_recording",
          "prepare_for_video_recording", "resume_preview", "resume_video_recording",
          "set_description", "set_exposure_mode", "set_exposure_offset",
          "set_exposure_point", "set_flash_mode", "set_focus_mode",
          "set_focus_point", "set_zoom_level", "start_image_stream",
          "start_video_recording", "stop_image_stream", "stop_video_recording",
          "supports_image_streaming", "take_picture", "unlock_capture_orientation",
        ])
    ) { node, _ in
      AnyView(CameraControlView(node: node))
    }

    #if canImport(AVFoundation)
      RufletPermissions.installProbe { permission in
        guard permission == "camera" else { return nil }
        return permissionStatus(AVCaptureDevice.authorizationStatus(for: .video))
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
    private static func permissionStatus(_ status: AVAuthorizationStatus) -> String {
      switch status {
      case .authorized: return "granted"
      case .notDetermined: return "denied"
      default: return "permanently_denied"
      }
    }
  #endif
}
