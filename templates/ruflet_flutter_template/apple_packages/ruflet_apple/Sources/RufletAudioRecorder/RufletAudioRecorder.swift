import RufletEngine

#if canImport(AVFoundation)
  import AVFoundation
#endif

/// Native Apple implementation of Flet's `flet_audio_recorder` package.
///
/// Applications link this product only when their Ruby control tree contains
/// `AudioRecorder`. Camera, playback, QR scanning and torch code are not
/// dependencies of this extension.
@MainActor
public enum RufletAudioRecorder: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("AudioRecorder") { AudioRecorderService() }

    #if canImport(AVFoundation)
      RufletPermissions.installProbe { permission in
        guard permission == "microphone" else { return nil }
        return permissionStatus(AVCaptureDevice.authorizationStatus(for: .audio))
      }
      RufletPermissions.installRequest { permission, completion in
        guard permission == "microphone" else { return false }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          Task { @MainActor in
            completion(granted ? "granted" : "permanentlyDenied")
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
      case .restricted: return "restricted"
      case .denied: return "permanentlyDenied"
      @unknown default: return "denied"
      }
    }
  #endif
}
