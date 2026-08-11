import Foundation
import RufletEngine
import RufletProtocol

#if canImport(AVFoundation)
  import AVFoundation
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

/// `Audio` — playback of a single source, driven entirely by method calls.
@MainActor
public final class AudioService: RufletService {
  public static let wireType = "Audio"

  #if canImport(AVFoundation)
    private var player: AVPlayer?
    private var observer: Any?
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
  #endif
  /// Held rather than captured: the notification closure is `@Sendable`, and
  /// the context is not.
  private var context: RufletServiceContext?
  private var controlID: Int?
  private var control: ControlNode?
  /// Flet reports whole seconds and suppresses a repeat of the second it last
  /// reported, so the last reported value has to be remembered.
  private var reportedPositionMilliseconds: Int64?
  private var durationMilliseconds: Int64?
  /// A base64 source is decoded once and played from a temporary file, which
  /// is removed when the player is released.
  private var decodedSource: URL?

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(AVFoundation)
      switch call.name {
      case "play", "resume":
        ensurePlayer(node: node, context: context)
        if call.name == "play", let milliseconds = call.argument("position")?.doubleValue {
          player?.seek(to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600))
        }
        player?.play()
        emit(event: "state_change", .map(["state": .string("playing")]))
        completion(.success(.null))

      case "pause":
        player?.pause()
        emit(event: "state_change", .map(["state": .string("paused")]))
        completion(.success(.null))

      case "release", "stop":
        player?.pause()
        player?.seek(to: .zero)
        emit(event: "state_change", .map(["state": .string("stopped")]))
        if call.name == "release" { releasePlayer() }
        completion(.success(.null))

      case "seek":
        let milliseconds = call.argument("position")?.doubleValue ?? 0
        player?.seek(
          to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600)
        ) { [weak self] _ in
          Task { @MainActor in self?.emit(event: "seek_complete", .null) }
        }
        completion(.success(.null))

      case "get_duration":
        guard let seconds = player?.currentItem?.duration.seconds, seconds.isFinite else {
          return completion(.success(.null))
        }
        completion(.success(.int(Int64(seconds * 1000))))

      case "get_current_position":
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else {
          return completion(.success(.null))
        }
        completion(.success(.int(Int64(seconds * 1000))))

      case "set_volume":
        player?.volume = Float(call.argument("volume")?.doubleValue ?? 1)
        completion(.success(.null))

      case "set_playback_rate":
        player?.rate = Float(call.argument("playback_rate")?.doubleValue ?? 1)
        completion(.success(.null))

      default:
        completion(
          .failure(RufletServiceError.unsupportedMethod(type: "Audio", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("AVFoundation is unavailable")))
    #endif
  }

  #if canImport(AVFoundation)
    /// Flet resolves the source from `src` or, when the caller sent the bytes
    /// inline, from `src_base64`. A URL with a scheme streams; anything else is
    /// a device path.
    private func resolveSource(node: ControlNode) -> URL? {
      if let source = node.string("src"), !source.isEmpty {
        if let parsed = URL(string: source), parsed.scheme != nil { return parsed }
        return URL(fileURLWithPath: source)
      }
      guard let encoded = node.string("src_base64"),
        let data = Data(base64Encoded: encoded)
      else { return nil }
      // AVPlayer plays from a URL rather than from memory, so the decoded
      // bytes are staged in the temporary directory for the player's lifetime.
      let staged = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ruflet-audio-\(UUID().uuidString)")
      guard (try? data.write(to: staged)) != nil else { return nil }
      decodedSource = staged
      return staged
    }

    /// The source lives on the control's `src`, and Flet reports `state_change`
    /// when playback finishes, so both are wired here.
    private func ensurePlayer(node: ControlNode?, context: RufletServiceContext) {
      guard player == nil, let node else { return }
      guard let url = resolveSource(node: node) else { return }

      let player = AVPlayer(url: url)
      // Flet ignores a volume outside the unit range rather than clamping it.
      if let volume = node.double("volume"), (0...1).contains(volume) {
        player.volume = Float(volume)
      } else {
        player.volume = 1
      }
      self.player = player

      self.context = context
      controlID = node.id
      control = node
      reportedPositionMilliseconds = nil
      durationMilliseconds = nil
      itemStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) {
        [weak self] item, _ in
        Task { @MainActor in
          guard let self else { return }
          switch item.status {
          case .readyToPlay:
            // Flet fires `loaded` once the source has been set, then autoplays.
            self.emit(event: "loaded", .null)
            if item.duration.seconds.isFinite {
              let milliseconds = Int64(item.duration.seconds * 1000)
              self.durationMilliseconds = milliseconds
              self.emit(event: "duration_change", .map(["duration": .int(milliseconds)]))
            }
            self.startAutoplayIfRequested()
          case .failed:
            self.emit(
              event: "error",
              .string(item.error?.localizedDescription ?? "The audio could not be loaded"))
          default:
            break
          }
        }
      }
      timeObserver = player.addPeriodicTimeObserver(
        forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
      ) { [weak self] time in
        Task { @MainActor in
          guard time.seconds.isFinite else { return }
          self?.reportPosition(seconds: time.seconds)
        }
      }
      observer = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: player.currentItem,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.reportCompletion() }
      }
    }
  #endif

  /// What Flet reports for a periodic tick, or `nil` when the tick repeats the
  /// second already reported. Flet reports whole seconds, and lets the final
  /// tick through when the raw position has reached the duration exactly.
  public struct PositionReport: Equatable, Sendable {
    /// The whole-second position Flet puts on the event.
    public let milliseconds: Int64
    /// What the service remembers as last reported.
    public let retained: Int64
  }

  nonisolated public static func positionReport(
    rawMilliseconds: Int64,
    lastReported: Int64?,
    durationMilliseconds: Int64?
  ) -> PositionReport? {
    let rounded = Int64((Double(rawMilliseconds) / 1000).rounded()) * 1000
    // Flet starts from -1 so the first tick, including a zero, always reports.
    if rounded != (lastReported ?? -1) {
      return PositionReport(milliseconds: rounded, retained: rounded)
    }
    if let durationMilliseconds, rawMilliseconds == durationMilliseconds {
      return PositionReport(milliseconds: rounded, retained: durationMilliseconds)
    }
    return nil
  }

  private func reportPosition(seconds: Double) {
    let raw = Int64(seconds * 1000)
    guard
      let report = Self.positionReport(
        rawMilliseconds: raw,
        lastReported: reportedPositionMilliseconds,
        durationMilliseconds: durationMilliseconds)
    else { return }
    reportedPositionMilliseconds = report.retained
    emit(event: "position_change", .map(["position": .int(report.milliseconds)]))
  }

  /// Flet resumes as soon as a new source has loaded when `autoplay` is set.
  private func startAutoplayIfRequested() {
    guard let control, control.bool("autoplay") == true else { return }
    #if canImport(AVFoundation)
      player?.play()
    #endif
    emit(event: "state_change", .map(["state": .string("playing")]))
  }

  /// audioplayers' release modes: `loop` restarts, `stop` rewinds and holds the
  /// source, and `release` — its default when the control leaves the property
  /// unset — frees the player once playback completes.
  public enum ReleaseMode: String, Sendable {
    case loop
    case stop
    case release
  }

  nonisolated public static func releaseMode(_ raw: String?) -> ReleaseMode {
    guard let raw, let parsed = ReleaseMode(rawValue: raw.lowercased()) else { return .release }
    return parsed
  }

  private func reportCompletion() {
    emit(event: "state_change", .map(["state": .string("completed")]))
    guard let control else { return }
    reportedPositionMilliseconds = nil
    switch Self.releaseMode(control.string("release_mode")) {
    case .loop:
      #if canImport(AVFoundation)
        player?.seek(to: .zero)
        player?.play()
      #endif
    case .stop:
      #if canImport(AVFoundation)
        player?.seek(to: .zero)
      #endif
    case .release:
      #if canImport(AVFoundation)
        releasePlayer()
      #endif
    }
  }

  private func emit(event: String, _ data: RufletValue) {
    guard let context, let controlID, let control, control.handlesEvent(event) else { return }
    context.emitEvent(controlID, event, data)
  }

  #if canImport(AVFoundation)
    private func releasePlayer() {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      observer = nil
      if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
      timeObserver = nil
      itemStatusObserver?.invalidate()
      itemStatusObserver = nil
      player = nil
      if let decodedSource { try? FileManager.default.removeItem(at: decodedSource) }
      decodedSource = nil
    }
  #endif

  deinit {
    #if canImport(AVFoundation)
      if let observer { NotificationCenter.default.removeObserver(observer) }
      if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
      itemStatusObserver?.invalidate()
    #endif
  }
}

/// `AudioRecorder` — capture to a file.
@MainActor
public final class AudioRecorderService: RufletService {
  public static let wireType = "AudioRecorder"

  #if canImport(AVFoundation)
    private var recorder: AVAudioRecorder?
  #endif
  private var outputPath: String?
  private var paused = false
  private var eventContext: RufletServiceContext?
  private var eventNode: ControlNode?

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    eventContext = context
    eventNode = node
    #if canImport(AVFoundation)
      switch call.name {
      case "start_recording":
        let path =
          call.argument("output_path")?.stringValue
          ?? (NSTemporaryDirectory() as NSString).appendingPathComponent(
            "ruflet-recording-\(UUID().uuidString).m4a")
        do {
          try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true)
          #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
          #endif
          let encoder = call.argument("configuration")?["encoder"]?.stringValue?.lowercased()
          let format = encoder == "wav" ? kAudioFormatLinearPCM : kAudioFormatMPEG4AAC
          var settings: [String: Any] = [
            AVFormatIDKey: Int(format),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1
          ]
          if format == kAudioFormatLinearPCM {
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = false
          }
          let recorder = try AVAudioRecorder(
            url: URL(fileURLWithPath: path),
            settings: settings)
          guard recorder.prepareToRecord(), recorder.record() else {
            throw RufletServiceError.failed("The audio recorder could not start")
          }
          self.recorder = recorder
          outputPath = path
          paused = false
          emitState("recording")
          completion(.success(.bool(true)))
        } catch {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        }

      case "stop_recording":
        recorder?.stop()
        recorder = nil
        paused = false
        emitState("stopped")
        completion(.success(outputPath.map { RufletValue.string($0) } ?? .null))

      case "cancel_recording":
        recorder?.stop()
        recorder = nil
        paused = false
        if let outputPath { try? FileManager.default.removeItem(atPath: outputPath) }
        outputPath = nil
        emitState("stopped")
        completion(.success(.null))

      case "pause_recording":
        recorder?.pause()
        paused = recorder != nil
        emitState("paused")
        completion(.success(.null))

      case "resume_recording":
        recorder?.record()
        paused = false
        emitState("recording")
        completion(.success(.null))

      case "is_recording":
        completion(.success(.bool(recorder?.isRecording ?? false)))

      case "is_paused":
        completion(.success(.bool(paused)))

      case "get_input_devices":
        #if os(iOS)
          let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
          completion(.success(.array(inputs.map { input in
            .map([
              "id": .string(input.uid),
              "label": .string(input.portName)
            ])
          })))
        #else
          let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified
          ).devices
          completion(.success(.array(devices.map { device in
            .map(["id": .string(device.uniqueID), "label": .string(device.localizedName)])
          })))
        #endif

      case "is_supported_encoder":
        completion(.success(.bool(true)))

      case "has_permission":
        #if os(iOS)
          switch AVAudioSession.sharedInstance().recordPermission {
          case .granted:
            completion(.success(.bool(true)))
          case .denied:
            completion(.success(.bool(false)))
          case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
              Task { @MainActor in completion(.success(.bool(granted))) }
            }
          @unknown default:
            completion(.success(.bool(false)))
          }
        #else
          let status = AVCaptureDevice.authorizationStatus(for: .audio)
          if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
              Task { @MainActor in completion(.success(.bool(granted))) }
            }
          } else {
            completion(.success(.bool(status == .authorized)))
          }
        #endif

      default:
        completion(
          .failure(
            RufletServiceError.unsupportedMethod(type: "AudioRecorder", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("AVFoundation is unavailable")))
    #endif
  }

  private func emitState(_ state: String) {
    guard let eventContext, let eventNode, eventNode.handlesEvent("state_change") else { return }
    eventContext.emitEvent(eventNode.id, "state_change", .map(["state": .string(state)]))
  }
}


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


/// `Flashlight` — the camera torch.
@MainActor
public final class FlashlightService: RufletService {
  public static let wireType = "Flashlight"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(AVFoundation) && os(iOS)
      guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
        return call.name == "is_available"
          ? completion(.success(.bool(false)))
          : completion(.failure(RufletServiceError.unavailable("This device has no torch")))
      }

      switch call.name {
      case "is_available":
        completion(.success(.bool(true)))
      case "on", "off":
        do {
          try device.lockForConfiguration()
          device.torchMode = call.name == "on" ? .on : .off
          device.unlockForConfiguration()
          completion(.success(.null))
        } catch {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        }
      default:
        completion(
          .failure(RufletServiceError.unsupportedMethod(type: "Flashlight", method: call.name)))
      }
    #else
      call.name == "is_available"
        ? completion(.success(.bool(false)))
        : completion(.failure(RufletServiceError.unavailable("No torch on this platform")))
    #endif
  }
}
