@testable import RufletLottie
import Lottie
import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class LottiePluginParityTests: XCTestCase {
  func testSourceResolutionMatchesFletResolvedAssetSource() {
    XCTAssertEqual(LottieSource.resolve(nil), .empty)
    XCTAssertEqual(LottieSource.resolve(.string("  ")), .empty)
    XCTAssertEqual(
      LottieSource.resolve(.string(" https://example.test/animation.json ")),
      .uri("https://example.test/animation.json"))
    XCTAssertEqual(
      LottieSource.resolve(.string("assets/animation.json")),
      .uri("assets/animation.json"))
    XCTAssertEqual(LottieSource.resolve(.string("AQID")), .bytes([1, 2, 3]))
    XCTAssertEqual(
      LottieSource.resolve(.string("data:application/json;base64,e30=")),
      .bytes([123, 125]))
    XCTAssertEqual(LottieSource.resolve(.binary([4, 5])), .bytes([4, 5]))
    XCTAssertEqual(
      LottieSource.resolve(.array([.int(-1), .int(256)])),
      .bytes([255, 0]))
    XCTAssertEqual(
      LottieSource.resolve(.array([.string("1")])),
      .unsupported("src is not a supported source type."))
  }

  func testValidationAndRuntimeFailuresFollowFletErrorContract() {
    let missing = LottieFailure(
      title: "Lottie must have \"src\" specified.", detail: "",
      usesErrorContent: false, emitsEvent: false)
    XCTAssertFalse(missing.usesErrorContent)
    XCTAssertFalse(missing.emitsEvent)

    let decode = LottieFailure(
      title: "Error decoding src", detail: "unsupported",
      usesErrorContent: true, emitsEvent: false)
    XCTAssertTrue(decode.usesErrorContent)
    XCTAssertFalse(decode.emitsEvent)

    let runtime = LottieFailure(
      title: "Error loading Lottie", detail: "invalid JSON",
      usesErrorContent: true, emitsEvent: true)
    XCTAssertTrue(runtime.usesErrorContent)
    XCTAssertTrue(runtime.emitsEvent)
  }

  func testZipSignaturePreservesFlutterLottieArchiveSupport() {
    XCTAssertTrue(LottieResource(data: Data([0x50, 0x4B, 0x03, 0x04])).isZip)
    XCTAssertFalse(LottieResource(data: Data("{}".utf8)).isZip)
    XCTAssertFalse(LottieResource(data: Data([0x50])).isZip)
  }

  func testPinnedPlaybackDefaultsAndNativeOptionBoundary() {
    let node = ControlNode(id: 3, type: "Lottie")
    XCTAssertTrue(node.rufletBool("repeat"))
    XCTAssertFalse(node.rufletBool("reverse"))
    XCTAssertTrue(node.rufletBool("animate"))
    XCTAssertFalse(node.rufletBool("enable_merge_paths"))
    XCTAssertFalse(node.rufletBool("enable_layers_opacity"))

    XCTAssertEqual(LottieControlSemantics.loopMode(repeat: true, reverse: false), .loop)
    XCTAssertEqual(LottieControlSemantics.loopMode(repeat: true, reverse: true), .autoReverse)
    XCTAssertEqual(LottieControlSemantics.loopMode(repeat: false, reverse: true), .playOnce)
    XCTAssertEqual(LottieControlSemantics.layerFilter(nil), .linear)
    XCTAssertEqual(LottieControlSemantics.layerFilter("none"), .nearest)
    XCTAssertEqual(LottieControlSemantics.layerFilter("medium"), .trilinear)
    XCTAssertEqual(LottieControlSemantics.mergePathsSupport, .nativeRuntimeAlwaysOn)
    XCTAssertEqual(LottieControlSemantics.applyingLayerOpacitySupport, .nativeRuntimeAlwaysOn)
  }

  @MainActor
  func testLottieRemainsAnIndependentOptionalExtension() {
    let registry = ServiceRegistry()
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "Lottie")?.rendering,
      .optionalBundle("RufletLottie"))
    RufletLottie.register(in: registry)
    XCTAssertEqual(ControlRegistry.descriptor(for: "Lottie")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Lottie")?.supportedEvents,
      ["error", "load"])
  }
}
