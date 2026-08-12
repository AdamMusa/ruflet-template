import Foundation
@testable import RufletAudioRecorder
import RufletEngine
import RufletProtocol
import XCTest

@MainActor
final class AudioRecorderPluginParityTests: XCTestCase {
  private func invoke(
    _ service: AudioRecorderService,
    method: String,
    args: [String: RufletValue] = [:]
  ) -> Result<RufletValue, Error>? {
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(
        controlID: 27, callID: "audio-recorder-test", name: method, args: .map(args)),
      node: ControlNode(id: 27, type: AudioRecorderService.wireType),
      context: RufletServiceContext(store: ControlStore()) { _, _, _ in }
    ) { result = $0 }
    return result
  }

  func testMissingConfigurationMatchesFletNullParser() {
    XCTAssertNil(AudioRecorderConfiguration(nil))
    XCTAssertNil(AudioRecorderConfiguration(.null))
  }

  func testStartConfigurationComesOnlyFromPinnedMethodArguments() {
    let node = ControlNode(
      id: 27, type: AudioRecorderService.wireType,
      props: ["configuration": .map(["encoder": .string("flac")])])
    let missing = RufletMethodCall(
      controlID: 27, callID: "missing-config", name: "start_recording",
      args: .map([:]))
    XCTAssertNil(
      AudioRecorderService.recordingConfigurationValue(for: missing, node: node))

    let explicitValue: RufletValue = .map(["encoder": .string("wav")])
    let explicit = RufletMethodCall(
      controlID: 27, callID: "explicit-config", name: "start_recording",
      args: .map(["configuration": explicitValue]))
    XCTAssertEqual(
      AudioRecorderService.recordingConfigurationValue(for: explicit, node: node),
      explicitValue)
  }

  func testEmptyConfigurationMatchesEveryPinnedFletDefault() throws {
    let config = try XCTUnwrap(AudioRecorderConfiguration(.map([:])))
    XCTAssertFalse(config.autoGain)
    XCTAssertEqual(config.bitRate, 128_000)
    XCTAssertEqual(config.encoder, "wav")
    XCTAssertFalse(config.echoCancel)
    XCTAssertFalse(config.noiseSuppress)
    XCTAssertEqual(config.channels, 2)
    XCTAssertNil(config.device)
    XCTAssertEqual(config.sampleRate, 44_100)
    XCTAssertEqual(config.android.audioSource, "defaultSource")
    XCTAssertTrue(config.android.manageBluetooth)
    XCTAssertFalse(config.android.muteAudio)
    XCTAssertFalse(config.android.useLegacy)
    XCTAssertTrue(config.ios.manageAudioSession)
    XCTAssertEqual(
      config.ios.options, ["defaultToSpeaker", "allowBluetooth", "allowBluetoothA2DP"])
  }

  func testConfigurationParsesEveryFletPropertyAndCaseInsensitiveEnums() throws {
    let config = try XCTUnwrap(AudioRecorderConfiguration(.map([
      "auto_gain": .bool(true), "bit_rate": .int(96_000),
      "encoder": .string("AACELD"), "cancel_echo": .bool(true),
      "suppress_noise": .bool(true), "channels": .int(1),
      "sample_rate": .int(48_000),
      "device": .map(["id": .string("input-1"), "label": .string("Studio Mic")]),
      "android_configuration": .map([
        "audio_source": .string("VOICECOMMUNICATION"),
        "manage_bluetooth": .bool(false), "mute_audio": .bool(true),
        "use_legacy": .bool(true),
      ]),
      "ios_configuration": .map([
        "manage_audio_session": .bool(false),
        "options": .array([
          .string("MIXWITHOTHERS"), .string("allowAirPlay"),
          .string("notAnOption"),
        ]),
      ]),
    ])))
    XCTAssertTrue(config.autoGain)
    XCTAssertEqual(config.bitRate, 96_000)
    XCTAssertEqual(config.encoder, "aacEld")
    XCTAssertTrue(config.echoCancel)
    XCTAssertTrue(config.noiseSuppress)
    XCTAssertEqual(config.channels, 1)
    XCTAssertEqual(config.sampleRate, 48_000)
    XCTAssertEqual(
      config.device, .init(id: "input-1", label: "Studio Mic"))
    XCTAssertEqual(config.android.audioSource, "voiceCommunication")
    XCTAssertFalse(config.android.manageBluetooth)
    XCTAssertTrue(config.android.muteAudio)
    XCTAssertTrue(config.android.useLegacy)
    XCTAssertFalse(config.ios.manageAudioSession)
    XCTAssertEqual(config.ios.options, ["mixWithOthers", "allowAirPlay"])
    XCTAssertEqual(
      config.unsupportedAppleProperties, ["auto_gain", "cancel_echo", "suppress_noise"])
  }

  func testEnumParsingDoesNotAcceptAliasesAbsentFromPinnedRecordEnums() throws {
    let config = try XCTUnwrap(AudioRecorderConfiguration(.map([
      "encoder": .string("AAC_ELD"),
      "android_configuration": .map([
        "audio_source": .string("VOICE_COMMUNICATION")
      ]),
      "ios_configuration": .map([
        "options": .array([.string("MIX_WITH_OTHERS")])
      ]),
    ])))

    XCTAssertEqual(config.encoder, "wav")
    XCTAssertEqual(config.android.audioSource, "defaultSource")
    XCTAssertEqual(config.ios.options, [])
  }

  func testAllPinnedAndroidAudioSourcesAreRecognized() throws {
    for (value, expected) in [
      ("voiceRecognition", "voiceRecognition"),
      ("REMOTESUBMIX", "remoteSubMix"),
    ] {
      let config = try XCTUnwrap(AudioRecorderConfiguration(.map([
        "android_configuration": .map(["audio_source": .string(value)])
      ])))
      XCTAssertEqual(config.android.audioSource, expected)
    }
  }

  func testUnknownEnumsUseTheSameFletFallbacks() throws {
    let config = try XCTUnwrap(AudioRecorderConfiguration(.map([
      "encoder": .string("futureCodec"),
      "android_configuration": .map(["audio_source": .string("futureSource")]),
      "ios_configuration": .map([
        "options": .array([.string("futureOption")])
      ]),
    ])))
    XCTAssertEqual(config.encoder, "wav")
    XCTAssertEqual(config.android.audioSource, "defaultSource")
    // An explicitly supplied iOS config has an explicitly parsed option list;
    // invalid members are dropped rather than restoring IosRecordConfig defaults.
    XCTAssertEqual(config.ios.options, [])
  }

  func testStreamEventUsesNativeMessagePackBinary() {
    XCTAssertEqual(
      AudioRecorderStreamEvent.wireValue(Data([0, 1, 127, 255])),
      .binary([0, 1, 127, 255]))
  }

  func testAndroidOnlySettingsAreExplicitlyClassified() {
    XCTAssertEqual(AudioRecorderConfiguration.androidOnlyProperties, [
      "android_configuration.audio_source", "android_configuration.manage_bluetooth",
      "android_configuration.mute_audio", "android_configuration.use_legacy",
    ])
  }

  func testEncoderSupportMatchesPinnedDarwinRecordPlugins() throws {
    let service = AudioRecorderService()
    let commonSupport: [String: Bool] = [
      "wav": true, "pcm16bits": true, "aacLc": true,
      "aacEld": true, "flac": true,
      "aacHe": false, "amrNb": false, "amrWb": false,
    ]

    for (encoder, expected) in commonSupport {
      XCTAssertEqual(
        try invoke(
          service, method: "is_supported_encoder",
          args: ["encoder": .string(encoder)])?.get(),
        .bool(expected), encoder)
    }

    #if os(iOS)
      let opusSupported = true
    #else
      let opusSupported = false
    #endif
    XCTAssertEqual(
      try invoke(
        service, method: "is_supported_encoder",
        args: ["encoder": .string("opus")])?.get(),
      .bool(opusSupported))

    // parseAudioEncoder has no default for this command. Invalid spelling and
    // unknown future values therefore fall through with Dart null.
    for invalid in ["AAC_LC", "aac-eld", "futureCodec"] {
      XCTAssertEqual(
        try invoke(
          service, method: "is_supported_encoder",
          args: ["encoder": .string(invalid)])?.get(),
        .null, invalid)
    }
  }

  func testIdleCommandResultsMatchRecordService() throws {
    let service = AudioRecorderService()

    XCTAssertEqual(try invoke(service, method: "stop_recording")?.get(), .null)
    XCTAssertEqual(try invoke(service, method: "cancel_recording")?.get(), .null)
    XCTAssertEqual(try invoke(service, method: "pause_recording")?.get(), .null)
    XCTAssertEqual(try invoke(service, method: "resume_recording")?.get(), .null)
    XCTAssertEqual(try invoke(service, method: "is_recording")?.get(), .bool(false))
    XCTAssertEqual(try invoke(service, method: "is_paused")?.get(), .bool(false))
    XCTAssertEqual(
      try invoke(service, method: "start_recording", args: [:])?.get(),
      .bool(false))
  }

  func testUnknownMethodIsAWireFailure() {
    guard case .failure(let error)? = invoke(AudioRecorderService(), method: "rewind"),
      case .unsupportedMethod(AudioRecorderService.wireType, "rewind") =
        error as? RufletServiceError
    else {
      return XCTFail("unknown AudioRecorder methods must fail")
    }
  }
}
