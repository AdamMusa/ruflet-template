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
  #endif
  /// Held rather than captured: the notification closure is `@Sendable`, and
  /// the context is not.
  private var context: RufletServiceContext?
  private var controlID: Int?

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
        player?.play()
        completion(.success(.null))

      case "pause":
        player?.pause()
        completion(.success(.null))

      case "release", "stop":
        player?.pause()
        player?.seek(to: .zero)
        if call.name == "release" { player = nil }
        completion(.success(.null))

      case "seek":
        let milliseconds = call.argument("position")?.doubleValue ?? 0
        player?.seek(to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600))
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
    /// The source lives on the control's `src`, and Flet reports `state_change`
    /// when playback finishes, so both are wired here.
    private func ensurePlayer(node: ControlNode?, context: RufletServiceContext) {
      guard player == nil, let node else { return }
      let url: URL?
      if let source = node.string("src"), let parsed = URL(string: source), parsed.scheme != nil {
        url = parsed
      } else if let source = node.string("src") {
        url = URL(fileURLWithPath: source)
      } else {
        url = nil
      }
      guard let url else { return }

      let player = AVPlayer(url: url)
      player.volume = Float(node.double("volume") ?? 1)
      self.player = player

      self.context = context
      controlID = node.id
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
    guard let context, let controlID else { return }
    context.emitEvent(controlID, "state_change", .string("completed"))
  }

  deinit {
    #if canImport(AVFoundation)
      if let observer { NotificationCenter.default.removeObserver(observer) }
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

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
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
          completion(.success(.bool(true)))
        } catch {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        }

      case "stop_recording":
        recorder?.stop()
        recorder = nil
        completion(.success(outputPath.map { RufletValue.string($0) } ?? .null))

      case "pause_recording":
        recorder?.pause()
        completion(.success(.null))

      case "resume_recording":
        recorder?.record()
        completion(.success(.null))

      case "is_recording":
        completion(.success(.bool(recorder?.isRecording ?? false)))

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
}


/// `Camera` — capture, exposed as method calls the way Flet's camera does.
@MainActor
public final class CameraService: RufletService {
  public static let wireType = "Camera"

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

      default:
        completion(
          .failure(RufletServiceError.unsupportedMethod(type: "Camera", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("No camera on this platform")))
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
