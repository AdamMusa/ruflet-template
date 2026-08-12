import RufletEngine
import RufletProtocol
@testable import RufletUI
import SwiftUI
import XCTest

final class ShimmerShaderMaskParityTests: XCTestCase {
  private let colors: RufletValue = .array([.string("red"), .string("blue")])

  private func gradient(
    _ type: String = "linear", _ extra: [String: RufletValue] = [:]
  ) -> RufletValue {
    .map(["_type": .string(type), "colors": colors].merging(extra) { _, new in new })
  }

  func testShimmerKeepsPinnedDefaultsAndDurationForms() {
    let omitted = RufletShimmerConfiguration(node: ControlNode(
      id: 1, type: "Shimmer",
      props: [
        "content": .controlRef(2),
        "base_color": .string("grey"),
        "highlight_color": .string("white"),
      ]))
    XCTAssertEqual(omitted.contentID, 2)
    XCTAssertEqual(omitted.direction, .ltr)
    XCTAssertEqual(omitted.period, 1.5)
    XCTAssertNil(omitted.repeats)
    XCTAssertTrue(omitted.enabled)

    let mappedDuration = RufletShimmerConfiguration(node: ControlNode(
      id: 3, type: "Shimmer",
      props: [
        "content": .controlRef(2),
        "gradient": gradient(),
        "period": .map(["duration": .double(250)]),
        "loop": .int(4),
        "disabled": .bool(true),
      ]))
    XCTAssertEqual(mappedDuration.period, 0.25)
    XCTAssertEqual(mappedDuration.repeats, 4)
    XCTAssertFalse(mappedDuration.enabled)
  }

  func testShimmerValidationKeepsFletOrderAndExactMessages() {
    let missingContent = RufletShimmerConfiguration(node: ControlNode(
      id: 1, type: "Shimmer",
      props: ["base_color": .string("grey"), "highlight_color": .string("white")]))
    XCTAssertEqual(
      missingContent.validationError(contentIsVisible: false),
      "Shimmer.content must be specified")

    let missingColors = RufletShimmerConfiguration(node: ControlNode(
      id: 2, type: "Shimmer", props: ["content": .controlRef(3)]))
    XCTAssertEqual(
      missingColors.validationError(contentIsVisible: true),
      "Shimmer requires either gradient or base/highlight colors")

    let validPair = RufletShimmerConfiguration(node: ControlNode(
      id: 4, type: "Shimmer",
      props: [
        "content": .controlRef(3),
        "base_color": .string("grey"),
        "highlight_color": .string("white"),
      ]))
    XCTAssertNil(validPair.validationError(contentIsVisible: true))

    let validGradient = RufletShimmerConfiguration(node: ControlNode(
      id: 5, type: "Shimmer",
      props: ["content": .controlRef(3), "gradient": gradient("radial")]))
    XCTAssertNil(validGradient.validationError(contentIsVisible: true))
  }

  func testEveryShimmerDirectionHasExactTravelAxisAndSign() {
    let cases: [(String?, RufletShimmerDirection, Bool, CGFloat)] = [
      (nil, .ltr, true, 1),
      ("ltr", .ltr, true, 1),
      ("rtl", .rtl, true, -1),
      ("ttb", .ttb, false, 1),
      ("btt", .btt, false, -1),
      ("unknown", .ltr, true, 1),
    ]
    for (raw, expected, horizontal, multiplier) in cases {
      let direction = RufletShimmerDirection(raw)
      XCTAssertEqual(direction, expected)
      XCTAssertEqual(direction.horizontal, horizontal)
      XCTAssertEqual(direction.phaseMultiplier, multiplier)
    }
  }

  func testWrapperGradientPinsAllFletConstructorDefaults() throws {
    let linear = try XCTUnwrap(RufletWrapperGradient(gradient("linear")))
    XCTAssertEqual(linear.kind, .linear)
    XCTAssertEqual(linear.begin, .leading)
    XCTAssertEqual(linear.end, .trailing)
    XCTAssertEqual(linear.tileMode, "clamp")
    XCTAssertEqual(linear.rotation.radians, 0)

    let radial = try XCTUnwrap(RufletWrapperGradient(gradient("radial", [
      "focal": .string("top_left"),
      "focal_radius": .double(0.2),
      "tile_mode": .string("mirror"),
    ])))
    XCTAssertEqual(radial.kind, .radial)
    XCTAssertEqual(radial.center, .center)
    XCTAssertEqual(radial.radius, 0.5)
    XCTAssertEqual(radial.focal, .topLeading)
    XCTAssertEqual(radial.focalRadius, 0.2)
    XCTAssertEqual(radial.tileMode, "mirror")

    let sweep = try XCTUnwrap(RufletWrapperGradient(gradient("sweep")))
    XCTAssertEqual(sweep.kind, .sweep)
    XCTAssertEqual(sweep.startAngle.radians, 0)
    XCTAssertEqual(sweep.endAngle.radians, Double.pi * 2, accuracy: 0.000_001)
  }

  func testInvalidGradientCannotSatisfyEitherWrapper() {
    let oneColor = RufletValue.map([
      "_type": .string("linear"), "colors": .array([.string("red")]),
    ])
    XCTAssertNil(RufletWrapperGradient(oneColor))

    let configuration = RufletShimmerConfiguration(node: ControlNode(
      id: 1, type: "Shimmer",
      props: ["content": .controlRef(2), "gradient": oneColor]))
    XCTAssertFalse(configuration.hasValidColors)

    let mask = RufletShaderMaskPresentation(node: ControlNode(
      id: 2, type: "ShaderMask", props: ["shader": oneColor]))
    XCTAssertNil(mask.shader)
  }

  func testShaderMaskDefaultsAndContentAreIndependent() throws {
    let noContent = RufletShaderMaskPresentation(node: ControlNode(
      id: 1, type: "ShaderMask", props: ["shader": gradient()]))
    XCTAssertNil(noContent.contentID)
    XCTAssertEqual(noContent.blendModeToken, "modulate")
    XCTAssertEqual(noContent.blendMode, .multiply)
    XCTAssertNil(noContent.borderRadii)

    let explicit = RufletShaderMaskPresentation(node: ControlNode(
      id: 2, type: "ShaderMask",
      props: [
        "shader": gradient(),
        "content": .controlRef(9),
        "blend_mode": .string("screen"),
        "border_radius": .map([
          "top_left": .double(2), "bottom_right": .double(7),
        ]),
      ]))
    XCTAssertEqual(explicit.contentID, 9)
    XCTAssertEqual(explicit.blendModeToken, "screen")
    XCTAssertEqual(explicit.blendMode, .screen)
    XCTAssertEqual(try XCTUnwrap(explicit.borderRadii).topLeft, 2)
    XCTAssertEqual(try XCTUnwrap(explicit.borderRadii).topRight, 0)
    XCTAssertEqual(try XCTUnwrap(explicit.borderRadii).bottomRight, 7)
  }

  func testShaderMaskMissingShaderMessageMatchesFlet() {
    XCTAssertEqual(
      RufletShaderMaskPresentation.missingShaderError,
      "ShaderMask.shader must be provided")
    XCTAssertNil(RufletShaderMaskPresentation(
      node: ControlNode(id: 1, type: "ShaderMask")).shader)
  }
}
