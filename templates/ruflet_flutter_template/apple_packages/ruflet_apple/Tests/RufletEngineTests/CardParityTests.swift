import RufletEngine
import RufletProtocol
import SwiftUI
@testable import RufletUI
import XCTest

/// Translated from Flet's CardControl constructor and Flutter's Material 3
/// Card defaults. These are engine contracts, not Explorer snapshot values.
final class CardParityTests: XCTestCase {
  private func node(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "Card", props: props)
  }

  func testElevatedCardUsesMaterialThreeDefaults() {
    let metrics = RufletCardMetrics(node: node())
    XCTAssertFalse(metrics.requiresCustomAppearance)
    XCTAssertEqual(metrics.variant, .elevated)
    XCTAssertEqual(metrics.fillToken, "surfacecontainerlow")
    XCTAssertEqual(metrics.shadowToken, "shadow")
    XCTAssertEqual(metrics.elevation, 1)
    XCTAssertEqual(metrics.radius, 12)
    XCTAssertFalse(metrics.shapeWasParsed)
    XCTAssertEqual(metrics.margin, EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    XCTAssertNil(metrics.outlineToken)
    XCTAssertEqual(metrics.clipBehavior, "none")
    XCTAssertTrue(metrics.semanticContainer)
    XCTAssertTrue(metrics.showBorderOnForeground)
  }

  func testFilledAndOutlinedVariantsResolveTheirOwnMaterialSurfaces() {
    let filled = RufletCardMetrics(node: node(["variant": .string("filled")]))
    XCTAssertFalse(filled.requiresCustomAppearance)
    XCTAssertEqual(filled.fillToken, "surfacecontainerhighest")
    XCTAssertEqual(filled.elevation, 0)
    XCTAssertNil(filled.outlineToken)

    let outlined = RufletCardMetrics(node: node(["variant": .string("outlined")]))
    XCTAssertEqual(outlined.fillToken, "surface")
    XCTAssertEqual(outlined.elevation, 0)
    XCTAssertEqual(outlined.outlineToken, "outlinevariant")
    XCTAssertEqual(outlined.outlineWidth, 1)
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
    XCTAssertTrue(metrics.requiresCustomAppearance)
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

  func testUnknownShapeIsNilThenFlutterAppliesVariantDefault() {
    let metrics = RufletCardMetrics(
      node: node([
        "variant": .string("outlined"),
        "shape": .map(["_type": .string("unknown")]),
      ]))
    XCTAssertEqual(metrics.variant, .outlined)
    XCTAssertFalse(metrics.shapeWasParsed)
    XCTAssertEqual(metrics.shapeKind, .roundedRectangle)
    XCTAssertEqual(metrics.radius, 12)
    XCTAssertEqual(metrics.outlineToken, "outlinevariant")
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

  func testCardContentUsesPinnedVisibleChildLookup() {
    let card = node(["content": .controlRef(2)])
    XCTAssertEqual(CardPresentation.visibleContentID(card, nodeForID: { id in
      id == 2 ? ControlNode(id: 2, type: "Text") : nil
    }), 2)
    XCTAssertNil(CardPresentation.visibleContentID(card, nodeForID: { id in
      id == 2 ? ControlNode(id: 2, type: "Text", props: ["visible": .bool(false)]) : nil
    }))
    XCTAssertNil(CardPresentation.visibleContentID(card, nodeForID: { _ in nil }))
  }

  func testRendererAlwaysUsesNativeAppleGroupBox() throws {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(contentsOf: package.appendingPathComponent(
      "Sources/RufletUI/Controls/ContainerControls.swift"))
    let start = try XCTUnwrap(source.range(of: "struct CardControlView"))
    let end = try XCTUnwrap(source.range(of: "/// `SafeArea`", range: start.upperBound..<source.endIndex))
    let card = source[start.lowerBound..<end.lowerBound]
    XCTAssertTrue(card.contains("GroupBox { cardContent }"))
    XCTAssertFalse(card.contains("customCard"))
    XCTAssertFalse(card.contains("MaterialPalette"))
    XCTAssertFalse(card.contains("RufletCardShape"))
  }
}
