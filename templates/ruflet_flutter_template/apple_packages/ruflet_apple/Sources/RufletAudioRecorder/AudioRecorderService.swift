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
        let configurationValue = Self.recordingConfigurationValue(for: call, node: node)
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
            throw RufletServiceError.failed("Failed to start recording: \(encoder) not supported")
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
          // record_ios reports a successful start once AVAudioRecorder was
          // created; it intentionally does not reinterpret these advisory
          // booleans as a different Flet result shape.
          _ = recorder.prepareToRecord()
          _ = recorder.record()
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
        outputPath = nil
        completion(.success(path.map { RufletValue.string($0) } ?? .null))
        // record completes stop() with the path before publishing its stopped
        // state on the recorder state stream.
        emitState("stopped")

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
          _ = recorder.record()
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
          do {
            let session = AVAudioSession.sharedInstance()
            #if compiler(>=6.2)
              let bluetooth: AVAudioSession.CategoryOptions = .allowBluetoothHFP
            #else
              let bluetooth: AVAudioSession.CategoryOptions = .allowBluetooth
            #endif
            try session.setCategory(
              .playAndRecord, options: [.defaultToSpeaker, bluetooth])
            let inputs = session.availableInputs ?? []
            completion(.success(.map(Dictionary(uniqueKeysWithValues: inputs.map {
              ($0.uid, RufletValue.string($0.portName))
            }))))
          } catch {
            completion(.failure(RufletServiceError.failed(
              "Failed to list inputs: \(error.localizedDescription)")))
          }
        #else
          let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio, position: .unspecified
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
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
          AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in completion(.success(.bool(granted))) }
          }
        } else {
          completion(.success(.bool(status == .authorized)))
        }

      default:
        completion(
          .failure(
            RufletServiceError.unsupportedMethod(type: "AudioRecorder", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("AVFoundation is unavailable")))
    #endif
  }

  /// Flet's recorder configuration is an imperative method argument. The
  /// service control has no update-driven `configuration` property fallback.
  static func recordingConfigurationValue(
    for call: RufletMethodCall, node _: ControlNode?
  ) -> RufletValue? {
    return call.argument("configuration")
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
    static func formatID(for encoder: String) -> AudioFormatID? {
      switch encoder.replacingOccurrences(of: "-", with: "_").lowercased() {
      case "wav", "pcm16bits": return kAudioFormatLinearPCM
      case "aaclc", "aac_lc": return kAudioFormatMPEG4AAC
      case "aache", "aac_he": return kAudioFormatMPEG4AAC_HE_V2
      case "aaceld", "aac_eld":
        #if os(macOS)
          return kAudioFormatMPEG4AAC_ELD
        #else
          return kAudioFormatMPEG4AAC_ELD_V2
        #endif
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
    static func isSupportedEncoder(_ encoder: String) -> Bool {
      switch encoder.replacingOccurrences(of: "-", with: "_").lowercased() {
      case "wav", "pcm16bits", "aaclc", "aac_lc", "aaceld", "aac_eld", "flac":
        return true
      case "opus":
        #if os(iOS)
          return true
        #else
          return false
        #endif
      default:
        return false
      }
    }

    static func parsedEncoder(_ value: String) -> String? {
      switch value.lowercased() {
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
