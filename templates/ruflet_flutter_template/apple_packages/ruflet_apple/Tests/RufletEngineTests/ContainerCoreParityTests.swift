import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletUI

final class ContainerCoreParityTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "Container", props: props)
  }

  func testOmittedContainerPropertiesStayAbsentAndUseFletClipDefault() {
    let semantics = RufletContainerSemantics(node: node())
    XCTAssertNil(semantics.padding)
    XCTAssertNil(semantics.alignment)
    XCTAssertNil(semantics.backgroundColorToken)
    XCTAssertNil(semantics.border)
    XCTAssertNil(semantics.gradient)
    XCTAssertNil(semantics.image)
    XCTAssertEqual(semantics.shape, .rectangle)
    XCTAssertEqual(semantics.clipBehavior, .none)
    XCTAssertFalse(semantics.hasBorderRadius)
    XCTAssertEqual(semantics.radii, RufletCornerRadii(uniform: 0))
    XCTAssertEqual(semantics.blur, RufletContainerBlur(nil))
  }

  func testBorderRadiusChangesOnlyTheOmittedClipDefault() {
    let rounded = RufletContainerSemantics(node: node(["border_radius": .double(12)]))
    XCTAssertTrue(rounded.hasBorderRadius)
    XCTAssertEqual(rounded.radii, RufletCornerRadii(uniform: 12))
    XCTAssertEqual(rounded.clipBehavior, .antiAlias)

    let explicitNone = RufletContainerSemantics(node: node([
      "border_radius": .double(12), "clip_behavior": .string("none"),
    ]))
    XCTAssertEqual(explicitNone.clipBehavior, .none)
    XCTAssertEqual(
      RufletContainerSemantics(node: node(["clip_behavior": .string("hard_edge")]))
        .clipBehavior,
      .hardEdge)
    XCTAssertEqual(
      RufletContainerSemantics(node: node([
        "clip_behavior": .string("anti_alias_with_save_layer"),
      ])).clipBehavior,
      .antiAliasWithSaveLayer)
  }

  func testCircleShapeDoesNotInventBorderRadius() {
    let semantics = RufletContainerSemantics(node: node(["shape": .string("circle")]))
    XCTAssertEqual(semantics.shape, .circle)
    XCTAssertFalse(semantics.hasBorderRadius)
    XCTAssertEqual(semantics.clipBehavior, .none)
  }

  func testBlurAcceptsEveryFletWireForm() {
    XCTAssertEqual(RufletContainerBlur(.double(4)),
                   RufletContainerBlur(.map(["sigma_x": .double(4), "sigma_y": .double(4)])))

    let pair = RufletContainerBlur(.array([.double(3), .double(7)]))
    XCTAssertEqual(pair.sigmaX, 3)
    XCTAssertEqual(pair.sigmaY, 7)
    XCTAssertEqual(pair.maximumSigma, 7)

    let mapped = RufletContainerBlur(.map([
      "sigma_x": .double(2), "sigma_y": .double(5), "tile_mode": .string("mirror"),
    ]))
    XCTAssertEqual(mapped.sigmaX, 2)
    XCTAssertEqual(mapped.sigmaY, 5)
    XCTAssertEqual(mapped.tileMode, "mirror")
  }

  func testGradientConstructorsKeepPinnedFletDefaults() throws {
    let colors: RufletValue = .array([.string("red"), .string("blue")])
    let linear = try XCTUnwrap(RufletGradientSpec(.map([
      "_type": .string("linear"), "colors": colors,
    ])))
    guard case .linear(let tokens, let stops, let begin, let end, let tile, let rotation) = linear
    else { return XCTFail("expected linear gradient") }
    XCTAssertEqual(tokens, ["red", "blue"])
    XCTAssertNil(stops)
    XCTAssertEqual(begin, .centerLeft)
    XCTAssertEqual(end, .centerRight)
    XCTAssertEqual(tile, "clamp")
    XCTAssertNil(rotation)

    let radial = try XCTUnwrap(RufletGradientSpec(.map([
      "_type": .string("radial"), "colors": colors,
    ])))
    guard case .radial(_, _, let center, let radius, let focal, let focalRadius, let tile, _) = radial
    else { return XCTFail("expected radial gradient") }
    XCTAssertEqual(center, .center)
    XCTAssertEqual(radius, 0.5)
    XCTAssertNil(focal)
    XCTAssertEqual(focalRadius, 0)
    XCTAssertEqual(tile, "clamp")

    let sweep = try XCTUnwrap(RufletGradientSpec(.map([
      "_type": .string("sweep"), "colors": colors,
    ])))
    guard case .sweep(_, _, let center, let start, let end, let tile, _) = sweep
    else { return XCTFail("expected sweep gradient") }
    XCTAssertEqual(center, .center)
    XCTAssertEqual(start, 0)
    XCTAssertEqual(end, 0)
    XCTAssertEqual(tile, "clamp")
    XCTAssertNil(RufletGradientSpec(.map(["_type": .string("unknown"), "colors": colors])))
  }

  func testDecorationImageKeepsFlutterConstructorDefaults() throws {
    let image = try XCTUnwrap(RufletDecorationImageSpec(.map(["src": .string("photo.png")])))
    XCTAssertEqual(image.source, .asset("photo.png"))
    XCTAssertNil(image.fit)
    XCTAssertEqual(image.alignment, .center)
    XCTAssertEqual(image.repeatMode, .noRepeat)
    XCTAssertFalse(image.matchTextDirection)
    XCTAssertEqual(image.scale, 1)
    XCTAssertEqual(image.opacity, 1)
    XCTAssertEqual(image.filterQuality, "medium")
    XCTAssertFalse(image.invertColors)
    XCTAssertFalse(image.antiAlias)
    XCTAssertNil(image.colorFilter)
    XCTAssertNil(RufletDecorationImageSpec(.map([:])))
  }

  func testBorderAndShadowParsersKeepFletSideDefaults() throws {
    let semantics = RufletContainerSemantics(node: node([
      "border": .map(["top": .map([:])]),
    ]))
    XCTAssertEqual(semantics.border?.top?.width, 1)
    XCTAssertNil(semantics.border?.right)

    let single = RufletBoxShadowSpec.parseList(.map([:]))
    XCTAssertEqual(single.count, 1)
    XCTAssertNil(single[0].colorToken)
    XCTAssertEqual(single[0].offsetX, 0)
    XCTAssertEqual(single[0].offsetY, 0)
    XCTAssertEqual(single[0].blurStyle, "normal")
    XCTAssertEqual(single[0].blurRadius, 0)
    XCTAssertEqual(single[0].spreadRadius, 0)
    XCTAssertEqual(
      RufletBoxShadowSpec.parseList(.array([.map([:]), .map([:])])).count,
      2)
  }

  func testContainerAnimationAcceptsBoolIntegerAndMapForms() throws {
    let bool = try XCTUnwrap(RufletContainerAnimationSpec(.bool(true)))
    XCTAssertEqual(bool.durationMilliseconds, 1_000)
    XCTAssertEqual(bool.curve, "linear")

    let integer = try XCTUnwrap(RufletContainerAnimationSpec(.int(250)))
    XCTAssertEqual(integer.durationMilliseconds, 250)
    XCTAssertEqual(integer.curve, "linear")

    let map = try XCTUnwrap(RufletContainerAnimationSpec(.map([
      "duration": .double(480), "curve": .string("easeInOut"),
    ])))
    XCTAssertEqual(map.durationMilliseconds, 480)
    XCTAssertEqual(map.curve, "easeinout")
    XCTAssertNil(RufletContainerAnimationSpec(nil))
  }
}
