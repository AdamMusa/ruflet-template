import XCTest
@testable import RufletUI
import RufletEngine
import RufletProtocol

final class WrapperControlParityTests: XCTestCase {
  func testScreenshotUsesFletCaptureDelayDefault() {
    XCTAssertEqual(RufletWrapperDefaults.screenshotDelay(nil), 20)
    XCTAssertEqual(RufletWrapperDefaults.screenshotDelay(0), 0)
    XCTAssertEqual(RufletWrapperDefaults.screenshotDelay(125), 125)
  }

  func testShimmerUsesFletPeriodAndLoopDefaults() {
    XCTAssertEqual(RufletWrapperDefaults.shimmerPeriod(nil), 1.5)
    XCTAssertEqual(RufletWrapperDefaults.shimmerPeriod(250), 0.25)
    XCTAssertNil(RufletWrapperDefaults.shimmerRepeats(nil))
    XCTAssertNil(RufletWrapperDefaults.shimmerRepeats(0))
    XCTAssertEqual(RufletWrapperDefaults.shimmerRepeats(3), 3)
  }

  func testShimmerRequiresTheSameConstructorInputsAsFlet() {
    let missing = RufletShimmerConfiguration(
      node: ControlNode(id: 1, type: "Shimmer"))
    XCTAssertFalse(missing.hasValidColors)
    XCTAssertTrue(missing.enabled)

    let pair = RufletShimmerConfiguration(
      node: ControlNode(
        id: 2, type: "Shimmer",
        props: [
          "base_color": .string("grey"),
          "highlight_color": .string("white"),
          "disabled": .bool(true),
        ]))
    XCTAssertTrue(pair.hasValidColors)
    XCTAssertFalse(pair.enabled)

    let gradient = RufletShimmerConfiguration(
      node: ControlNode(
        id: 3, type: "Shimmer",
        props: ["gradient": wrapperGradient("radial")]))
    XCTAssertTrue(gradient.hasValidColors)
  }

  func testWrapperGradientAcceptsEveryGradientTypeParsedByFlet() throws {
    XCTAssertEqual(try XCTUnwrap(RufletWrapperGradient(wrapperGradient("linear"))).kind, .linear)
    XCTAssertEqual(try XCTUnwrap(RufletWrapperGradient(wrapperGradient("radial"))).kind, .radial)
    XCTAssertEqual(try XCTUnwrap(RufletWrapperGradient(wrapperGradient("sweep"))).kind, .sweep)
    XCTAssertNil(RufletWrapperGradient(.map([
      "_type": .string("linear"), "colors": .array([.string("red")])
    ])))
    XCTAssertNil(RufletWrapperGradient(wrapperGradient("unsupported")))
    XCTAssertNil(RufletWrapperGradient(.map([
      "colors": .array([.string("red"), .string("blue")])
    ])))
  }

  func testShaderMaskDefaultsToFluttersModulateBlendMode() {
    XCTAssertEqual(RufletWrapperDefaults.shaderBlendMode(nil), .multiply)
    XCTAssertEqual(RufletWrapperDefaults.shaderBlendMode("modulate"), .multiply)
    XCTAssertEqual(RufletWrapperDefaults.shaderBlendMode("screen"), .screen)
  }

  func testHeroTagPreservesProtocolTypeAsWellAsValue() {
    XCTAssertEqual(RufletHeroTag(.int(7)), RufletHeroTag(.int(7)))
    XCTAssertNotEqual(RufletHeroTag(.int(7)), RufletHeroTag(.string("7")))
    XCTAssertNotEqual(RufletHeroTag(.bool(true)), RufletHeroTag(.string("true")))
    XCTAssertNotEqual(RufletHeroTag(.binary([1, 2])), RufletHeroTag(.binary([3, 4])))
    XCTAssertEqual(
      RufletHeroTag(.map(["a": .int(1), "b": .string("two")])),
      RufletHeroTag(.map(["b": .string("two"), "a": .int(1)])))
    XCTAssertNotEqual(
      RufletHeroTag(.array([.int(1), .string("2")])),
      RufletHeroTag(.array([.string("1"), .int(2)])))
  }

  func testHeroValidationMatchesFletsContentThenTagOrder() {
    XCTAssertEqual(
      RufletHeroSemantics.validationError(
        contentID: nil, contentIsVisible: false, tag: nil),
      "Hero.content must be provided and visible")
    XCTAssertEqual(
      RufletHeroSemantics.validationError(
        contentID: 2, contentIsVisible: false, tag: .string("avatar")),
      "Hero.content must be provided and visible")
    XCTAssertEqual(
      RufletHeroSemantics.validationError(
        contentID: 2, contentIsVisible: true, tag: nil),
      "Hero.tag must be provided")
    XCTAssertEqual(
      RufletHeroSemantics.validationError(
        contentID: 2, contentIsVisible: true, tag: .null),
      "Hero.tag must be provided")
    XCTAssertNil(RufletHeroSemantics.validationError(
      contentID: 2, contentIsVisible: true, tag: .int(0)))
  }

  func testHeroTransitionOnUserGesturesKeepsFletDefaultAndExplicitValue() {
    XCTAssertFalse(RufletHeroSemantics.transitionOnUserGestures(
      ControlNode(id: 1, type: "Hero")))
    XCTAssertTrue(RufletHeroSemantics.transitionOnUserGestures(ControlNode(
      id: 2, type: "Hero",
      props: ["transition_on_user_gestures": .bool(true)])))
  }

  func testOnlyTheActiveNativeRouteProvidesSharedHeroGeometry() {
    XCTAssertFalse(RufletHeroSemantics.providesGeometry(viewID: 10, activeViewID: 20))
    XCTAssertTrue(RufletHeroSemantics.providesGeometry(viewID: 20, activeViewID: 20))
  }

  func testSelectionAreaEmitsFletsNullablePlainTextPayload() {
    let source = "A 👋 selection"
    XCTAssertEqual(
      RufletSelectionAreaPayload.selection(
        in: source, range: NSRange(location: 2, length: 2)),
      "👋")
    XCTAssertNil(
      RufletSelectionAreaPayload.selection(
        in: source, range: NSRange(location: 4, length: 0)))
    XCTAssertNil(
      RufletSelectionAreaPayload.selection(
        in: source, range: NSRange(location: NSNotFound, length: 0)))
    XCTAssertNil(
      RufletSelectionAreaPayload.selection(
        in: source, range: NSRange(location: 0, length: source.utf16.count + 1)))
    XCTAssertEqual(RufletSelectionAreaPayload.data("selection"), .string("selection"))
    XCTAssertEqual(RufletSelectionAreaPayload.data(nil), .null)
  }

  private func wrapperGradient(_ type: String) -> RufletValue {
    .map([
      "_type": .string(type),
      "colors": .array([.string("red"), .string("blue")]),
      "stops": .array([.double(0), .double(1)]),
    ])
  }
}
