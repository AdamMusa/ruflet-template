@preconcurrency import AVFoundation
import Combine
import Foundation

@MainActor
public final class RufletCameraController: NSObject, ObservableObject,
  @preconcurrency AVCapturePhotoCaptureDelegate,
  AVCaptureVideoDataOutputSampleBufferDelegate,
  AVCaptureFileOutputRecordingDelegate
{
  public let session = AVCaptureSession()
  public var onStateChange: (@MainActor @Sendable (RufletCameraState) -> Void)?
  public var onStreamImage: (@MainActor @Sendable (RufletCameraImage) -> Void)?

  @Published public private(set) var state = RufletCameraState()

  private let photoOutput = AVCapturePhotoOutput()
  private let movieOutput = AVCaptureMovieFileOutput()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let sessionQueue = DispatchQueue(label: "ruflet.camera.session")
  private let streamQueue = DispatchQueue(label: "ruflet.camera.stream")
  private var device: AVCaptureDevice?
  private var pendingPhoto: CheckedContinuation<Data, Error>?
  private var pendingMovie: CheckedContinuation<Data, Error>?
  private var movieURL: URL?
  private var processingImage = false

  public static func availableCameras() -> [RufletCameraDescription] {
    discoverySession().devices.map(RufletCameraMapping.description)
  }

  public func initialize(
    description: RufletCameraDescription,
    resolutionPreset: RufletResolutionPreset = .max,
    enableAudio: Bool = true,
    fps: Int? = nil
  ) async throws -> [String: Any] {
    guard let selectedDevice = Self.discoverySession().devices.first(where: {
      $0.uniqueID == description.name
    }) else {
      throw RufletCameraError.cameraNotFound(description.name)
    }
    let videoInput = try AVCaptureDeviceInput(device: selectedDevice)
    let audioInput = enableAudio
      ? AVCaptureDevice.default(for: .audio).flatMap { try? AVCaptureDeviceInput(device: $0) }
      : nil

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      sessionQueue.async { [session, photoOutput, movieOutput, videoOutput] in
        session.beginConfiguration()
        defer {
          session.commitConfiguration()
          continuation.resume()
        }
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        if session.canSetSessionPreset(resolutionPreset.sessionPreset) {
          session.sessionPreset = resolutionPreset.sessionPreset
        }
        if session.canAddInput(videoInput) { session.addInput(videoInput) }
        if let audioInput, session.canAddInput(audioInput) { session.addInput(audioInput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
      }
    }

    if let fps, let range = selectedDevice.activeFormat.videoSupportedFrameRateRanges.first(
      where: { $0.minFrameRate <= Double(fps) && $0.maxFrameRate >= Double(fps) })
    {
      _ = range
      try selectedDevice.lockForConfiguration()
      let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
      selectedDevice.activeVideoMinFrameDuration = duration
      selectedDevice.activeVideoMaxFrameDuration = duration
      selectedDevice.unlockForConfiguration()
    }

    device = selectedDevice
    state.description = RufletCameraMapping.description(for: selectedDevice)
    state.exposurePointSupported = selectedDevice.isExposurePointOfInterestSupported
    state.focusPointSupported = selectedDevice.isFocusPointOfInterestSupported
    state.isInitialized = true
    sessionQueue.async { [session] in
      if !session.isRunning { session.startRunning() }
    }
    emitState()
    return state.map
  }

  public func pausePreview() {
    sessionQueue.async { [session] in session.stopRunning() }
    state.isPreviewPaused = true
    emitState()
  }

  public func resumePreview() {
    sessionQueue.async { [session] in session.startRunning() }
    state.isPreviewPaused = false
    emitState()
  }

  public func setCaptureOrientationLocked(_ locked: Bool) {
    state.isCaptureOrientationLocked = locked
    emitState()
  }

  public func takePicture() async throws -> Data {
    guard state.isInitialized else { throw RufletCameraError.notInitialized }
    state.isTakingPicture = true
    emitState()
    return try await withCheckedThrowingContinuation { continuation in
      pendingPhoto = continuation
      photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
  }

  public func startVideoRecording(to url: URL) throws {
    guard state.isInitialized else { throw RufletCameraError.notInitialized }
    guard !movieOutput.isRecording else { throw RufletCameraError.alreadyRecording }
    movieURL = url
    movieOutput.startRecording(to: url, recordingDelegate: self)
    state.isRecordingVideo = true
    emitState()
  }

  public func pauseVideoRecording() throws {
    guard movieOutput.isRecording else { throw RufletCameraError.notRecording }
    #if os(iOS)
    guard #available(iOS 18.0, *) else {
      throw RufletCameraError.unsupportedOnCurrentApplePlatform("pause_video_recording")
    }
    #endif
    movieOutput.pauseRecording()
    state.isRecordingPaused = true
    emitState()
  }

  public func resumeVideoRecording() throws {
    guard movieOutput.isRecording else { throw RufletCameraError.notRecording }
    #if os(iOS)
    guard #available(iOS 18.0, *) else {
      throw RufletCameraError.unsupportedOnCurrentApplePlatform("resume_video_recording")
    }
    #endif
    movieOutput.resumeRecording()
    state.isRecordingPaused = false
    emitState()
  }

  public func stopVideoRecording() async throws -> Data {
    guard movieOutput.isRecording else { throw RufletCameraError.notRecording }
    return try await withCheckedThrowingContinuation { continuation in
      pendingMovie = continuation
      movieOutput.stopRecording()
    }
  }

  public func startImageStream() throws {
    guard state.isInitialized else { throw RufletCameraError.notInitialized }
    videoOutput.setSampleBufferDelegate(self, queue: streamQueue)
    state.isStreamingImages = true
    emitState()
  }

  public func stopImageStream() {
    videoOutput.setSampleBufferDelegate(nil, queue: nil)
    processingImage = false
    state.isStreamingImages = false
    emitState()
  }

  public func setZoomLevel(_ zoom: Double) throws {
    #if os(iOS)
    let device = try requireDevice()
    try device.lockForConfiguration()
    device.videoZoomFactor = min(max(CGFloat(zoom), device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
    device.unlockForConfiguration()
    #elseif os(macOS)
    throw RufletCameraError.unsupportedOnCurrentApplePlatform("set_zoom_level")
    #endif
  }

  public var minimumZoomLevel: Double {
    #if os(iOS)
    device.map { Double($0.minAvailableVideoZoomFactor) } ?? 1
    #elseif os(macOS)
    1
    #endif
  }

  public var maximumZoomLevel: Double {
    #if os(iOS)
    device.map { Double($0.maxAvailableVideoZoomFactor) } ?? 1
    #elseif os(macOS)
    1
    #endif
  }

  public var minimumExposureOffset: Double {
    #if os(iOS)
    device.map { Double($0.minExposureTargetBias) } ?? 0
    #elseif os(macOS)
    0
    #endif
  }

  public var maximumExposureOffset: Double {
    #if os(iOS)
    device.map { Double($0.maxExposureTargetBias) } ?? 0
    #elseif os(macOS)
    0
    #endif
  }

  public var exposureOffsetStepSize: Double { 1.0 / 3.0 }

  public func setExposureOffset(_ offset: Double) throws -> Double {
    #if os(iOS)
    let device = try requireDevice()
    let clamped = min(max(Float(offset), device.minExposureTargetBias), device.maxExposureTargetBias)
    try device.lockForConfiguration()
    device.setExposureTargetBias(clamped)
    device.unlockForConfiguration()
    return Double(clamped)
    #elseif os(macOS)
    throw RufletCameraError.unsupportedOnCurrentApplePlatform("set_exposure_offset")
    #endif
  }

  public func setExposurePoint(_ point: CGPoint?) throws {
    let device = try requireDevice()
    guard device.isExposurePointOfInterestSupported else { return }
    try device.lockForConfiguration()
    if let point { device.exposurePointOfInterest = point }
    device.exposureMode = .continuousAutoExposure
    device.unlockForConfiguration()
  }

  public func setExposureMode(_ mode: RufletCameraExposureMode) throws {
    let device = try requireDevice()
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    switch mode {
    case .auto:
      if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
      }
    case .locked:
      if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
    }
    state.exposureMode = mode
    emitState()
  }

  public func setFocusPoint(_ point: CGPoint?) throws {
    let device = try requireDevice()
    guard device.isFocusPointOfInterestSupported else { return }
    try device.lockForConfiguration()
    if let point { device.focusPointOfInterest = point }
    device.focusMode = .continuousAutoFocus
    device.unlockForConfiguration()
  }

  public func setFocusMode(_ mode: RufletCameraFocusMode) throws {
    let device = try requireDevice()
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    switch mode {
    case .auto:
      if device.isFocusModeSupported(.continuousAutoFocus) {
        device.focusMode = .continuousAutoFocus
      }
    case .locked:
      if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
    }
    state.focusMode = mode
    emitState()
  }

  public func setFlashMode(_ mode: RufletCameraFlashMode) throws {
    let device = try requireDevice()
    try device.lockForConfiguration()
    switch mode {
    case .torch: if device.hasTorch { try device.setTorchModeOn(level: 1) }
    case .off, .auto, .always: if device.hasTorch { device.torchMode = .off }
    }
    device.unlockForConfiguration()
    state.flashMode = mode
    emitState()
  }

  public func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    state.isTakingPicture = false
    emitState()
    if let error {
      pendingPhoto?.resume(throwing: error)
    } else if let data = photo.fileDataRepresentation() {
      pendingPhoto?.resume(returning: data)
    } else {
      pendingPhoto?.resume(throwing: RufletCameraError.couldNotEncodePhoto)
    }
    pendingPhoto = nil
  }

  nonisolated public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    Task { @MainActor [weak self] in
      guard let self, !processingImage else { return }
      processingImage = true
      defer { processingImage = false }
      guard let data = RufletCameraMapping.jpegData(from: sampleBuffer) else { return }
      guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
      let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
      onStreamImage?(RufletCameraImage(
        width: Int(dimensions.width),
        height: Int(dimensions.height),
        format: "bgra8888",
        encodedFormat: "jpeg",
        bytes: data))
    }
  }

  nonisolated public func fileOutput(
    _ output: AVCaptureFileOutput,
    didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection],
    error: Error?
  ) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      state.isRecordingVideo = false
      state.isRecordingPaused = false
      emitState()
      if let error {
        pendingMovie?.resume(throwing: error)
      } else {
        do { pendingMovie?.resume(returning: try Data(contentsOf: outputFileURL)) }
        catch { pendingMovie?.resume(throwing: error) }
      }
      pendingMovie = nil
      movieURL = nil
    }
  }

  private func requireDevice() throws -> AVCaptureDevice {
    guard let device else { throw RufletCameraError.notInitialized }
    return device
  }

  private func emitState() {
    onStateChange?(state)
  }

  private static func discoverySession() -> AVCaptureDevice.DiscoverySession {
    #if os(iOS)
    var types: [AVCaptureDevice.DeviceType] = [
      .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera,
      .builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera,
      .builtInTrueDepthCamera,
    ]
    if #available(iOS 17.0, *) { types.append(.external) }
    #elseif os(macOS)
    let types: [AVCaptureDevice.DeviceType]
    if #available(macOS 14.0, *) {
      types = [.builtInWideAngleCamera, .external]
    } else {
      types = [.builtInWideAngleCamera, .externalUnknown]
    }
    #endif
    return AVCaptureDevice.DiscoverySession(
      deviceTypes: types,
      mediaType: .video,
      position: .unspecified)
  }
}

public enum RufletCameraError: Error, Equatable, Sendable {
  case notInitialized
  case cameraNotFound(String)
  case alreadyRecording
  case notRecording
  case couldNotEncodePhoto
  case invalidDescription
  case unknownMethod(String)
  case unsupportedOnCurrentApplePlatform(String)
}
