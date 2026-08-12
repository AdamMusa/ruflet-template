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

/// `Audio` — playback of a single source, driven entirely by method calls.
struct AudioPlaybackOptions: Equatable {
  let autoplay: Bool
  let volume: Double
  let balance: Double
  let playbackRate: Double
  let releaseMode: String?

  init(_ node: ControlNode) {
    autoplay = node.bool("autoplay") ?? false
    let requestedVolume = node.double("volume") ?? 1
    volume = (0...1).contains(requestedVolume) ? requestedVolume : 1
    let requestedBalance = node.double("balance") ?? 0
    balance = (-1...1).contains(requestedBalance) ? requestedBalance : 0
    playbackRate = node.double("playback_rate") ?? 1
    releaseMode = node.string("release_mode")?.lowercased()
  }

  /// audioplayers_darwin 6.4.0 accepts `setBalance` but its Apple backend
  /// implements it as a no-op. AVPlayer likewise has no stereo-pan property.
  static let avFoundationUnsupportedProperties: Set<String> = ["balance"]
}

@MainActor
public final class AudioService: RufletStreamingService {
  public static let wireType = "Audio"

  #if canImport(AVFoundation)
    private var player: AVPlayer?
    private var observer: Any?
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var temporarySourceURL: URL?
  #endif
  /// Held rather than captured: the notification closure is `@Sendable`, and
  /// the context is not.
  private var context: RufletServiceContext?
  private var controlID: Int?
  private var control: ControlNode?
  private var sourceIdentity: String?
  private var playbackRate: Float = 1

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    ensurePlayer(node: node, context: context)
  }

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
        guard player != nil else {
          completion(.failure(RufletServiceError.failed("Audio must have \"src\" specified.")))
          return
        }
        if call.name == "play", let milliseconds = call.argument("position")?.doubleValue {
          guard let player else {
            completion(.success(.null))
            return
          }
          player.seek(
            to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600)
          ) { [weak self] _ in
            Task { @MainActor in
              guard let self else { return }
              player.playImmediately(atRate: self.playbackRate)
              self.emit("state_change", .map(["state": .string("playing")]))
              completion(.success(.null))
            }
          }
          return
        }
        player?.playImmediately(atRate: playbackRate)
        emit("state_change", .map(["state": .string("playing")]))
        completion(.success(.null))

      case "pause":
        player?.pause()
        emit("state_change", .map(["state": .string("paused")]))
        completion(.success(.null))

      case "release":
        player?.pause()
        player?.seek(to: .zero)
        emit("state_change", .map(["state": .string("disposed")]))
        releasePlayer()
        completion(.success(.null))

      case "seek":
        guard let milliseconds = call.argument("position")?.doubleValue else {
          completion(.success(.null))
          return
        }
        guard let player else {
          completion(.success(.null))
          return
        }
        player.seek(
          to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600)
        ) { [weak self] _ in
          Task { @MainActor in
            self?.emit("seek_complete", .null)
            completion(.success(.null))
          }
        }

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

      default:
        completion(
          .failure(RufletServiceError.unsupportedMethod(type: "Audio", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("AVFoundation is unavailable")))
    #endif
  }

  #if canImport(AVFoundation)
    /// The source lives on the control's `src`, and Flet reports `state_change`
    /// when playback finishes, so both are wired here.
    private func ensurePlayer(node: ControlNode?, context: RufletServiceContext) {
      guard let node else { return }
      let url: URL?
      let identity: String?
      if let source = node.string("src"), let parsed = URL(string: source), parsed.scheme != nil {
        url = parsed
        identity = "url:\(source)"
      } else if let source = node.string("src") {
        url = URL(fileURLWithPath: source)
        identity = "file:\(source)"
      } else if let encoded = node.string("src_base64"), let data = Data(base64Encoded: encoded) {
        // Flet lets a sound travel inline; AVPlayer needs a file, so the bytes
        // are spilled to a temporary one named for their own digest.
        let file = FileManager.default.temporaryDirectory
          .appendingPathComponent("ruflet-audio-\(encoded.hashValue).m4a")
        try? data.write(to: file)
        url = file
        identity = "base64:\(encoded.hashValue)"
      } else {
        url = nil
        identity = nil
      }
      guard let url, let identity else { return }

      self.context = context
      controlID = node.id
      control = node

      let sourceChanged = player == nil || identity != sourceIdentity
      if sourceChanged {
        releasePlayer()
        if identity.hasPrefix("base64:") { temporarySourceURL = url }
        sourceIdentity = identity
        installPlayer(url: url, node: node)
      }

      guard let player else { return }
      let options = AudioPlaybackOptions(node)
      player.volume = Float(options.volume)
      playbackRate = Float(options.playbackRate)
      if player.rate != 0 { player.rate = playbackRate }
      // Keep parity with audioplayers_darwin 6.4.0: Flet forwards balance,
      // while the pinned Apple backend explicitly treats setBalance as a
      // no-op. AVPlayer has no channel-pan API, so applying whole-track volume
      // here would be observably incorrect.

      // Flet applies autoplay when a source is mounted/replaced. A later
      // property update must not unexpectedly resume audio the user paused.
      if sourceChanged, node.bool("autoplay") == true {
        player.playImmediately(atRate: playbackRate)
        emit("state_change", .map(["state": .string("playing")]))
      }
    }

    private func installPlayer(url: URL, node: ControlNode) {
      let player = AVPlayer(url: url)
      self.player = player

      itemStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) {
        [weak self] item, _ in
        Task { @MainActor in
          guard let self else { return }
          switch item.status {
          case .readyToPlay:
            self.emit("loaded", .null)
            if item.duration.seconds.isFinite {
              self.emit(
                "duration_change",
                .map(["duration": .int(Int64(item.duration.seconds * 1000))]))
            }
          case .failed:
            self.emit(
              "error",
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
          self?.emit(
            "position_change",
            .map(["position": .int(Int64(time.seconds.rounded() * 1000))]))
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

  private func reportCompletion() {
    emit("state_change", .map(["state": .string("completed")]))
    switch control?.string("release_mode")?.lowercased() ?? "release" {
    case "loop":
      player?.seek(to: .zero)
      player?.playImmediately(atRate: playbackRate)
    case "stop":
      player?.pause()
      player?.seek(to: .zero)
    default:
      // audioplayers defaults to ReleaseMode.release.
      releasePlayer()
    }
  }

  private func emit(_ name: String, _ data: RufletValue) {
    guard let context, let controlID, let control, control.handlesEvent(name) else { return }
    context.emitEvent(controlID, name, data)
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
      if let temporarySourceURL { try? FileManager.default.removeItem(at: temporarySourceURL) }
      temporarySourceURL = nil
      sourceIdentity = nil
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
  private var recorderState = "stopped"
  private var eventContext: RufletServiceContext?
  private var eventNode: ControlNode?
  private var streamTimer: DispatchSourceTimer?
  private var streamedByteCount: UInt64 = 0

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
        let configurationValue = call.argument("configuration") ?? node?.props["configuration"]
        guard let configuration = AudioRecorderConfiguration(configurationValue) else {
          completion(.success(.bool(false)))
          return
        }
        // Validate the device-only path before asking for microphone access.
        // This preserves Flet's false result while avoiding a permission prompt
        // for a request that could never start recording.
        guard let path = call.argument("output_path")?.stringValue, !path.isEmpty else {
          completion(.success(.bool(false)))
          return
        }
        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        if permission == .denied || permission == .restricted {
          completion(.success(.bool(false)))
          return
        }
        if permission == .notDetermined {
          AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
              guard let self else { return }
              if granted {
                self.invoke(call, node: node, context: context, completion: completion)
              } else {
                completion(.success(.bool(false)))
              }
            }
          }
          return
        }
        // `record` requires a writable device path on native targets. Flet
        // deliberately returns false when it is omitted rather than silently
        // inventing a temporary file (web is the only target where it may be
        // empty).
        do {
          try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true)
          let encoder = configuration.encoder.lowercased()
          guard Self.isSupportedEncoder(encoder), let format = Self.formatID(for: encoder) else {
            completion(.success(.bool(false)))
            return
          }
          if recorder != nil {
            recorder?.stop()
            recorder = nil
            paused = false
            emitState("stopped")
          }
          let requestedSampleRate = Double(configuration.sampleRate)
          let sampleRate = Self.sampleRate(for: encoder, requested: requestedSampleRate)
          var settings: [String: Any] = [
            AVFormatIDKey: Int(format),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: configuration.channels,
            AVEncoderBitRateKey: configuration.bitRate,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
          ]
          if format == kAudioFormatLinearPCM {
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = false
          }
          let recorder = try AVAudioRecorder(
            url: URL(fileURLWithPath: path),
            settings: settings)
          #if os(iOS)
            try Self.configureAudioSession(configuration)
            if let requestedID = configuration.device?.id,
              let input = AVAudioSession.sharedInstance().availableInputs?.first(where: {
                $0.uid == requestedID
              })
            {
              try AVAudioSession.sharedInstance().setPreferredInput(input)
            }
          #endif
          guard recorder.prepareToRecord(), recorder.record() else {
            throw RufletServiceError.failed("The audio recorder could not start")
          }
          self.recorder = recorder
          outputPath = path
          paused = false
          streamedByteCount = 0
          startStreamIfHandled()
          emitState("recording")
          completion(.success(.bool(true)))
        } catch {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        }

      case "stop_recording":
        let path = recorder == nil ? nil : outputPath
        recorder?.stop()
        recorder = nil
        stopStream(flush: true)
        paused = false
        emitState("stopped")
        outputPath = nil
        completion(.success(path.map { RufletValue.string($0) } ?? .null))

      case "cancel_recording":
        recorder?.stop()
        recorder = nil
        stopStream(flush: false)
        paused = false
        if let outputPath { try? FileManager.default.removeItem(atPath: outputPath) }
        outputPath = nil
        emitState("stopped")
        completion(.success(.null))

      case "pause_recording":
        if let recorder, recorder.isRecording, !paused {
          recorder.pause()
          paused = true
          emitState("paused")
        }
        completion(.success(.null))

      case "resume_recording":
        if let recorder, paused {
          recorder.record()
          paused = false
          emitState("recording")
        }
        completion(.success(.null))

      case "is_recording":
        // record's paused state is still an active recording.
        completion(.success(.bool(recorder != nil)))

      case "is_paused":
        completion(.success(.bool(paused)))

      case "get_input_devices":
        #if os(iOS)
          let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
          completion(.success(.map(Dictionary(uniqueKeysWithValues: inputs.map {
            ($0.uid, RufletValue.string($0.portName))
          }))))
        #else
          let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified
          ).devices
          completion(.success(.map(Dictionary(uniqueKeysWithValues: devices.map {
            ($0.uniqueID, RufletValue.string($0.localizedName))
          }))))
        #endif

      case "is_supported_encoder":
        guard let raw = call.argument("encoder")?.stringValue,
          let encoder = Self.parsedEncoder(raw)
        else {
          completion(.success(.null))
          return
        }
        completion(.success(.bool(Self.isSupportedEncoder(encoder))) )

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
    guard recorderState != state else { return }
    recorderState = state
    guard let eventContext, let eventNode, eventNode.handlesEvent("state_change") else { return }
    eventContext.emitEvent(eventNode.id, "state_change", .string(state))
  }

  /// Ruflet's native `on_stream` extension emits the bytes appended to the
  /// configured recording file. The wire carries them as MessagePack binary,
  /// matching the typed byte buffers produced by record's Darwin stream.
  private func startStreamIfHandled() {
    stopStream(flush: false)
    guard eventNode?.handlesEvent("stream") == true else { return }
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
    timer.setEventHandler { [weak self] in self?.emitPendingStream() }
    streamTimer = timer
    timer.resume()
  }

  private func stopStream(flush: Bool) {
    streamTimer?.cancel()
    streamTimer = nil
    if flush { emitPendingStream() }
    streamedByteCount = 0
  }

  private func emitPendingStream() {
    guard let outputPath, let eventContext, let eventNode,
      eventNode.handlesEvent("stream"),
      let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: outputPath))
    else { return }
    defer { try? handle.close() }
    do {
      try handle.seek(toOffset: streamedByteCount)
      guard let data = try handle.readToEnd(), !data.isEmpty else { return }
      streamedByteCount += UInt64(data.count)
      eventContext.emitEvent(eventNode.id, "stream", AudioRecorderStreamEvent.wireValue(data))
    } catch {
      // A recording may not have flushed its first packet yet; the next timer
      // tick retries from the same offset.
    }
  }

  #if canImport(AVFoundation)
    private static func formatID(for encoder: String) -> AudioFormatID? {
      switch encoder.replacingOccurrences(of: "-", with: "_").lowercased() {
      case "wav", "pcm16bits": return kAudioFormatLinearPCM
      case "aaclc", "aac_lc": return kAudioFormatMPEG4AAC
      case "aache", "aac_he": return kAudioFormatMPEG4AAC_HE_V2
      case "aaceld", "aac_eld": return kAudioFormatMPEG4AAC_ELD_V2
      case "amrnb", "amr_nb": return kAudioFormatAMR
      case "amrwb", "amr_wb": return kAudioFormatAMR_WB
      case "opus": return kAudioFormatOpus
      case "flac": return kAudioFormatFLAC
      case "alac": return kAudioFormatAppleLossless
      default: return nil
      }
    }

    /// Mirrors record_ios' advertised encoder surface. Some Core Audio format
    /// identifiers exist on Apple platforms but the pinned plug-in deliberately
    /// reports them as unsupported because its recording pipeline cannot
    /// guarantee conversion for those formats.
    private static func isSupportedEncoder(_ encoder: String) -> Bool {
      switch encoder.replacingOccurrences(of: "-", with: "_").lowercased() {
      case "wav", "pcm16bits", "aaclc", "aac_lc", "aaceld", "aac_eld", "opus", "flac":
        return true
      default:
        return false
      }
    }

    private static func parsedEncoder(_ value: String) -> String? {
      switch value.replacingOccurrences(of: "_", with: "").lowercased() {
      case "aaclc": return "aacLc"
      case "aaceld": return "aacEld"
      case "aache": return "aacHe"
      case "amrnb": return "amrNb"
      case "amrwb": return "amrWb"
      case "opus": return "opus"
      case "flac": return "flac"
      case "pcm16bits": return "pcm16bits"
      case "wav": return "wav"
      default: return nil
      }
    }

    private static func sampleRate(for encoder: String, requested: Double) -> Double {
      guard encoder.replacingOccurrences(of: "-", with: "_").lowercased() == "opus" else {
        return requested
      }
      return [8_000.0, 12_000, 16_000, 24_000, 48_000]
        .min(by: { abs($0 - requested) < abs($1 - requested) }) ?? 48_000
    }

    #if os(iOS)
      private static func configureAudioSession(_ configuration: AudioRecorderConfiguration) throws {
        let session = AVAudioSession.sharedInstance()
        let options = audioSessionOptions(configuration.ios.options)

        try session.setPreferredSampleRate(
          min(Double(configuration.sampleRate), 48_000))
        if configuration.ios.manageAudioSession {
          try session.setCategory(.playAndRecord, mode: .default, options: options)
          try session.setActive(true, options: .notifyOthersOnDeactivation)
        }
        let channels = min(
          configuration.channels,
          session.maximumInputNumberOfChannels)
        if channels > 0 { try session.setPreferredInputNumberOfChannels(channels) }
      }

      private static func audioSessionOptions(_ names: [String])
        -> AVAudioSession.CategoryOptions
      {
        names.reduce(into: AVAudioSession.CategoryOptions()) { result, raw in
          switch raw.replacingOccurrences(of: "_", with: "").lowercased() {
          case "mixwithothers": result.insert(.mixWithOthers)
          case "duckothers": result.insert(.duckOthers)
          case "allowbluetooth":
            #if compiler(>=6.2)
              result.insert(.allowBluetoothHFP)
            #else
              result.insert(.allowBluetooth)
            #endif
          case "defaulttospeaker": result.insert(.defaultToSpeaker)
          case "interruptspokenaudioandmixwithothers":
            result.insert(.interruptSpokenAudioAndMixWithOthers)
          case "allowbluetootha2dp": result.insert(.allowBluetoothA2DP)
          case "allowairplay": result.insert(.allowAirPlay)
          case "overridemutedmicrophoneinterruption":
            if #available(iOS 14.5, *) { result.insert(.overrideMutedMicrophoneInterruption) }
          default: break
          }
        }
      }
    #endif
  #endif

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
