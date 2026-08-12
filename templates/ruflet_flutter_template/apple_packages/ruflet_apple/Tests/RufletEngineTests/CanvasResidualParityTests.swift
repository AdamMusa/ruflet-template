import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CanvasResidualParityTests: XCTestCase {
  func testTextLayoutUsesPinnedDefaults() {
    let layout = CanvasTextLayout(node: ControlNode(id: 1, type: "Text"))
    XCTAssertEqual(layout.point, .zero)
    XCTAssertEqual(layout.alignment, .topLeft)
    XCTAssertEqual(layout.textAlign, "start")
    XCTAssertNil(layout.maxLines)
    XCTAssertNil(layout.maxWidth)
    XCTAssertNil(layout.ellipsis)
    XCTAssertEqual(layout.rotation, 0)
    XCTAssertEqual(layout.anchor.x, 0)
    XCTAssertEqual(layout.anchor.y, 0)
  }

  func testTextLayoutConsumesWidthLinesEllipsisAlignmentAndRotation() {
    let layout = CanvasTextLayout(node: ControlNode(
      id: 1, type: "Text",
      props: [
        "x": .double(20), "y": .double(30),
        "alignment": .map(["x": .double(0.5), "y": .double(-0.5)]),
        "text_align": .string("justify"), "max_lines": .int(3),
        "max_width": .double(240), "ellipsis": .string("..."),
        "rotate": .double(.pi / 3),
      ]))
    XCTAssertEqual(layout.point, CGPoint(x: 20, y: 30))
    XCTAssertEqual(layout.alignment, RufletAlignment(x: 0.5, y: -0.5))
    XCTAssertEqual(layout.textAlign, "justify")
    XCTAssertEqual(layout.maxLines, 3)
    XCTAssertEqual(layout.maxWidth, 240)
    XCTAssertEqual(layout.ellipsis, "...")
    XCTAssertEqual(layout.rotation, .pi / 3)
    XCTAssertEqual(layout.anchor.x, 0.75)
    XCTAssertEqual(layout.anchor.y, 0.25)
  }

  func testTextAlignAcceptsOnlyPinnedFlutterNames() {
    let expected = [
      "center": "center", "end": "end", "justify": "justify",
      "left": "left", "right": "right", "start": "start",
      "unknown": "start",
    ]
    for (input, output) in expected {
      let layout = CanvasTextLayout(node: ControlNode(
        id: 1, type: "Text", props: ["text_align": .string(input)]))
      XCTAssertEqual(layout.textAlign, output)
    }
  }

  func testImageUsesExplicitDestinationOnlyWhenBothDimensionsExist() {
    let intrinsic = CGSize(width: 80, height: 60)
    XCTAssertEqual(
      CanvasImageLayout.destination(
        x: 4, y: 5, width: nil, height: nil, intrinsic: intrinsic),
      CGRect(x: 4, y: 5, width: 80, height: 60))
    XCTAssertEqual(
      CanvasImageLayout.destination(
        x: 4, y: 5, width: 120, height: nil, intrinsic: intrinsic),
      CGRect(x: 4, y: 5, width: 80, height: 60),
      "Flet ignores a lone width")
    XCTAssertEqual(
      CanvasImageLayout.destination(
        x: 4, y: 5, width: nil, height: 90, intrinsic: intrinsic),
      CGRect(x: 4, y: 5, width: 80, height: 60),
      "Flet ignores a lone height")
    XCTAssertEqual(
      CanvasImageLayout.destination(
        x: 4, y: 5, width: 120, height: 90, intrinsic: intrinsic),
      CGRect(x: 4, y: 5, width: 120, height: 90))
  }

  func testMissingConicWeightMatchesPinnedBuildPathZeroDefault() {
    let missingWeight = CanvasControlView.path(from: [
      .map(["_type": .string("MoveTo"), "x": .double(0), "y": .double(0)]),
      .map([
        "_type": .string("QuadraticTo"),
        "cp1x": .double(50), "cp1y": .double(100),
        "x": .double(100), "y": .double(0),
      ]),
    ])
    let ordinaryQuadratic = CanvasControlView.path(from: [
      .map(["_type": .string("MoveTo"), "x": .double(0), "y": .double(0)]),
      .map([
        "_type": .string("QuadraticTo"),
        "cp1x": .double(50), "cp1y": .double(100),
        "x": .double(100), "y": .double(0), "w": .double(1),
      ]),
    ])
    XCTAssertEqual(missingWeight.boundingRect.height, 0, accuracy: 0.001)
    XCTAssertGreaterThan(ordinaryQuadratic.boundingRect.height, 45)
  }

  func testCanvasTextAndCaptureRouteThroughSettledNativeSymbols() throws {
    let source = try String(contentsOf: sourceURL)
    XCTAssertTrue(source.contains("RufletRichTextDocument("))
    XCTAssertTrue(source.contains("spanIDs: node.controlIDs(forKey: \"spans\")"))
    XCTAssertTrue(source.contains("await imageCache.load(imageShapes"))
    XCTAssertTrue(source.contains("CanvasShapeTextView(node: shape, store: store)"))
    XCTAssertTrue(source.contains("RufletImageAssetURL.imageAsset"))
  }

  private var sourceURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletUI/Controls/MediaControls.swift")
  }
}
