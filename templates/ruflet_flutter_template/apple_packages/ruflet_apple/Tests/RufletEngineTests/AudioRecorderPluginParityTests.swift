import Foundation
@testable import RufletAudioRecorder
import RufletProtocol
import XCTest

final class AudioRecorderPluginParityTests: XCTestCase {
  func testMissingConfigurationMatchesFletNullParser() {
    XCTAssertNil(AudioRecorderConfiguration(nil))
    XCTAssertNil(AudioRecorderConfiguration(.null))
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
      "encoder": .string("AAC_ELD"), "cancel_echo": .bool(true),
      "suppress_noise": .bool(true), "channels": .int(1),
      "sample_rate": .int(48_000),
      "device": .map(["id": .string("input-1"), "label": .string("Studio Mic")]),
      "android_configuration": .map([
        "audio_source": .string("VOICE_COMMUNICATION"),
        "manage_bluetooth": .bool(false), "mute_audio": .bool(true),
        "use_legacy": .bool(true),
      ]),
      "ios_configuration": .map([
        "manage_audio_session": .bool(false),
        "options": .array([
          .string("MIX_WITH_OTHERS"), .string("allowAirPlay"),
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
}
