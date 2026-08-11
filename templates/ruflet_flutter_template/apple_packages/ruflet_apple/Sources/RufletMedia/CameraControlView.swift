import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  import AVFoundation
  import CoreImage
#endif

/// `Camera` — a live preview plus the capture methods.
///
/// Ruflet treats camera as a *visual* service (`Page#visual_service_type?`), so
/// unlike the other services it appears in the control tree and has to render.
public struct CameraControlView: View {
  let node: ControlNode
  @StateObject private var model = CameraModel()

  public init(node: ControlNode) { self.node = node }
  @Environment(\.rufletEvents) private var events

  public var body: some View {
    Group {
      #if canImport(AVFoundation) && !targetEnvironment(simulator)
        if model.isInitialized && (node.bool("preview_enabled") ?? true) {
          CameraPreview(model: model)
            .overlay {
              if let contentID = node.controlID(forKey: "content") {
                ControlView(id: contentID, axis: .none)
              }
            }
        } else {
          // Flet's Camera is a zero-sized LayoutControl until initialize has
          // produced a controller. `preview_enabled: false` likewise hides the
          // preview without stopping capture or recording.
          EmptyView()
        }
      #else
        EmptyView()
      #endif
    }
    .onAppear { model.attach(node: node, events: events) }
    .onDisappear { model.stop() }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, node: node, events: events, completion: completion)
    }
  }
}

@MainActor
final class CameraModel: NSObject, ObservableObject {
  @Published private(set) var isInitialized = false
  #if canImport(AVFoundation)
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoQueue = DispatchQueue(label: "com.izeesoft.ruflet.camera.images")
    private var pendingCapture: RufletMethodCompletion?
    private var pendingRecording: RufletMethodCompletion?
    private var recordingURL: URL?
    private var configured = false
    private var streamingImages = false
    private var captureOrientationLocked = false
    private var recordingPaused = false
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var lastDescription: RufletValue?
    private var lastEnableAudio = true
    private var lastResolutionPreset: String?
    private var lastFPS: Int?
    private var control: ControlNode?
    private var events = RufletEventSink()
  #endif

  func attach(node: ControlNode, events: RufletEventSink) {
    #if canImport(AVFoundation)
      control = node
      self.events = events
    #endif
  }

  func stop() {
    #if canImport(AVFoundation) && !targetEnvironment(simulator)
      guard session.isRunning else { return }
      let session = session
      Task { [weak self] in
        await Task.detached { session.stopRunning() }.value
        self?.isInitialized = false
      }
    #endif
  }

  #if canImport(AVFoundation)
    private func configure(
      node: ControlNode,
      description: RufletValue?,
      enableAudio: Bool,
      resolutionPreset: String?,
      fps: Int?
    ) throws {
      if configured { return }
      configured = true

      session.beginConfiguration()
      defer { session.commitConfiguration() }
      session.sessionPreset = Self.sessionPreset(resolutionPreset)

      let requestedName = description?["name"]?.stringValue
        ?? description?["id"]?.stringValue
      let wantsFront = description?["lens_direction"]?.stringValue?.lowercased() == "front"
      let devices = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera],
        mediaType: .video,
        position: wantsFront ? .front : .back
      ).devices
      guard let device = devices.first(where: {
        requestedName == nil || $0.uniqueID == requestedName || $0.localizedName == requestedName
      }) ?? devices.first else {
        configured = false
        throw RufletServiceError.unavailable("No matching camera is available")
      }
      let input = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(input) else {
        configured = false
        throw RufletServiceError.unavailable("The selected camera cannot be attached")
      }
      session.addInput(input)
      if let fps, fps > 0,
        device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
          $0.minFrameRate <= Double(fps) && Double(fps) <= $0.maxFrameRate
        })
      {
        try device.lockForConfiguration()
        let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.unlockForConfiguration()
      }
      if enableAudio, let microphone = AVCaptureDevice.default(for: .audio) {
        let audioInput = try AVCaptureDeviceInput(device: microphone)
        if session.canAddInput(audioInput) { session.addInput(audioInput) }
      }
      if session.canAddOutput(photoOutput) {
        session.addOutput(photoOutput)
      }
      if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
    }

    private static func sessionPreset(_ value: String?) -> AVCaptureSession.Preset {
      switch value?.lowercased() {
      case "low": return .low
      case "medium": return .medium
      case "high": return .high
      case "very_high": return .hd1280x720
      case "ultra_high": return .hd1920x1080
      case "max": return .photo
      default: return .photo
      }
    }
  #endif

  func handle(
    _ call: RufletMethodCall,
    node: ControlNode,
    events: RufletEventSink,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(AVFoundation)
      switch call.name {
      case "get_available_cameras", "get_cameras", "available_cameras":
        let devices = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInWideAngleCamera],
          mediaType: .video,
          position: .unspecified
        ).devices
        completion(.success(.array(devices.map { device in
          .map([
            "name": .string(device.uniqueID),
            "lens_direction": .string(device.position == .front ? "front" : "back"),
            "sensor_orientation": .int(device.position == .front ? 270 : 90),
            "lens_type": .string("wide")
          ])
        })))
      case "initialize":
        #if targetEnvironment(simulator)
          completion(.failure(RufletServiceError.unavailable("No camera on this simulator")))
        #else
          do {
            control = node
            self.events = events
            lastDescription = call.argument("description")
            guard let description = lastDescription,
              Self.isCameraDescription(description)
            else {
              throw RufletServiceError.invalidArguments(
                "Camera description is required for initialization.")
            }
            lastEnableAudio = call.argument("enable_audio")?.boolValue ?? true
            lastResolutionPreset = call.argument("resolution_preset")?.stringValue
            lastFPS = call.argument("fps")?.intValue.map { Int($0) }
            try configure(
              node: node,
              description: description,
              enableAudio: lastEnableAudio,
              resolutionPreset: lastResolutionPreset,
              fps: lastFPS)
            startSession(completion: completion)
          } catch {
            configured = false
            completion(.failure(error))
          }
        #endif
      case "take_picture", "capture":
        #if targetEnvironment(simulator)
          completion(.failure(RufletServiceError.unavailable("No camera on this simulator")))
        #else
        guard configured, session.isRunning else {
          completion(.failure(RufletServiceError.unavailable(
            "Camera is not initialized. Call initialize first.")))
          return
        }
        guard pendingCapture == nil else {
          return completion(.failure(RufletServiceError.failed("A capture is already in flight")))
        }
        pendingCapture = completion
        emitState(takingPicture: true)
        let settings = AVCapturePhotoSettings()
        if videoDevice?.hasFlash == true { settings.flashMode = flashMode }
        photoOutput.capturePhoto(with: settings, delegate: self)
        #endif
      case "pause_preview":
        pauseSession(completion: completion)
      case "resume_preview":
        startSession(completion: completion)
      case "get_min_zoom_level":
        withVideoDevice(completion) { _ in .double(1) }
      case "get_max_zoom_level":
        #if os(iOS)
        withVideoDevice(completion) { device in
          .double(Double(device.activeFormat.videoMaxZoomFactor))
        }
        #else
        completion(.failure(Self.platformUnsupported(call.name)))
        #endif
      case "get_min_exposure_offset":
        #if os(iOS)
        withVideoDevice(completion) { .double(Double($0.minExposureTargetBias)) }
        #else
        completion(.failure(Self.platformUnsupported(call.name)))
        #endif
      case "get_max_exposure_offset":
        #if os(iOS)
        withVideoDevice(completion) { .double(Double($0.maxExposureTargetBias)) }
        #else
        completion(.failure(Self.platformUnsupported(call.name)))
        #endif
      case "get_exposure_offset_step_size":
        // iOS accepts a continuous target bias, so zero is the camera plugin's
        // canonical representation of no discrete step.
        withVideoDevice(completion) { _ in .double(0) }
      case "set_zoom_level":
        #if os(iOS)
        guard call.argument("zoom")?.doubleValue != nil else {
          completion(.success(.null))
          return
        }
        configureDevice(call, completion: completion) { device in
          let zoom = call.argument("zoom")!.doubleValue!
          device.videoZoomFactor = min(
            max(CGFloat(zoom), 1), device.activeFormat.videoMaxZoomFactor)
          return .null
        }
        #else
        completion(.failure(Self.platformUnsupported(call.name)))
        #endif
      case "set_exposure_offset":
        #if os(iOS)
        guard let offset = call.argument("offset")?.doubleValue else {
          completion(.success(.null))
          return
        }
        guard let device = videoDevice else {
          completion(.failure(RufletServiceError.unavailable(
            "Camera is not initialized. Call initialize first.")))
          return
        }
        do {
          try device.lockForConfiguration()
          device.setExposureTargetBias(Float(offset)) { _ in
            Task { @MainActor in
              device.unlockForConfiguration()
              self.emitState()
              completion(.success(.double(offset)))
            }
          }
        } catch { completion(.failure(error)) }
        #else
        completion(.failure(Self.platformUnsupported(call.name)))
        #endif
      case "set_flash_mode":
        guard let value = call.argument("mode")?.stringValue?.lowercased(),
          ["off", "on", "auto", "torch"].contains(value)
        else {
          completion(.success(.null))
          return
        }
        configureDevice(call, completion: completion) { device in
          let mode: AVCaptureDevice.FlashMode = value == "on" || value == "torch"
            ? .on : (value == "auto" ? .auto : .off)
          guard device.isFlashModeSupported(mode) else {
            throw RufletServiceError.unavailable("The selected flash mode is unavailable")
          }
          device.flashMode = mode
          self.flashMode = mode
          return .null
        }
      case "set_focus_mode":
        guard let value = call.argument("mode")?.stringValue?.lowercased(),
          ["auto", "locked"].contains(value)
        else {
          completion(.success(.null))
          return
        }
        configureDevice(call, completion: completion) { device in
          let mode: AVCaptureDevice.FocusMode = value == "locked" ? .locked : .continuousAutoFocus
          guard device.isFocusModeSupported(mode) else {
            throw RufletServiceError.unavailable("The selected focus mode is unavailable")
          }
          device.focusMode = mode
          return .null
        }
      case "set_exposure_mode":
        guard let value = call.argument("mode")?.stringValue?.lowercased(),
          ["auto", "locked"].contains(value)
        else {
          completion(.success(.null))
          return
        }
        configureDevice(call, completion: completion) { device in
          let mode: AVCaptureDevice.ExposureMode = value == "locked" ? .locked : .continuousAutoExposure
          guard device.isExposureModeSupported(mode) else {
            throw RufletServiceError.unavailable("The selected exposure mode is unavailable")
          }
          device.exposureMode = mode
          return .null
        }
      case "set_focus_point", "set_exposure_point":
        configureDevice(call, completion: completion) { device in
          let value = call.argument("point")?.mapValue
          let x = value?["dx"]?.doubleValue ?? value?["x"]?.doubleValue
          let y = value?["dy"]?.doubleValue ?? value?["y"]?.doubleValue
          // camera_avfoundation accepts null to reset the metering point. Its
          // native reset target is the center of the sensor.
          let point = CGPoint(
            x: min(max(x ?? 0.5, 0), 1),
            y: min(max(y ?? 0.5, 0), 1))
          if call.name == "set_focus_point" {
            guard device.isFocusPointOfInterestSupported else {
              throw RufletServiceError.unavailable("Focus points are unavailable")
            }
            device.focusPointOfInterest = point
          } else {
            guard device.isExposurePointOfInterestSupported else {
              throw RufletServiceError.unavailable("Exposure points are unavailable")
            }
            device.exposurePointOfInterest = point
          }
          return .null
        }
      case "lock_capture_orientation":
        captureOrientationLocked = true
        applyOrientation(call.argument("orientation")?.stringValue)
        emitState()
        completion(.success(.null))
      case "unlock_capture_orientation":
        captureOrientationLocked = false
        emitState()
        completion(.success(.null))
      case "prepare_for_video_recording":
        completion(.success(.null))
      case "start_video_recording":
        startVideoRecording(completion: completion)
      case "pause_video_recording":
        if #available(iOS 18.0, macOS 15.0, *) {
          movieOutput.pauseRecording()
          recordingPaused = true
          emitState()
          completion(.success(.null))
        } else {
          completion(.failure(RufletServiceError.unavailable(
            "Pausing a camera recording requires iOS 18 or macOS 15.")))
        }
      case "resume_video_recording":
        if #available(iOS 18.0, macOS 15.0, *) {
          movieOutput.resumeRecording()
          recordingPaused = false
          emitState()
          completion(.success(.null))
        } else {
          completion(.failure(RufletServiceError.unavailable(
            "Resuming a camera recording requires iOS 18 or macOS 15.")))
        }
      case "stop_video_recording":
        guard movieOutput.isRecording else {
          completion(.failure(RufletServiceError.unavailable("No video recording is active")))
          return
        }
        pendingRecording = completion
        movieOutput.stopRecording()
      case "set_description":
        guard let description = call.argument("description"),
          Self.isCameraDescription(description)
        else {
          completion(.success(.null))
          return
        }
        guard configured else {
          completion(.failure(RufletServiceError.unavailable(
            "Camera is not initialized. Call initialize first.")))
          return
        }
        let wasRunning = session.isRunning
        let session = session
        Task { [weak self] in
          if wasRunning {
            await Task.detached { session.stopRunning() }.value
          }
          guard let self else { return }
          do {
            self.resetConfiguration()
            self.lastDescription = description
            try self.configure(
              node: node, description: self.lastDescription,
              enableAudio: self.lastEnableAudio, resolutionPreset: self.lastResolutionPreset,
              fps: self.lastFPS)
            if wasRunning {
              await Task.detached { session.startRunning() }.value
            }
            self.isInitialized = !wasRunning || session.isRunning
            self.emitState()
            completion(.success(.null))
          } catch { completion(.failure(error)) }
        }
      case "start", "resume":
        startSession(completion: completion)
      case "stop", "pause":
        stop()
        completion(.success(.null))
      case "start_image_stream":
        startImageStream(node: node, events: events, completion: completion)
      case "stop_image_stream":
        stopImageStream(completion: completion)
      case "supports_image_streaming":
        guard configured else {
          completion(.failure(RufletServiceError.unavailable("Camera is not initialized. Call initialize first.")))
          return
        }
        completion(.success(.bool(true)))
      default:
        completion(.failure(rufletUnsupported("Camera", call)))
      }
    #else
      completion(
        .failure(RufletServiceError.unavailable("No capture device on this platform")))
    #endif
  }

  #if canImport(AVFoundation)
    private static func isCameraDescription(_ value: RufletValue) -> Bool {
      value["name"]?.stringValue != nil && value["sensor_orientation"]?.intValue != nil
    }

    private static func platformUnsupported(_ method: String) -> RufletServiceError {
      .platformUnsupported(type: "Camera", method: method, platform: "macOS")
    }

    private var videoDevice: AVCaptureDevice? {
      session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
        .first(where: { $0.device.hasMediaType(.video) })?.device
    }

    private func startSession(completion: @escaping RufletMethodCompletion) {
      guard configured else {
        completion(.failure(RufletServiceError.unavailable("Camera is not initialized. Call initialize first.")))
        return
      }
      guard !session.isRunning else {
        isInitialized = true
        emitState()
        completion(.success(.null))
        return
      }
      let session = session
      Task { [weak self] in
        await Task.detached { session.startRunning() }.value
        guard let self else { return }
        self.isInitialized = session.isRunning
        self.emitState()
        completion(.success(.null))
      }
    }

    private func pauseSession(completion: @escaping RufletMethodCompletion) {
      guard session.isRunning else {
        completion(.success(.null))
        return
      }
      let session = session
      Task { [weak self] in
        await Task.detached { session.stopRunning() }.value
        self?.emitState()
        completion(.success(.null))
      }
    }

    private func withVideoDevice(
      _ completion: @escaping RufletMethodCompletion,
      value: (AVCaptureDevice) -> RufletValue
    ) {
      guard let device = videoDevice else {
        completion(.failure(RufletServiceError.unavailable("Camera is not initialized. Call initialize first.")))
        return
      }
      completion(.success(value(device)))
    }

    private func configureDevice(
      _ call: RufletMethodCall,
      completion: @escaping RufletMethodCompletion,
      change: (AVCaptureDevice) throws -> RufletValue
    ) {
      guard let device = videoDevice else {
        completion(.failure(RufletServiceError.unavailable("Camera is not initialized. Call initialize first.")))
        return
      }
      do {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        let result = try change(device)
        emitState()
        completion(.success(result))
      } catch { completion(.failure(error)) }
    }

    private func resetConfiguration() {
      videoOutput.setSampleBufferDelegate(nil, queue: nil)
      session.beginConfiguration()
      session.inputs.forEach(session.removeInput)
      session.outputs.forEach(session.removeOutput)
      session.commitConfiguration()
      configured = false
      streamingImages = false
      isInitialized = false
    }

    private func applyOrientation(_ name: String?) {
      #if canImport(UIKit)
        let orientation: AVCaptureVideoOrientation
        switch name?.lowercased() {
        case "landscape_left": orientation = .landscapeLeft
        case "landscape_right": orientation = .landscapeRight
        case "portrait_down": orientation = .portraitUpsideDown
        default: orientation = .portrait
        }
        for connection in [photoOutput.connection(with: .video), movieOutput.connection(with: .video),
          videoOutput.connection(with: .video)].compactMap({ $0 }) where connection.isVideoOrientationSupported {
          connection.videoOrientation = orientation
        }
      #endif
    }

    private func startVideoRecording(completion: @escaping RufletMethodCompletion) {
      guard configured, session.isRunning else {
        completion(.failure(RufletServiceError.unavailable("Camera is not initialized. Call initialize first.")))
        return
      }
      guard !movieOutput.isRecording else {
        completion(.failure(RufletServiceError.failed("A video recording is already active")))
        return
      }
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ruflet-camera-\(UUID().uuidString).mov")
      recordingURL = url
      recordingPaused = false
      movieOutput.startRecording(to: url, recordingDelegate: self)
      emitState()
      completion(.success(.null))
    }

    private func startImageStream(
      node: ControlNode,
      events: RufletEventSink,
      completion: @escaping RufletMethodCompletion
    ) {
      control = node
      self.events = events
      guard configured else {
        completion(.failure(RufletServiceError.unavailable("Camera is not initialized. Call initialize first.")))
        return
      }
      guard !streamingImages else { return completion(.success(.null)) }
      videoOutput.alwaysDiscardsLateVideoFrames = true
      videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
      ]
      videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
      session.beginConfiguration()
      if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
      session.commitConfiguration()
      streamingImages = session.outputs.contains { $0 === videoOutput }
      emitState()
      completion(.success(.null))
    }

    private func stopImageStream(completion: @escaping RufletMethodCompletion) {
      guard streamingImages else { return completion(.success(.null)) }
      videoOutput.setSampleBufferDelegate(nil, queue: nil)
      session.beginConfiguration()
      session.removeOutput(videoOutput)
      session.commitConfiguration()
      streamingImages = false
      emitState()
      completion(.success(.null))
    }

    private func emitState(takingPicture: Bool = false) {
      guard let control else { return }
      events.fire(control, "state_change", data: stateValue(takingPicture: takingPicture))
    }

    private func stateValue(takingPicture: Bool = false) -> RufletValue {
      let input = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first
      let device = input?.device
      var state: [String: RufletValue] = [
        "is_initialized": .bool(isInitialized),
        "is_recording_video": .bool(movieOutput.isRecording),
        "is_recording_paused": .bool(recordingPaused),
        "is_taking_picture": .bool(takingPicture),
        "is_streaming_images": .bool(streamingImages),
        "is_preview_paused": .bool(!session.isRunning),
        "is_capture_orientation_locked": .bool(captureOrientationLocked),
        "has_error": .bool(false)
      ]
      if let device {
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let width = Double(dimensions.width)
        let height = Double(dimensions.height)
        state["description"] = .map([
          "name": .string(device.uniqueID),
          "lens_direction": .string(device.position == .front ? "front" : "back"),
          "sensor_orientation": .int(device.position == .front ? 270 : 90),
          "lens_type": .string("wide")
        ])
        state["device_orientation"] = .string("portrait_up")
        let flashName = flashMode == .on ? "on" : (flashMode == .off ? "off" : "auto")
        state["flash_mode"] = .string(flashName)
        state["exposure_mode"] = .string(
          device.exposureMode == .continuousAutoExposure ? "auto" : "locked")
        state["focus_mode"] = .string(
          device.focusMode == .continuousAutoFocus ? "auto" : "locked")
        state["exposure_point_supported"] = .bool(device.isExposurePointOfInterestSupported)
        state["focus_point_supported"] = .bool(device.isFocusPointOfInterestSupported)
        state["preview_size"] = .map([
          "width": .double(width),
          "height": .double(height)
        ])
        if height > 0 { state["aspect_ratio"] = .double(width / height) }
      }
      return .map(state)
    }
  #endif
}

#if canImport(AVFoundation)
  extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
      _ output: AVCapturePhotoOutput,
      didFinishProcessingPhoto photo: AVCapturePhoto,
      error: Error?
    ) {
      let data = photo.fileDataRepresentation()
      Task { @MainActor in
        let completion = pendingCapture
        pendingCapture = nil
        if let error {
          emitState()
          completion?(.failure(RufletServiceError.failed(error.localizedDescription)))
        } else if let data {
          emitState()
          completion?(.success(.binary([UInt8](data))))
        } else {
          completion?(.failure(RufletServiceError.failed("The photo produced no data")))
        }
      }
    }
  }

  extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
      _ output: AVCaptureFileOutput,
      didFinishRecordingTo outputFileURL: URL,
      from connections: [AVCaptureConnection],
      error: Error?
    ) {
      let data = try? Data(contentsOf: outputFileURL)
      try? FileManager.default.removeItem(at: outputFileURL)
      Task { @MainActor in
        let completion = pendingRecording
        pendingRecording = nil
        recordingURL = nil
        recordingPaused = false
        emitState()
        if let error {
          completion?(.failure(RufletServiceError.failed(error.localizedDescription)))
        } else if let data {
          completion?(.success(.binary([UInt8](data))))
        } else {
          completion?(.failure(RufletServiceError.failed("The video recording produced no data")))
        }
      }
    }

    nonisolated func fileOutput(
      _ output: AVCaptureFileOutput,
      didStartRecordingTo fileURL: URL,
      from connections: [AVCaptureConnection]
    ) {
      Task { @MainActor in emitState() }
    }
  }

  extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
      _ output: AVCaptureOutput,
      didOutput sampleBuffer: CMSampleBuffer,
      from connection: AVCaptureConnection
    ) {
      guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
      let image = CIImage(cvPixelBuffer: imageBuffer)
      let context = CIContext(options: nil)
      guard let data = context.jpegRepresentation(
        of: image,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        options: [:]
      ) else { return }
      let width = CVPixelBufferGetWidth(imageBuffer)
      let height = CVPixelBufferGetHeight(imageBuffer)
      Task { @MainActor [data] in
        guard let control = self.control else { return }
        self.events.fire(control, "stream_image", data: .map([
          "width": .int(Int64(width)),
          "height": .int(Int64(height)),
          "format": .string("bgra8888"),
          "encoded_format": .string("jpeg"),
          "bytes": .binary([UInt8](data))
        ]))
      }
    }
  }

  #if !targetEnvironment(simulator)
    /// `AVCaptureVideoPreviewLayer` is a CALayer, so it needs a hosting view on
    /// each platform.
    private struct CameraPreview {
      let model: CameraModel
    }

    #if canImport(UIKit)
      final class CameraPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
      }

      extension CameraPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> CameraPreviewView {
          let view = CameraPreviewView()
          view.previewLayer.session = model.session
          view.previewLayer.videoGravity = .resizeAspectFill
          return view
        }
        func updateUIView(_ view: CameraPreviewView, context: Context) {}
      }
    #elseif canImport(AppKit)
      extension CameraPreview: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
          let view = NSView()
          view.wantsLayer = true
          let preview = AVCaptureVideoPreviewLayer(session: model.session)
          preview.videoGravity = .resizeAspectFill
          preview.frame = view.bounds
          preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
          view.layer = preview
          return view
        }
        func updateNSView(_ view: NSView, context: Context) {}
      }
    #endif
  #endif
#endif
