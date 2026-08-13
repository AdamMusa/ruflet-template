import RufletEngine
import RufletProtocol
import SwiftUI

@MainActor
public final class RufletCameraExtension: RufletExtension {
  private var controllers: [Int: RufletCameraController] = [:]
  private var invokeTokens: [Int: UUID] = [:]

  public init() {}

  public var renderedControlTypes: Set<String> { RufletCamera.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    guard control.type == "Camera" else { return nil }
    let controller = controller(for: control)
    attachMethods(to: control, controller: controller)
    return AnyView(CameraControlView(control: control, controller: controller))
  }

  private func controller(for control: RufletControl) -> RufletCameraController {
    if let controller = controllers[control.id] { return controller }
    let controller = RufletCameraController()
    controller.onStateChange = { [weak control] state in
      guard let control, control.hasEventHandler("state_change") else { return }
      control.triggerEvent("state_change", data: Self.value(state.map))
    }
    controller.onStreamImage = { [weak control] image in
      guard let control, control.hasEventHandler("stream_image") else { return }
      control.triggerEvent("stream_image", data: .map([
        "width": .int(Int64(image.width)),
        "height": .int(Int64(image.height)),
        "format": .string(image.format),
        "encoded_format": .string(image.encodedFormat),
        "bytes": .binary(image.bytes),
      ]))
    }
    controllers[control.id] = controller
    return controller
  }

  private func attachMethods(to control: RufletControl, controller: RufletCameraController) {
    guard invokeTokens[control.id] == nil else { return }
    invokeTokens[control.id] = control.addInvokeMethodListener { [weak self, weak control] name, args in
      guard let self, let control else { return .null }
      return try await self.invoke(name, args: args, control: control, controller: controller)
    }
  }

  private func invoke(
    _ name: String,
    args: RufletValue,
    control: RufletControl,
    controller: RufletCameraController
  ) async throws -> RufletValue {
    switch name {
    case "get_available_cameras":
      return .array(RufletCameraController.availableCameras().map { Self.value($0.map) })
    case "initialize":
      guard
        let descriptionMap = args["description"]?.map,
        let name = descriptionMap["name"]?.text
      else { throw RufletCameraError.invalidDescription }
      let description = RufletCameraController.availableCameras().first { $0.name == name }
        ?? RufletCameraDescription(
          name: name,
          lensDirection: RufletCameraLensDirection(
            rawValue: descriptionMap["lens_direction"]?.text ?? "back") ?? .back,
          sensorOrientation: descriptionMap["sensor_orientation"]?.integer ?? 0,
          lensType: RufletCameraLensType(
            rawValue: descriptionMap["lens_type"]?.text ?? "unknown") ?? .unknown)
      let preset = RufletResolutionPreset(rawValue: args["resolution_preset"]?.text ?? "max") ?? .max
      let state = try await controller.initialize(
        description: description,
        resolutionPreset: preset,
        enableAudio: args["enable_audio"]?.bool ?? true,
        fps: args["fps"]?.integer)
      return Self.value(state)
    case "get_exposure_offset_step_size": return .double(controller.exposureOffsetStepSize)
    case "get_max_exposure_offset": return .double(controller.maximumExposureOffset)
    case "get_max_zoom_level": return .double(controller.maximumZoomLevel)
    case "get_min_exposure_offset": return .double(controller.minimumExposureOffset)
    case "get_min_zoom_level": return .double(controller.minimumZoomLevel)
    case "lock_capture_orientation":
      // Capture orientation is owned by native preview connections on Apple.
      controller.setCaptureOrientationLocked(true)
      return .null
    case "unlock_capture_orientation":
      controller.setCaptureOrientationLocked(false)
      return .null
    case "pause_preview": controller.pausePreview(); return .null
    case "resume_preview": controller.resumePreview(); return .null
    case "take_picture": return .binary(try await controller.takePicture())
    case "prepare_for_video_recording": return .null
    case "start_video_recording":
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ruflet-camera-(UUID().uuidString).mov")
      try controller.startVideoRecording(to: url)
      return .null
    case "pause_video_recording": try controller.pauseVideoRecording(); return .null
    case "resume_video_recording": try controller.resumeVideoRecording(); return .null
    case "stop_video_recording": return .binary(try await controller.stopVideoRecording())
    case "supports_image_streaming": return .bool(true)
    case "start_image_stream": try controller.startImageStream(); return .null
    case "stop_image_stream": controller.stopImageStream(); return .null
    case "set_description":
      guard let descriptionMap = args["description"]?.map,
            let name = descriptionMap["name"]?.text,
            let description = RufletCameraController.availableCameras().first(where: { $0.name == name })
      else { throw RufletCameraError.invalidDescription }
      _ = try await controller.initialize(description: description)
      return .null
    case "set_exposure_mode":
      let mode = RufletCameraExposureMode(rawValue: args["mode"]?.text ?? "") ?? .auto
      try controller.setExposureMode(mode)
      return .null
    case "set_exposure_offset":
      guard let offset = args["offset"]?.number else { return .null }
      return .double(try controller.setExposureOffset(offset))
    case "set_exposure_point":
      try controller.setExposurePoint(Self.point(args["point"]))
      return .null
    case "set_flash_mode":
      let mode = RufletCameraFlashMode(rawValue: args["mode"]?.text ?? "") ?? .off
      try controller.setFlashMode(mode)
      return .null
    case "set_focus_mode":
      let mode = RufletCameraFocusMode(rawValue: args["mode"]?.text ?? "") ?? .auto
      try controller.setFocusMode(mode)
      return .null
    case "set_focus_point":
      try controller.setFocusPoint(Self.point(args["point"]))
      return .null
    case "set_zoom_level":
      if let zoom = args["zoom"]?.number { try controller.setZoomLevel(zoom) }
      return .null
    default:
      throw RufletCameraError.unknownMethod(name)
    }
  }

  private static func point(_ value: RufletValue?) -> CGPoint? {
    guard let map = value?.map,
          let dx = map["dx"]?.number ?? map["x"]?.number,
          let dy = map["dy"]?.number ?? map["y"]?.number
    else { return nil }
    return CGPoint(x: dx, y: dy)
  }

  private static func value(_ map: [String: Any]) -> RufletValue {
    .map(map.compactMapValues(value))
  }

  private static func value(_ value: Any) -> RufletValue? {
    switch value {
    case let value as RufletValue: value
    case let value as Bool: .bool(value)
    case let value as Int: .int(Int64(value))
    case let value as Int64: .int(value)
    case let value as Double: .double(value)
    case let value as CGFloat: .double(Double(value))
    case let value as String: .string(value)
    case let value as Data: .binary(value)
    case let value as [String: Any]: .map(value.compactMapValues(Self.value))
    case let value as [Any]: .array(value.compactMap(Self.value))
    default: nil
    }
  }
}

private struct CameraControlView: View {
  @ObservedObject var control: RufletControl
  @ObservedObject var controller: RufletCameraController

  var body: some View {
    RufletCameraPreview(
      session: controller.session,
      previewEnabled: control.boolean("preview_enabled", default: true))
  }
}
