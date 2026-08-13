@preconcurrency import AVFoundation
import Foundation
import RufletEngine
import RufletProtocol

public enum RufletAudioRecorderState: String, Sendable {
  case recording
  case paused
  case stopped
}

@MainActor
public final class RufletAudioRecorderController: NSObject, @preconcurrency AVAudioRecorderDelegate {
  public var onStateChange: (@MainActor @Sendable (RufletAudioRecorderState) -> Void)?

  private var recorder: AVAudioRecorder?
  private var outputURL: URL?
  private var state: RufletAudioRecorderState = .stopped

  public func start(configuration: RufletRecordConfiguration, outputURL: URL) async throws -> Bool {
    guard configuration.encoder.appleFormatID != nil else {
      throw RufletAudioRecorderError.unsupportedEncoder(configuration.encoder)
    }
    guard await hasPermission() else { return false }

    try configureAudioSession(configuration.ios)
    let recorder = try AVAudioRecorder(
      url: outputURL,
      settings: configuration.recorderSettings)
    recorder.delegate = self
    recorder.isMeteringEnabled = true
    guard recorder.prepareToRecord(), recorder.record() else {
      throw RufletAudioRecorderError.couldNotStart
    }

    self.recorder?.stop()
    self.recorder = recorder
    self.outputURL = outputURL
    transition(to: .recording)
    return true
  }

  public func stop() -> URL? {
    guard let recorder else { return nil }
    recorder.stop()
    self.recorder = nil
    transition(to: .stopped)
    let completedURL = outputURL
    outputURL = nil
    return completedURL
  }

  public func cancel() throws {
    let cancelledURL = outputURL
    recorder?.stop()
    recorder?.deleteRecording()
    recorder = nil
    outputURL = nil
    transition(to: .stopped)
    if let cancelledURL, FileManager.default.fileExists(atPath: cancelledURL.path) {
      try FileManager.default.removeItem(at: cancelledURL)
    }
  }

  public func pause() throws {
    guard let recorder, recorder.isRecording else {
      throw RufletAudioRecorderError.notRecording
    }
    recorder.pause()
    transition(to: .paused)
  }

  public func resume() throws {
    guard let recorder else { throw RufletAudioRecorderError.notRecording }
    guard recorder.record() else { throw RufletAudioRecorderError.couldNotResume }
    transition(to: .recording)
  }

  public var isPaused: Bool { state == .paused }
  public var isRecording: Bool { state == .recording && recorder?.isRecording == true }

  public func isSupported(_ encoder: RufletAudioEncoder) -> Bool {
    encoder.appleFormatID != nil
  }

  public func hasPermission() async -> Bool {
    #if os(iOS)
    if #available(iOS 17.0, *) {
      return await AVAudioApplication.requestRecordPermission()
    }
    return await withCheckedContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission {
        continuation.resume(returning: $0)
      }
    }
    #elseif os(macOS)
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return true
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: .audio)
    case .denied, .restricted:
      return false
    @unknown default:
      return false
    }
    #endif
  }

  public func inputDevices() -> [RufletAudioInputDevice] {
    #if os(iOS)
    return (AVAudioSession.sharedInstance().availableInputs ?? []).map {
      RufletAudioInputDevice(id: $0.uid, label: $0.portName)
    }
    #elseif os(macOS)
    let session = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInMicrophone],
      mediaType: .audio,
      position: .unspecified)
    return session.devices.map {
      RufletAudioInputDevice(id: $0.uniqueID, label: $0.localizedName)
    }
    #endif
  }

  public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    self.recorder = nil
    transition(to: .stopped)
  }

  public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    self.recorder = nil
    transition(to: .stopped)
  }

  private func transition(to nextState: RufletAudioRecorderState) {
    guard state != nextState else { return }
    state = nextState
    onStateChange?(nextState)
  }

  private func configureAudioSession(_ configuration: RufletIOSRecordConfiguration) throws {
    #if os(iOS)
    guard configuration.manageAudioSession else { return }
    let options = configuration.categoryOptions.reduce(into: AVAudioSession.CategoryOptions()) {
      $0.insert($1.avOption)
    }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .default, options: options)
    try session.setActive(true)
    #endif
  }
}

public enum RufletAudioRecorderError: Error, Equatable, Sendable {
  case unsupportedEncoder(RufletAudioEncoder)
  case couldNotStart
  case couldNotResume
  case notRecording
  case missingOutputPath
  case invalidConfiguration
  case unknownMethod(String)
}

@MainActor
public final class AudioRecorderService: RufletService {
  private let recorder = RufletAudioRecorderController()
  private var invokeToken: UUID?

  public required init(control: RufletControl) {
    super.init(control: control)
  }

  public override func initialize() {
    recorder.onStateChange = { [weak self] state in
      self?.control.triggerEvent("state_change", data: .string(state.rawValue))
    }
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try await self.invoke(name, arguments: arguments)
    }
  }

  public override func dispose() {
    if recorder.isRecording || recorder.isPaused { _ = recorder.stop() }
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    switch name {
    case "start_recording":
      guard let configuration = RufletRecordConfiguration.parse(arguments["configuration"]) else {
        throw RufletAudioRecorderError.invalidConfiguration
      }
      guard let path = arguments["output_path"]?.text, !path.isEmpty else {
        return .bool(false)
      }
      let outputURL = URL(string: path).flatMap { $0.isFileURL ? $0 : nil }
        ?? URL(fileURLWithPath: path)
      return .bool(try await recorder.start(configuration: configuration, outputURL: outputURL))
    case "stop_recording":
      return recorder.stop().map { .string($0.path) } ?? .null
    case "cancel_recording":
      try recorder.cancel()
      return .null
    case "resume_recording":
      try recorder.resume()
      return .null
    case "pause_recording":
      try recorder.pause()
      return .null
    case "is_supported_encoder":
      guard let encoder = RufletAudioEncoder.parse(arguments["encoder"]?.text) else {
        return .bool(false)
      }
      return .bool(recorder.isSupported(encoder))
    case "is_paused":
      return .bool(recorder.isPaused)
    case "is_recording":
      return .bool(recorder.isRecording)
    case "has_permission":
      return .bool(await recorder.hasPermission())
    case "get_input_devices":
      return .map(Dictionary(uniqueKeysWithValues: recorder.inputDevices().map {
        ($0.id, .string($0.label))
      }))
    default:
      throw RufletAudioRecorderError.unknownMethod(name)
    }
  }
}
