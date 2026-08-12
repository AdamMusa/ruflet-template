import RufletEngine
@testable import RufletCamera
import RufletProtocol
@testable import RufletUI
import XCTest

final class CameraPluginParityTests: XCTestCase {
  func testInitializationUsesPinnedFletCameraDefaults() {
    let call = RufletMethodCall(
      controlID: 1, callID: "initialize", name: "initialize",
      args: .map(["description": cameraDescription]))
    let options = CameraInitializationOptions(call)

    XCTAssertEqual(options.description, cameraDescription)
    XCTAssertEqual(options.resolutionPreset, "max")
    XCTAssertTrue(options.enableAudio)
    XCTAssertNil(options.fps)
    XCTAssertNil(options.videoBitrate)
    XCTAssertNil(options.audioBitrate)
    XCTAssertEqual(options.imageFormatGroup, "unknown")
    XCTAssertEqual(
      CameraInitializationOptions.avFoundationUnsupportedProperties,
      ["audio_bitrate", "video_bitrate"])
  }

  func testInitializationPreservesEveryFletConstructorOption() {
    let call = RufletMethodCall(
      controlID: 1, callID: "initialize", name: "initialize",
      args: .map([
        "description": cameraDescription,
        "resolution_preset": .string("high"), "enable_audio": .bool(false),
        "fps": .int(24), "video_bitrate": .int(2_000_000),
        "audio_bitrate": .int(128_000), "image_format_group": .string("bgra8888"),
      ]))
    let options = CameraInitializationOptions(call)

    XCTAssertEqual(options.resolutionPreset, "high")
    XCTAssertFalse(options.enableAudio)
    XCTAssertEqual(options.fps, 24)
    XCTAssertEqual(options.videoBitrate, 2_000_000)
    XCTAssertEqual(options.audioBitrate, 128_000)
    XCTAssertEqual(options.imageFormatGroup, "bgra8888")
  }

  func testCameraEnumsFollowFlutterCameraNamesAndNullParserBehavior() {
    XCTAssertEqual(CameraWireSemantics.flashMode("off"), "off")
    XCTAssertEqual(CameraWireSemantics.flashMode("auto"), "auto")
    XCTAssertEqual(CameraWireSemantics.flashMode("always"), "always")
    XCTAssertEqual(CameraWireSemantics.flashMode("torch"), "torch")
    XCTAssertNil(CameraWireSemantics.flashMode("on"))
    XCTAssertNil(CameraWireSemantics.flashMode("invalid"))

    XCTAssertEqual(CameraWireSemantics.focusMode("auto"), "auto")
    XCTAssertEqual(CameraWireSemantics.exposureMode("locked"), "locked")
    XCTAssertNil(CameraWireSemantics.focusMode("continuous"))

    XCTAssertEqual(CameraWireSemantics.orientation("portrait_up"), "portrait_up")
    XCTAssertEqual(CameraWireSemantics.orientation("portrait_down"), "portrait_down")
    XCTAssertEqual(CameraWireSemantics.orientation("landscape_left"), "landscape_left")
    XCTAssertEqual(CameraWireSemantics.orientation("landscape_right"), "landscape_right")
    XCTAssertNil(CameraWireSemantics.orientation("face_up"))
  }

  func testCameraVisualDefaultIsSourceOwned() {
    XCTAssertTrue(CameraWireSemantics.previewEnabled)
  }

  func testAppleResolutionPresetKeepsPinnedCamelCaseNames() {
    XCTAssertEqual(CameraWireSemantics.resolutionPreset(nil), "max")
    XCTAssertEqual(CameraWireSemantics.resolutionPreset("VERYHIGH"), "veryHigh")
    XCTAssertEqual(CameraWireSemantics.resolutionPreset("ultraHigh"), "ultraHigh")
    XCTAssertEqual(CameraWireSemantics.resolutionPreset("very_high"), "max")
    XCTAssertEqual(CameraWireSemantics.resolutionPreset("invented"), "max")
  }

  func testAppleStreamFormatsFollowCameraAvfoundationFallbacks() {
    XCTAssertEqual(CameraWireSemantics.appleStreamFormat("yuv420"), "yuv420")
    XCTAssertEqual(CameraWireSemantics.appleStreamFormat("bgra8888"), "bgra8888")
    XCTAssertEqual(CameraWireSemantics.appleStreamFormat("jpeg"), "bgra8888")
    XCTAssertEqual(CameraWireSemantics.appleStreamFormat("nv21"), "bgra8888")
    XCTAssertEqual(CameraWireSemantics.appleStreamFormat("unknown"), "bgra8888")
    XCTAssertEqual(CameraWireSemantics.appleStreamFormat(nil), "bgra8888")
  }

  private var cameraDescription: RufletValue {
    .map([
      "name": .string("camera-id"), "lens_direction": .string("back"),
      "sensor_orientation": .int(90), "lens_type": .string("wide"),
    ])
  }
}
