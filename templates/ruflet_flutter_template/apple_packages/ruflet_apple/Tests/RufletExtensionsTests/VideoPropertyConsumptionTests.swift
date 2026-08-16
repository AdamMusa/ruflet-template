import AVFoundation
import QuartzCore
import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletVideo

@MainActor
final class VideoPropertyConsumptionTests: XCTestCase {
  func testConfigurationConsumesPinnedControllerAndPlayerFields() {
    let configuration = RufletVideoConfiguration(
      control: control(properties: [
        "title": .string("Demo video"),
        "configuration": .map([
          "output_driver": .string("gpu-next"),
          "hardware_decoding_api": .string("videotoolbox"),
          "enable_hardware_acceleration": .bool(false),
          "width": .int(640),
          "height": .int(360),
          "scale": .double(1.5),
          "mpv_properties": .map([
            "deband": .bool(true),
            "video-sync": .string("display-resample"),
            "cache-secs": .int(8),
          ]),
        ]),
      ]))

    XCTAssertEqual(configuration.title, "Demo video")
    XCTAssertEqual(configuration.outputDriver, "gpu-next")
    XCTAssertEqual(configuration.hardwareDecodingAPI, "videotoolbox")
    XCTAssertFalse(configuration.enableHardwareAcceleration)
    XCTAssertEqual(configuration.width, 640)
    XCTAssertEqual(configuration.height, 360)
    XCTAssertEqual(configuration.scale, 1.5)
    XCTAssertEqual(configuration.preferredMaximumResolution, CGSize(width: 960, height: 540))
    XCTAssertEqual(configuration.mpvProperties["deband"], "yes")
    XCTAssertEqual(configuration.mpvProperties["video-sync"], "display-resample")
    XCTAssertEqual(configuration.mpvProperties["cache-secs"], "8.0")
  }

  func testConfigurationUsesPinnedDefaultsAndRejectsInvalidResolution() {
    let defaults = RufletVideoConfiguration(control: control(properties: [:]))
    XCTAssertEqual(defaults.title, "flet-video")
    XCTAssertTrue(defaults.enableHardwareAcceleration)
    XCTAssertEqual(defaults.scale, 1)
    XCTAssertNil(defaults.preferredMaximumResolution)

    let invalid = RufletVideoConfiguration(
      control: control(properties: [
        "configuration": .map([
          "width": .int(640),
          "height": .int(0),
          "scale": .int(2),
        ])
      ]))
    XCTAssertNil(invalid.preferredMaximumResolution)
  }

  func testFilterQualityMapsEveryPinnedModeToNativeScalingFilters() {
    XCTAssertEqual(RufletVideoFilterQuality(nil), .low)
    XCTAssertEqual(RufletVideoFilterQuality("NONE"), .none)
    XCTAssertEqual(RufletVideoFilterQuality("medium"), .medium)
    XCTAssertEqual(RufletVideoFilterQuality("high"), .high)
    XCTAssertEqual(RufletVideoFilterQuality("unknown"), .low)

    let layer = CALayer()
    let child = CALayer()
    layer.addSublayer(child)
    applyVideoFilterQuality(.high, to: layer)
    XCTAssertEqual(layer.magnificationFilter, .trilinear)
    XCTAssertEqual(layer.minificationFilter, .trilinear)
    XCTAssertEqual(child.magnificationFilter, .trilinear)

    applyVideoFilterQuality(.none, to: layer)
    XCTAssertEqual(layer.magnificationFilter, .nearest)
    XCTAssertEqual(child.minificationFilter, .nearest)
  }

  func testRemotePlaylistMediaUsesTheBackendResolvedURL() throws {
    let url = "https://media.example.test/video.mp4"
    let backend = VideoTestBackend(
      resolvedSource: RufletAssetSource(path: url, isFile: false))
    let control = RufletControl(
      id: 1,
      type: "Video",
      properties: [:],
      backend: backend)
    let media = RufletVideoMedia(
      resource: .string("clip.mp4"), extras: [:], httpHeaders: [:])

    let item = try makeVideoItem(media, control: control)

    XCTAssertEqual((item.asset as? AVURLAsset)?.url.absoluteString, url)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "Video",
      properties: properties,
      backend: VideoTestBackend())
  }
}

@MainActor
private final class VideoTestBackend: RufletBackendProtocol {
  let resolvedSource: RufletAssetSource?
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  init(resolvedSource: RufletAssetSource? = nil) {
    self.resolvedSource = resolvedSource
  }

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { resolvedSource }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
