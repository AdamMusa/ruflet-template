import Foundation
import RufletProtocol

/// Source-faithful translation of the pinned Flet `parseRecordConfig` helpers.
///
/// Keep these defaults here rather than in a screen or host application: they
/// are part of the AudioRecorder wire contract supplied by Flet's Dart client.
public struct AudioRecorderConfiguration: Equatable, Sendable {
  public struct InputDevice: Equatable, Sendable {
    public let id: String
    public let label: String
  }

  public struct Android: Equatable, Sendable {
    public let audioSource: String
    public let manageBluetooth: Bool
    public let muteAudio: Bool
    public let useLegacy: Bool
  }

  public struct IOS: Equatable, Sendable {
    public let manageAudioSession: Bool
    public let options: [String]
  }

  public let autoGain: Bool
  public let bitRate: Int
  public let encoder: String
  public let echoCancel: Bool
  public let noiseSuppress: Bool
  public let channels: Int
  public let device: InputDevice?
  public let sampleRate: Int
  public let android: Android
  public let ios: IOS

  /// Flet returns `null` from `parseRecordConfig` for a missing value. Ruflet's
  /// Ruby service normally supplies its `{}` control default, so the empty map
  /// produces the concrete Flet defaults below.
  public init?(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return nil }
    autoGain = map["auto_gain"]?.boolValue ?? false
    bitRate = map["bit_rate"]?.intValue ?? 128_000
    encoder = Self.encoder(map["encoder"]?.stringValue)
    echoCancel = map["cancel_echo"]?.boolValue ?? false
    noiseSuppress = map["suppress_noise"]?.boolValue ?? false
    channels = map["channels"]?.intValue ?? 2
    sampleRate = map["sample_rate"]?.intValue ?? 44_100

    if let deviceMap = map["device"]?.mapValue,
      let id = deviceMap["id"]?.stringValue,
      let label = deviceMap["label"]?.stringValue
    {
      device = InputDevice(id: id, label: label)
    } else {
      device = nil
    }

    if let androidMap = map["android_configuration"]?.mapValue {
      android = Android(
        audioSource: Self.androidAudioSource(androidMap["audio_source"]?.stringValue),
        manageBluetooth: androidMap["manage_bluetooth"]?.boolValue ?? true,
        muteAudio: androidMap["mute_audio"]?.boolValue ?? false,
        useLegacy: androidMap["use_legacy"]?.boolValue ?? false)
    } else {
      android = Android(
        audioSource: "defaultSource", manageBluetooth: true, muteAudio: false,
        useLegacy: false)
    }

    if let iosMap = map["ios_configuration"]?.mapValue {
      ios = IOS(
        manageAudioSession: iosMap["manage_audio_session"]?.boolValue ?? true,
        options: iosMap["options"]?.arrayValue?.compactMap { value in
          guard let raw = value.stringValue else { return nil }
          return Self.iosOption(raw)
        } ?? [])
    } else {
      ios = IOS(
        manageAudioSession: true,
        options: ["defaultToSpeaker", "allowBluetooth", "allowBluetoothA2DP"])
    }
  }

  /// Properties accepted by Flet's cross-platform configuration that have no
  /// AVAudioRecorder equivalent. They are deliberately classified, not
  /// silently repurposed as unrelated Apple behavior.
  public var unsupportedAppleProperties: Set<String> {
    var result = Set<String>()
    if autoGain { result.insert("auto_gain") }
    if echoCancel { result.insert("cancel_echo") }
    if noiseSuppress { result.insert("suppress_noise") }
    return result
  }

  public static let androidOnlyProperties: Set<String> = [
    "android_configuration.audio_source", "android_configuration.manage_bluetooth",
    "android_configuration.mute_audio", "android_configuration.use_legacy",
  ]

  private static let encoders = [
    "aaclc": "aacLc", "aaceld": "aacEld", "aache": "aacHe", "amrnb": "amrNb",
    "amrwb": "amrWb", "opus": "opus", "flac": "flac",
    "pcm16bits": "pcm16bits", "wav": "wav",
  ]

  private static func encoder(_ value: String?) -> String {
    guard let value else { return "wav" }
    return encoders[normalized(value)] ?? "wav"
  }

  private static let androidAudioSources = [
    "defaultsource": "defaultSource", "mic": "mic", "voiceuplink": "voiceUplink",
    "voicedownlink": "voiceDownlink", "voicecall": "voiceCall",
    "voicerecognition": "voiceRecognition", "remotesubmix": "remoteSubMix",
    "voicecommunication": "voiceCommunication", "voiceperformance": "voicePerformance",
    "camcorder": "camcorder", "unprocessed": "unprocessed",
  ]

  private static func androidAudioSource(_ value: String?) -> String {
    guard let value else { return "defaultSource" }
    return androidAudioSources[normalized(value)] ?? "defaultSource"
  }

  private static let iosOptions = [
    "mixwithothers": "mixWithOthers", "duckothers": "duckOthers",
    "allowbluetooth": "allowBluetooth", "defaulttospeaker": "defaultToSpeaker",
    "interruptspokenaudioandmixwithothers": "interruptSpokenAudioAndMixWithOthers",
    "allowbluetootha2dp": "allowBluetoothA2DP", "allowairplay": "allowAirPlay",
    "overridemutedmicrophoneinterruption": "overrideMutedMicrophoneInterruption",
  ]

  private static func iosOption(_ value: String) -> String? {
    iosOptions[normalized(value)]
  }

  private static func normalized(_ value: String) -> String {
    value.lowercased()
  }
}

/// Flet's record stream event is a typed byte buffer. Ruflet has a native
/// MessagePack binary value, so no base-64 wrapper or platform-shaped map is
/// introduced on the Apple wire.
public enum AudioRecorderStreamEvent {
  public static func wireValue(_ data: Data) -> RufletValue {
    .binary(Array(data))
  }
}
