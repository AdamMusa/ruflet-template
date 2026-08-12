import RufletEngine
import RufletProtocol
import SwiftUI
@testable import RufletUI
import XCTest

/// Flet Card wire behavior mapped onto native Apple presentation. Omitted
/// visuals stay native; explicit DSL visuals are resolved by the renderer.
final class CardParityTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "Card", props: props)
  }

  func testOmittedCardVisualsUseNativeAppleAppearance() {
    let metrics = RufletCardMetrics(node: node())
    XCTAssertTrue(metrics.usesNativeAppearance)
    XCTAssertEqual(metrics.variant, .elevated)
    XCTAssertNil(metrics.fillToken)
    XCTAssertNil(metrics.shadowToken)
    XCTAssertEqual(metrics.elevation, 0)
    XCTAssertEqual(metrics.radius, 0)
    XCTAssertFalse(metrics.shapeWasParsed)
    XCTAssertEqual(metrics.margin, EdgeInsets())
    XCTAssertNil(metrics.outlineToken)
    XCTAssertEqual(metrics.clipBehavior, "none")
    XCTAssertTrue(metrics.semanticContainer)
    XCTAssertTrue(metrics.showBorderOnForeground)
  }

  func testVariantsPreserveWireMeaningWithoutForcingMaterialPresentation() {
    let filled = RufletCardMetrics(node: node(["variant": .string("filled")]))
    XCTAssertTrue(filled.usesNativeAppearance)
    XCTAssertEqual(filled.variant, .filled)
    XCTAssertNil(filled.fillToken)
    XCTAssertEqual(filled.elevation, 0)
    XCTAssertNil(filled.outlineToken)

    let outlined = RufletCardMetrics(node: node(["variant": .string("outlined")]))
    XCTAssertTrue(outlined.usesNativeAppearance)
    XCTAssertEqual(outlined.variant, .outlined)
    XCTAssertNil(outlined.fillToken)
    XCTAssertEqual(outlined.elevation, 0)
    XCTAssertNil(outlined.outlineToken)
    XCTAssertEqual(outlined.outlineWidth, 0)
  }

  func testExplicitCardConstructorValuesOverrideDefaults() {
    let metrics = RufletCardMetrics(
      node: node([
        "bgcolor": .string("red"),
        "shadow_color": .string("blue"),
        "elevation": .double(7),
        "margin": .map([
          "left": .double(1), "top": .double(2),
          "right": .double(3), "bottom": .double(4),
        ]),
        "clip_behavior": .string("antiAlias"),
        "semantic_container": .bool(false),
        "show_border_on_foreground": .bool(false),
      ]))
    XCTAssertEqual(metrics.fillToken, "red")
    XCTAssertEqual(metrics.shadowToken, "blue")
    XCTAssertEqual(metrics.elevation, 7)
    XCTAssertEqual(metrics.margin, EdgeInsets(top: 2, leading: 1, bottom: 4, trailing: 3))
    XCTAssertEqual(metrics.clipBehavior, "antiAlias")
    XCTAssertFalse(metrics.semanticContainer)
    XCTAssertFalse(metrics.showBorderOnForeground)
  }

  func testExplicitShapeReplacesRatherThanMergesOutlinedDefault() {
    let noSide = RufletCardMetrics(
      node: node([
        "variant": .string("outlined"),
        "shape": .map([
          "_type": .string("stadium"), "radius": .double(30),
        ]),
      ]))
    XCTAssertEqual(noSide.shapeKind, .stadium)
    XCTAssertEqual(noSide.radius, 30)
    XCTAssertNil(noSide.outlineToken)

    let side = RufletCardMetrics(
      node: node([
        "shape": .map([
          "_type": .string("beveledrectangle"),
          "radius": .double(8),
          "side": .map(["color": .string("green"), "width": .double(3)]),
        ]),
      ]))
    XCTAssertEqual(side.shapeKind, .beveledRectangle)
    XCTAssertEqual(side.radius, 8)
    XCTAssertTrue(side.shapeWasParsed)
    XCTAssertEqual(side.outlineToken, "green")
    XCTAssertEqual(side.outlineWidth, 3)
  }

  func testUnknownShapeDoesNotInventAMaterialVariantBorder() {
    let metrics = RufletCardMetrics(
      node: node([
        "variant": .string("outlined"),
        "shape": .map(["_type": .string("unknown")]),
      ]))
    XCTAssertEqual(metrics.variant, .outlined)
    XCTAssertFalse(metrics.shapeWasParsed)
    XCTAssertEqual(metrics.shapeKind, .roundedRectangle)
    XCTAssertEqual(metrics.radius, 0)
    XCTAssertNil(metrics.outlineToken)
  }

  func testShapeParserPreservesIndependentRadiiCircleEccentricityAndStrokeAlign() {
    let rectangle = RufletCardMetrics(
      node: node([
        "shape": .map([
          "_type": .string("roundedrectangle"),
          "radius": .map([
            "top_left": .double(1), "top_right": .double(2),
            "bottom_left": .double(3), "bottom_right": .double(4),
          ]),
          "side": .map([
            "color": .string("red"), "width": .double(2),
            "stroke_align": .double(0),
          ]),
        ])
      ]))
    XCTAssertEqual(
      rectangle.radii,
      RufletCornerRadii(topLeft: 1, topRight: 2, bottomLeft: 3, bottomRight: 4))
    XCTAssertEqual(rectangle.outlineStrokeAlign, 0)

    let circle = RufletCardMetrics(
      node: node([
        "shape": .map([
          "_type": .string("circle"), "eccentricity": .double(0.75),
        ])
      ]))
    XCTAssertEqual(circle.eccentricity, 0.75)
  }
}
