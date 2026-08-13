import AVFoundation
import Foundation
import RufletProtocol

public enum RufletAudioEncoder: String, CaseIterable, Sendable {
  case aacLc
  case aacEld
  case aacHe
  case amrNb
  case amrWb
  case opus
  case flac
  case wav
  case pcm16bits

  public static func parse(_ value: String?, default defaultValue: Self? = nil) -> Self? {
    guard let value else { return defaultValue }
    return allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
      ?? defaultValue
  }

  public var appleFormatID: AudioFormatID? {
    switch self {
    case .aacLc: kAudioFormatMPEG4AAC
    case .aacEld: kAudioFormatMPEG4AAC_ELD
    case .aacHe: kAudioFormatMPEG4AAC_HE
    case .opus: kAudioFormatOpus
    case .flac: kAudioFormatFLAC
    case .wav, .pcm16bits: kAudioFormatLinearPCM
    case .amrNb, .amrWb: nil
    }
  }
}

public struct RufletAudioInputDevice: Equatable, Sendable {
  public let id: String
  public let label: String

  public init(id: String, label: String) {
    self.id = id
    self.label = label
  }

  public static func parse(_ value: Any?) -> Self? {
    let value = unwrapRufletValue(value)
    guard
      let value = value as? [String: Any],
      let id = value["id"] as? String,
      let label = value["label"] as? String
    else { return nil }
    return Self(id: id, label: label)
  }
}

public enum RufletIOSAudioCategoryOption: String, CaseIterable, Sendable {
  case mixWithOthers
  case duckOthers
  case allowBluetooth
  case defaultToSpeaker
  case interruptSpokenAudioAndMixWithOthers
  case allowBluetoothA2DP
  case allowAirPlay
  case overrideMutedMicrophoneInterruption

  public static func parse(_ value: String?) -> Self? {
    guard let value else { return nil }
    return allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
  }

  #if os(iOS)
  var avOption: AVAudioSession.CategoryOptions {
    switch self {
    case .mixWithOthers: .mixWithOthers
    case .duckOthers: .duckOthers
    case .allowBluetooth: .allowBluetoothHFP
    case .defaultToSpeaker: .defaultToSpeaker
    case .interruptSpokenAudioAndMixWithOthers: .interruptSpokenAudioAndMixWithOthers
    case .allowBluetoothA2DP: .allowBluetoothA2DP
    case .allowAirPlay: .allowAirPlay
    case .overrideMutedMicrophoneInterruption: .overrideMutedMicrophoneInterruption
    }
  }
  #endif
}

public struct RufletIOSRecordConfiguration: Equatable, Sendable {
  public var manageAudioSession: Bool
  public var categoryOptions: [RufletIOSAudioCategoryOption]

  public init(
    manageAudioSession: Bool = true,
    categoryOptions: [RufletIOSAudioCategoryOption] = [
      .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP,
    ]
  ) {
    self.manageAudioSession = manageAudioSession
    self.categoryOptions = categoryOptions
  }

  public static func parse(_ value: Any?, default defaultValue: Self = .init()) -> Self {
    let value = unwrapRufletValue(value)
    guard let value = value as? [String: Any] else { return defaultValue }
    let options = (value["options"] as? [Any] ?? [])
      .compactMap { RufletIOSAudioCategoryOption.parse($0 as? String) }
    return Self(
      manageAudioSession: value.bool("manage_audio_session") ?? true,
      categoryOptions: options)
  }
}

public struct RufletRecordConfiguration: Equatable, Sendable {
  public var autoGain: Bool
  public var bitRate: Int
  public var encoder: RufletAudioEncoder
  public var echoCancellation: Bool
  public var noiseSuppression: Bool
  public var channels: Int
  public var device: RufletAudioInputDevice?
  public var sampleRate: Int
  public var ios: RufletIOSRecordConfiguration

  public init(
    autoGain: Bool = false,
    bitRate: Int = 128_000,
    encoder: RufletAudioEncoder = .wav,
    echoCancellation: Bool = false,
    noiseSuppression: Bool = false,
    channels: Int = 2,
    device: RufletAudioInputDevice? = nil,
    sampleRate: Int = 44_100,
    ios: RufletIOSRecordConfiguration = .init()
  ) {
    self.autoGain = autoGain
    self.bitRate = bitRate
    self.encoder = encoder
    self.echoCancellation = echoCancellation
    self.noiseSuppression = noiseSuppression
    self.channels = channels
    self.device = device
    self.sampleRate = sampleRate
    self.ios = ios
  }

  public static func parse(_ value: Any?) -> Self? {
    let value = unwrapRufletValue(value)
    guard let value = value as? [String: Any] else { return nil }
    return Self(
      autoGain: value.bool("auto_gain") ?? false,
      bitRate: value.int("bit_rate") ?? 128_000,
      encoder: .parse(value["encoder"] as? String, default: .wav) ?? .wav,
      echoCancellation: value.bool("cancel_echo") ?? false,
      noiseSuppression: value.bool("suppress_noise") ?? false,
      channels: value.int("channels") ?? 2,
      device: RufletAudioInputDevice.parse(value["device"]),
      sampleRate: value.int("sample_rate") ?? 44_100,
      ios: .parse(value["ios_configuration"]))
  }

  public var recorderSettings: [String: Any] {
    var settings: [String: Any] = [
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: channels,
      AVEncoderBitRateKey: bitRate,
    ]
    if let format = encoder.appleFormatID {
      settings[AVFormatIDKey] = format
    }
    if encoder == .wav || encoder == .pcm16bits {
      settings[AVLinearPCMBitDepthKey] = 16
      settings[AVLinearPCMIsFloatKey] = false
      settings[AVLinearPCMIsBigEndianKey] = false
    }
    return settings
  }
}

private func unwrapRufletValue(_ value: Any?) -> Any? {
  guard let value = value as? RufletValue else { return value }
  switch value {
  case .null: return nil
  case .bool(let value): return value
  case .int(let value): return Int(value)
  case .double(let value): return value
  case .string(let value): return value
  case .binary(let value): return value
  case .array(let values): return values.map { unwrapRufletValue($0) as Any }
  case .map(let values): return values.mapValues { unwrapRufletValue($0) as Any }
  case .keyedMap(let values):
    return Dictionary<AnyHashable, Any>(uniqueKeysWithValues: values.map { key, value in
      let unwrappedKey: AnyHashable = switch key {
      case .string(let text): AnyHashable(text)
      case .int(let integer): AnyHashable(integer)
      }
      return (unwrappedKey, unwrapRufletValue(value) as Any)
    })
  case .extensionValue: return nil
  }
}

private extension Dictionary where Key == String, Value == Any {
  func bool(_ key: String) -> Bool? {
    switch self[key] {
    case let value as Bool: value
    case let value as NSNumber: value.boolValue
    case let value as String: ["true", "1", "yes", "on"].contains(value.lowercased())
    default: nil
    }
  }

  func int(_ key: String) -> Int? {
    switch self[key] {
    case let value as Int: value
    case let value as NSNumber: value.intValue
    case let value as String: Int(value)
    default: nil
    }
  }
}
