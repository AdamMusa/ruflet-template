import RufletEngine
@testable import RufletMedia
import RufletProtocol
@testable import RufletUI
import XCTest

final class MediaPluginParityTests: XCTestCase {
  func testMediaDescriptorsMatchPinnedFletMethodsAndEvents() throws {
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "Video")).supportedMethods,
      ["get_current_position", "get_duration", "is_completed", "is_playing", "jump_to",
       "next", "pause", "play", "play_or_pause", "playlist_add", "playlist_remove",
       "previous", "seek", "stop"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "Video")).supportedEvents,
      ["complete", "enter_fullscreen", "error", "exit_fullscreen", "loaded", "track_change"])

    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "Audio")).supportedMethods,
      ["get_current_position", "get_duration", "pause", "play", "release", "resume", "seek"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "Audio")).supportedEvents,
      ["duration_change", "loaded", "position_change", "seek_complete", "state_change"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "AudioRecorder")).supportedMethods,
      ["cancel_recording", "get_input_devices", "has_permission", "is_paused", "is_recording",
       "is_supported_encoder", "pause_recording", "resume_recording", "start_recording",
       "stop_recording"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "AudioRecorder")).supportedEvents,
      ["state_change"])

    let camera = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "Camera"))
    XCTAssertEqual(camera.supportedEvents, ["state_change", "stream_image"])
    XCTAssertEqual(camera.supportedMethods, [
      "get_available_cameras", "get_exposure_offset_step_size", "get_max_exposure_offset",
      "get_max_zoom_level", "get_min_exposure_offset", "get_min_zoom_level", "initialize",
      "lock_capture_orientation", "pause_preview", "pause_video_recording",
      "prepare_for_video_recording", "resume_preview", "resume_video_recording",
      "set_description", "set_exposure_mode", "set_exposure_offset", "set_exposure_point",
      "set_flash_mode", "set_focus_mode", "set_focus_point", "set_zoom_level",
      "start_image_stream", "start_video_recording", "stop_image_stream",
      "stop_video_recording", "supports_image_streaming", "take_picture",
      "unlock_capture_orientation",
    ])
  }

  func testVideoUsesPinnedFletDefaults() {
    let node = ControlNode(id: 1, type: "Video")
    XCTAssertEqual(node.rufletString("alignment"), "center")
    XCTAssertEqual(node.rufletBool("autoplay"), false)
    XCTAssertEqual(node.rufletBool("muted"), false)
    XCTAssertEqual(node.rufletBool("show_controls"), true)
    XCTAssertEqual(node.rufletBool("pause_upon_entering_background_mode"), true)
    // This default is supplied by the Flet video plug-in at build time rather
    // than the generated Python control contract.
    XCTAssertEqual(node.bool("resume_upon_entering_foreground_mode") ?? false, false)
    XCTAssertEqual(node.rufletBool("wakelock"), true)
  }

  func testVideoMediaParsesFletResourceAndHeaders() throws {
    let source = try XCTUnwrap(VideoMediaSource(.map([
      "resource": .string("https://example.test/movie.mp4"),
      "http_headers": .map(["Authorization": .string("Bearer token")]),
      "extras": .map(["platform-specific": .string("ignored by AVFoundation")]),
    ])))
    XCTAssertEqual(source.resource, "https://example.test/movie.mp4")
    XCTAssertEqual(source.httpHeaders, ["Authorization": "Bearer token"])
  }

  #if canImport(AVKit)
    @MainActor
    func testVideoVolumeUsesFletZeroToOneHundredScale() {
      let events = RufletEventSink()
      let onePercent = VideoPlayerModel()
      onePercent.configure(
        from: ControlNode(id: 2, type: "Video", props: ["volume": .double(1)]),
        events: events)
      XCTAssertEqual(onePercent.player.volume, 0.01, accuracy: 0.0001)

      let defaultVolume = VideoPlayerModel()
      defaultVolume.configure(from: ControlNode(id: 3, type: "Video"), events: events)
      XCTAssertEqual(defaultVolume.player.volume, 1, accuracy: 0.0001)
    }
  #endif

  @MainActor
  func testRecorderRequiresNativeOutputPathLikePinnedFlet() {
    let service = AudioRecorderService()
    let store = ControlStore()
    let node = ControlNode(id: 7, type: "AudioRecorder")
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(
        controlID: node.id, callID: "record", name: "start_recording",
        args: .map(["configuration": .map([:])])),
      node: node,
      context: RufletServiceContext(store: store, emitEvent: { _, _, _ in })
    ) { result = $0 }
    XCTAssertEqual(try? result?.get(), .bool(false))
  }

  @MainActor
  func testRecorderRecognizesPinnedFletEncoderNames() {
    let service = AudioRecorderService()
    let node = ControlNode(id: 8, type: "AudioRecorder")
    let context = RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })

    let expectedSupport = [
      "wav": true, "pcm16bits": true, "aacLc": true, "aacEld": true,
      "opus": true, "flac": true, "aacHe": false, "amrNb": false,
      "amrWb": false, "unknown": false,
    ]
    for (encoder, supported) in expectedSupport {
      var result: Result<RufletValue, Error>?
      service.invoke(
        RufletMethodCall(
          controlID: node.id, callID: encoder, name: "is_supported_encoder",
          args: .map(["encoder": .string(encoder)])),
        node: node, context: context
      ) { result = $0 }
      XCTAssertEqual(try? result?.get(), .bool(supported), encoder)
    }
  }

  @MainActor
  func testCameraRequiresDescriptionBeforeInitialization() {
    let model = CameraModel()
    let node = ControlNode(id: 9, type: "Camera")
    var result: Result<RufletValue, Error>?
    model.handle(
      RufletMethodCall(
        controlID: node.id, callID: "initialize", name: "initialize", args: .map([:])),
      node: node, events: RufletEventSink()
    ) { result = $0 }

    guard case .failure(let error) = result else {
      return XCTFail("initialize without a camera description must fail")
    }
    XCTAssertTrue(error.localizedDescription.contains("description"))
  }

  @MainActor
  func testCameraIgnoresUnknownOptionalEnumLikePinnedParser() {
    let model = CameraModel()
    let node = ControlNode(id: 10, type: "Camera")
    var result: Result<RufletValue, Error>?
    model.handle(
      RufletMethodCall(
        controlID: node.id, callID: "flash", name: "set_flash_mode",
        args: .map(["mode": .string("not_a_flash_mode")])),
      node: node, events: RufletEventSink()
    ) { result = $0 }
    XCTAssertEqual(try? result?.get(), .null)
  }

  @MainActor
  func testRecorderDoesNotEmitDuplicateStoppedState() {
    let service = AudioRecorderService()
    let node = ControlNode(
      id: 11, type: "AudioRecorder", props: ["on_state_change": .bool(true)])
    var emitted: [RufletValue] = []
    let context = RufletServiceContext(
      store: ControlStore(), emitEvent: { _, name, value in
        if name == "state_change" { emitted.append(value) }
      })
    service.invoke(
      RufletMethodCall(
        controlID: node.id, callID: "stop", name: "stop_recording", args: .map([:])),
      node: node, context: context
    ) { _ in }
    XCTAssertTrue(emitted.isEmpty)
  }
}
