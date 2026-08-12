import Foundation
import RufletEngine
import RufletProtocol

#if canImport(AVFoundation)
  @preconcurrency import AVFoundation
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

/// `Camera` — capture, exposed as method calls the way Flet's camera does.
@MainActor
public final class CameraService: RufletService {
  public static let wireType = "Camera"

  private var selectedDeviceID: String?

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(AVFoundation)
      switch call.name {
      case "get_available_cameras", "get_cameras", "available_cameras":
        let session = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInWideAngleCamera],
          mediaType: .video,
          position: .unspecified)
        completion(
          .success(
            .array(
              session.devices.map { device in
                .map([
                  "id": .string(device.uniqueID),
                  "name": .string(device.localizedName),
                  "lens_direction": .string(device.position == .front ? "front" : "back")
                ])
              })))

      case "has_permission":
        completion(
          .success(.bool(AVCaptureDevice.authorizationStatus(for: .video) == .authorized)))

      case "request_permission":
        AVCaptureDevice.requestAccess(for: .video) { granted in
          Task { @MainActor in completion(.success(.bool(granted))) }
        }

      #if os(iOS)
      case "get_min_zoom_level":
        completion(.success(.double(1)))

      case "get_max_zoom_level":
        guard let device = selectedDevice(call) else {
          return completion(.failure(RufletServiceError.unavailable("No camera is available")))
        }
        completion(.success(.double(Double(device.activeFormat.videoMaxZoomFactor))))

      case "get_min_exposure_offset":
        guard let device = selectedDevice(call) else {
          return completion(.failure(RufletServiceError.unavailable("No camera is available")))
        }
        completion(.success(.double(Double(device.minExposureTargetBias))))

      case "get_max_exposure_offset":
        guard let device = selectedDevice(call) else {
          return completion(.failure(RufletServiceError.unavailable("No camera is available")))
        }
        completion(.success(.double(Double(device.maxExposureTargetBias))))

      case "get_exposure_offset_step_size":
        // AVFoundation accepts a continuous target bias rather than exposing
        // the plugin's discrete Android step size.
        completion(.success(.double(0)))
      #else
      case "get_min_zoom_level", "get_max_zoom_level", "get_min_exposure_offset",
        "get_max_exposure_offset", "get_exposure_offset_step_size":
        completion(.failure(RufletServiceError.platformUnsupported(
          type: Self.wireType, method: call.name, platform: Self.platformName)))
      #endif

      case "set_description":
        selectedDeviceID = Self.descriptionID(call.argument("description"))
        completion(.success(.null))

      #if os(iOS)
      case "set_zoom_level":
        guard let zoom = call.argument("zoom")?.doubleValue,
          let device = selectedDevice(call)
        else {
          return completion(.failure(RufletServiceError.invalidArguments(
            "zoom and an available camera are required")))
        }
        configure(device, completion: completion) {
          device.videoZoomFactor = min(max(CGFloat(zoom), 1), device.activeFormat.videoMaxZoomFactor)
        }

      case "set_exposure_offset":
        guard let offset = call.argument("offset")?.doubleValue,
          let device = selectedDevice(call)
        else {
          return completion(.failure(RufletServiceError.invalidArguments(
            "offset and an available camera are required")))
        }
        do {
          try device.lockForConfiguration()
          device.setExposureTargetBias(Float(offset)) { _ in
            Task { @MainActor in completion(.success(.double(offset))) }
          }
          device.unlockForConfiguration()
        } catch {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        }

      case "set_flash_mode":
        guard let device = selectedDevice(call), device.hasFlash else {
          return completion(.failure(RufletServiceError.unavailable("This camera has no flash")))
        }
        let mode = call.argument("mode")?.stringValue?.lowercased() ?? "off"
        configure(device, completion: completion) {
          device.flashMode = mode == "on" ? .on : (mode == "auto" ? .auto : .off)
        }

      case "set_focus_mode":
        guard let device = selectedDevice(call) else {
          return completion(.failure(RufletServiceError.unavailable("No camera is available")))
        }
        let mode = call.argument("mode")?.stringValue?.lowercased() ?? "auto"
        configure(device, completion: completion) {
          let target: AVCaptureDevice.FocusMode = mode.contains("locked") ? .locked : .continuousAutoFocus
          if device.isFocusModeSupported(target) { device.focusMode = target }
        }

      case "set_exposure_mode":
        guard let device = selectedDevice(call) else {
          return completion(.failure(RufletServiceError.unavailable("No camera is available")))
        }
        let mode = call.argument("mode")?.stringValue?.lowercased() ?? "auto"
        configure(device, completion: completion) {
          let target: AVCaptureDevice.ExposureMode = mode.contains("locked") ? .locked : .continuousAutoExposure
          if device.isExposureModeSupported(target) { device.exposureMode = target }
        }

      case "set_focus_point", "set_exposure_point":
        guard let point = call.argument("point")?.mapValue,
          let x = point["dx"]?.doubleValue ?? point["x"]?.doubleValue,
          let y = point["dy"]?.doubleValue ?? point["y"]?.doubleValue,
          let device = selectedDevice(call)
        else {
          return completion(.failure(RufletServiceError.invalidArguments(
            "point and an available camera are required")))
        }
        configure(device, completion: completion) {
          let focus = CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
          if call.name == "set_focus_point", device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = focus
          } else if call.name == "set_exposure_point", device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = focus
          }
        }
      #else
      case "set_zoom_level", "set_exposure_offset", "set_flash_mode", "set_focus_mode",
        "set_exposure_mode", "set_focus_point", "set_exposure_point":
        completion(.failure(RufletServiceError.platformUnsupported(
          type: Self.wireType, method: call.name, platform: Self.platformName)))
      #endif

      case "supports_image_streaming":
        completion(.success(.bool(false)))

      case "initialize", "lock_capture_orientation", "unlock_capture_orientation",
        "pause_preview", "resume_preview", "take_picture", "prepare_for_video_recording",
        "start_video_recording", "pause_video_recording", "resume_video_recording",
        "stop_video_recording", "start_image_stream", "stop_image_stream":
        completion(.failure(RufletServiceError.platformUnsupported(
          type: Self.wireType, method: call.name, platform: Self.platformName)))

      default:
        completion(
          .failure(RufletServiceError.unsupportedMethod(type: "Camera", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("No camera on this platform")))
    #endif
  }

  #if canImport(AVFoundation)
    private func selectedDevice(_ call: RufletMethodCall) -> AVCaptureDevice? {
      let requested = Self.descriptionID(call.argument("description")) ?? selectedDeviceID
      if let requested, let device = AVCaptureDevice(uniqueID: requested) { return device }
      return AVCaptureDevice.default(for: .video)
    }

    private static func descriptionID(_ value: RufletValue?) -> String? {
      value?["name"]?.stringValue ?? value?["id"]?.stringValue ?? value?.stringValue
    }

    private func configure(
      _ device: AVCaptureDevice,
      completion: @escaping RufletMethodCompletion,
      change: () -> Void
    ) {
      do {
        try device.lockForConfiguration()
        change()
        device.unlockForConfiguration()
        completion(.success(.null))
      } catch {
        completion(.failure(RufletServiceError.failed(error.localizedDescription)))
      }
    }
  #endif

  private static var platformName: String {
    #if os(iOS)
      return "iOS service mode; use the Camera control for capture"
    #elseif os(macOS)
      return "macOS service mode; use the Camera control for capture"
    #else
      return "this Apple platform"
    #endif
  }
}
