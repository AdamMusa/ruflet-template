@testable import RufletAudio
import RufletEngine
import RufletProtocol
import XCTest

final class AudioPluginParityTests: XCTestCase {
  func testSourceResolutionMatchesFletResolvedAssetSource() throws {
    XCTAssertEqual(
      try FletAudioSource.resolve(.string(" https://example.test/tone.mp3 ")),
      .uri("https://example.test/tone.mp3"))
    XCTAssertEqual(
      try FletAudioSource.resolve(.string("assets/tone.mp3")),
      .uri("assets/tone.mp3"))
    XCTAssertEqual(
      try FletAudioSource.resolve(.string("AQID")),
      .bytes([1, 2, 3]))
    XCTAssertEqual(
      try FletAudioSource.resolve(.string("AQI")),
      .bytes([1, 2]))
    XCTAssertEqual(
      try FletAudioSource.resolve(.string("data:audio/mpeg;base64,AQID")),
      .bytes([1, 2, 3]))
    XCTAssertEqual(
      try FletAudioSource.resolve(.binary([4, 5, 6])),
      .bytes([4, 5, 6]))
    XCTAssertEqual(
      try FletAudioSource.resolve(.array([.int(-1), .int(256)])),
      .bytes([255, 0]))
    XCTAssertNil(try FletAudioSource.resolve(.string("  ")))
    XCTAssertThrowsError(try FletAudioSource.resolve(.array([.string("7")])))
  }

  func testDurationArgumentsAndResultsPreserveFletWireSemantics() {
    XCTAssertEqual(FletAudioDuration.milliseconds(.int(250)), 250)
    XCTAssertEqual(FletAudioDuration.milliseconds(.double(4.5)), 0)
    XCTAssertEqual(
      FletAudioDuration.milliseconds(.extended(type: 3, string: "250000")),
      250)
    XCTAssertEqual(
      FletAudioDuration.milliseconds(.map([
        "minutes": .int(1), "seconds": .int(2), "milliseconds": .int(3),
        "microseconds": .int(500),
      ])),
      62_003.5)
    XCTAssertEqual(
      FletAudioDuration.wireValue(milliseconds: 1_234),
      .extended(type: 3, string: "1234000"))
  }

  func testOptionsPreserveDefaultsValidationAndReleaseModeParsing() {
    let defaults = AudioPlaybackOptions(ControlNode(id: 1, type: "Audio"))
    XCTAssertFalse(defaults.autoplay)
    XCTAssertEqual(defaults.validVolume, 1)
    XCTAssertEqual(defaults.validBalance, 0)
    XCTAssertEqual(defaults.playbackRate, 1)
    XCTAssertNil(defaults.releaseMode)

    let invalid = AudioPlaybackOptions(ControlNode(id: 2, type: "Audio", props: [
      "volume": .double(2), "balance": .double(-2),
      "release_mode": .string("NOT_A_MODE"),
    ]))
    XCTAssertNil(invalid.validVolume)
    XCTAssertNil(invalid.validBalance)
    XCTAssertEqual(invalid.releaseMode, "not_a_mode")
  }

  @MainActor
  func testReleaseReportsAudioplayersStoppedStateRatherThanDisposed() throws {
    let node = ControlNode(
      id: 9, type: "Audio", props: ["on_state_change": .bool(true)])
    var events: [(String, RufletValue)] = []
    let context = RufletServiceContext(store: ControlStore()) { _, name, data in
      events.append((name, data))
    }
    let service = AudioService()
    service.activate(node: node, context: context)

    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: 9, callID: "release", name: "release", args: .map([:])),
      node: node,
      context: context
    ) { result = $0 }

    XCTAssertEqual(try result?.get(), .null)
    XCTAssertEqual(events.map(\.0), ["state_change"])
    XCTAssertEqual(events.first?.1, .map(["state": .string("stopped")]))
  }

  @MainActor
  func testAudioRemainsAnIndependentOptionalExtension() {
    let registry = ServiceRegistry()
    XCTAssertFalse(registry.handles("Audio"))
    registry.register(extension: RufletAudio.self)
    XCTAssertTrue(registry.hasExtension("RufletAudio"))
    XCTAssertTrue(registry.handles("Audio"))
  }
}
