import CoreGraphics
import Foundation
import ImageIO
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class RufletCanvasInvariantTests: XCTestCase {
  func testResizeTrackerMatchesPinnedThrottleAndSizeChangeContract() {
    var tracker = RufletCanvasResizeTracker()

    XCTAssertTrue(
      tracker.update(
        size: CGSize(width: 20, height: 10), nowMilliseconds: 0, intervalMilliseconds: 10))
    XCTAssertFalse(
      tracker.update(
        size: CGSize(width: 20, height: 10), nowMilliseconds: 20, intervalMilliseconds: 10))
    XCTAssertFalse(
      tracker.update(
        size: CGSize(width: 21, height: 10), nowMilliseconds: 5, intervalMilliseconds: 10))
    XCTAssertTrue(
      tracker.update(
        size: CGSize(width: 21, height: 10), nowMilliseconds: 11, intervalMilliseconds: 10))
  }

  func testPaintConsumesEveryPinnedDrawingField() throws {
    let paint = RufletCanvasPaint(
      rufletAny(
        [
          "color": "#80112233",
          "blend_mode": "multiply",
          "anti_alias": false,
          "blur_image": ["sigma_x": 2, "sigma_y": 3, "tile_mode": "mirror"],
          "gradient": [
            "_type": "linear",
            "begin": ["x": 1, "y": 2],
            "end": ["x": 9, "y": 10],
            "colors": ["#FFFF0000", "#FF0000FF"],
            "color_stops": [0.2, 0.8],
            "tile_mode": "repeated",
          ],
          "stroke_miter_limit": 8,
          "stroke_width": 4,
          "stroke_cap": "round",
          "stroke_join": "bevel",
          "style": "stroke",
          "stroke_dash_pattern": [2, 1],
        ] as RufletValue))

    XCTAssertEqual(paint.blendMode, .multiply)
    XCTAssertFalse(paint.antiAlias)
    XCTAssertEqual(paint.blurX, 2)
    XCTAssertEqual(paint.blurY, 3)
    XCTAssertEqual(paint.blurTileMode, .mirror)
    XCTAssertEqual(paint.strokeMiterLimit, 8)
    XCTAssertEqual(paint.strokeWidth, 4)
    XCTAssertEqual(paint.strokeCap, .round)
    XCTAssertEqual(paint.strokeJoin, .bevel)
    XCTAssertEqual(paint.style, .stroke)
    XCTAssertEqual(paint.dashPattern, [2, 1])
    let gradient = try XCTUnwrap(paint.gradient)
    XCTAssertEqual(gradient.tileMode, .repeated)
    XCTAssertEqual(gradient.stops, [0.2, 0.8])
    guard case .linear(let begin, let end) = gradient.kind else {
      return XCTFail("Expected linear paint gradient")
    }
    XCTAssertEqual(begin, CGPoint(x: 1, y: 2))
    XCTAssertEqual(end, CGPoint(x: 9, y: 10))
  }

  func testPathBuildsEveryPinnedElementAndPreservesConicEndpoint() {
    let path = RufletCanvasRenderer.path(elements: [
      ["_type": "MoveTo", "x": 0, "y": 0],
      ["_type": "LineTo", "x": 10, "y": 0],
      [
        "_type": "Arc", "x": 10, "y": 0, "width": 10, "height": 8, "start_angle": 0,
        "sweep_angle": 1.5,
      ],
      [
        "_type": "ArcTo", "x": 28, "y": 12, "radius": 5, "rotation": 0.4, "large_arc": true,
        "clockwise": false,
      ],
      ["_type": "Oval", "x": 30, "y": 2, "width": 6, "height": 9],
      [
        "_type": "Rect", "x": 40, "y": 3, "width": 8, "height": 7,
        "border_radius": ["top_left": 1, "top_right": 2, "bottom_left": 3, "bottom_right": 4],
      ],
      ["_type": "MoveTo", "x": 50, "y": 5],
      ["_type": "QuadraticTo", "cp1x": 55, "cp1y": 20, "x": 60, "y": 5, "w": 0.5],
      ["_type": "CubicTo", "cp1x": 62, "cp1y": 0, "cp2x": 68, "cp2y": 10, "x": 70, "y": 5],
      [
        "_type": "SubPath", "x": 75, "y": 10,
        "elements": [
          ["_type": "MoveTo", "x": 0, "y": 0],
          ["_type": "LineTo", "x": 5, "y": 4],
          ["_type": "Close"],
        ],
      ],
      ["_type": "Close"],
    ])

    XCTAssertFalse(path.isEmpty)
    XCTAssertGreaterThanOrEqual(path.boundingBoxOfPath.maxX, 80)
    XCTAssertGreaterThanOrEqual(path.boundingBoxOfPath.maxY, 14)

    let conic = RufletCanvasRenderer.path(elements: [
      ["_type": "MoveTo", "x": 1, "y": 2],
      ["_type": "QuadraticTo", "cp1x": 8, "cp1y": 14, "x": 20, "y": 4, "w": 0.25],
    ])
    XCTAssertEqual(conic.currentPoint, CGPoint(x: 20, y: 4))
  }

  func testRadialAndSweepGradientsPreserveFocalAndRotationFields() throws {
    let radial = try XCTUnwrap(
      RufletCanvasGradient(
        rufletAny(
          [
            "_type": "radial",
            "colors": ["#FFFFFFFF", "#FF000000"],
            "center": [3, 4],
            "radius": 12,
            "focal": [5, 6],
            "focal_radius": 2,
            "tile_mode": "mirror",
          ] as RufletValue)))
    guard case .radial(let center, let radius, let focal, let focalRadius) = radial.kind else {
      return XCTFail("Expected radial gradient")
    }
    XCTAssertEqual(center, CGPoint(x: 3, y: 4))
    XCTAssertEqual(radius, 12)
    XCTAssertEqual(focal, CGPoint(x: 5, y: 6))
    XCTAssertEqual(focalRadius, 2)

    let sweep = try XCTUnwrap(
      RufletCanvasGradient(
        rufletAny(
          [
            "_type": "sweep",
            "colors": ["#FFFF0000", "#FF0000FF"],
            "center": [7, 8],
            "start_angle": 0.5,
            "end_angle": 5.5,
            "rotation": 0.75,
            "tile_mode": "decal",
          ] as RufletValue)))
    guard case .sweep(let center, let start, let end, let rotation) = sweep.kind else {
      return XCTFail("Expected sweep gradient")
    }
    XCTAssertEqual(center, CGPoint(x: 7, y: 8))
    XCTAssertEqual(start, 0.5)
    XCTAssertEqual(end, 5.5)
    XCTAssertEqual(rotation, 0.75)
    XCTAssertEqual(sweep.tileMode, .decal)
  }

  func testAllPinnedShapeTypesRenderIntoNativeBitmap() {
    let backend = CanvasTestBackend()
    let shapes: [RufletValue] = [
      wireShape(2, "Fill", ["paint": paint(color: "#FFFFFFFF")]),
      wireShape(3, "Color", ["color": "#10FF0000", "blend_mode": "srcOver"]),
      wireShape(4, "Line", ["x1": 1, "y1": 1, "x2": 20, "y2": 1, "paint": strokePaint]),
      wireShape(5, "Circle", ["x": 8, "y": 8, "radius": 4, "paint": paint(color: "#FFFF0000")]),
      wireShape(
        6, "Arc",
        [
          "x": 2, "y": 2, "width": 12, "height": 10, "start_angle": 0, "sweep_angle": 2.4,
          "use_center": true, "paint": paint(color: "#FF00FF00"),
        ]),
      wireShape(
        7, "Oval", ["x": 12, "y": 3, "width": 8, "height": 5, "paint": paint(color: "#FF0000FF")]),
      wireShape(
        8, "Points",
        [
          "points": [["x": 2, "y": 15], ["x": 10, "y": 15], ["x": 18, "y": 15]],
          "point_mode": "polygon", "paint": strokePaint,
        ]),
      wireShape(
        9, "Rect",
        [
          "x": 1, "y": 17, "width": 9, "height": 5, "border_radius": 2,
          "paint": paint(color: "#FFFFFF00"),
        ]),
      wireShape(
        10, "Path",
        [
          "elements": [
            ["_type": "MoveTo", "x": 12, "y": 17], ["_type": "LineTo", "x": 20, "y": 22],
            ["_type": "Close"],
          ], "paint": paint(color: "#FFFF00FF"),
        ]),
      wireShape(
        11, "Shadow",
        [
          "path": [["_type": "Rect", "x": 3, "y": 3, "width": 4, "height": 4]],
          "color": "#80000000", "elevation": 2, "transparent_occluder": true,
        ]),
      wireShape(
        12, "Text",
        [
          "x": 1, "y": 23, "value": "Apple", "max_width": 20, "max_lines": 1, "ellipsis": "…",
          "rotate": 0.1, "alignment": ["x": -1, "y": -1], "text_align": "center",
          "style": [
            "size": 6, "color": "#FF000000", "weight": "bold", "italic": true, "height": 1.1,
            "letter_spacing": 0.2, "word_spacing": 0.3, "decoration": 5,
          ],
        ]),
    ]
    let root = RufletControl(
      id: 1,
      type: "Canvas",
      properties: ["shapes": .array(shapes)],
      backend: backend)

    let image = RufletCanvasRenderer.makeImage(
      size: CGSize(width: 24, height: 30),
      pixelRatio: 2,
      shapes: root.children("shapes"),
      images: [:],
      capturedImage: nil,
      capturedSize: .zero)

    XCTAssertEqual(image?.width, 48)
    XCTAssertEqual(image?.height, 60)
  }

  func testCaptureGetAndClearMethodsPreservePinnedOrderingAndPNGBytes() async throws {
    let backend = CanvasTestBackend()
    let root = RufletControl(
      id: 20,
      type: "Canvas",
      properties: ["shapes": [wireShape(21, "Color", ["color": "#FFFF0000"])]],
      backend: backend)
    let coordinator = RufletCanvasCoordinator()
    coordinator.configure(control: root)
    coordinator.updateSize(CGSize(width: 4, height: 3), resizeIntervalMilliseconds: 10)

    let captureResult = try await coordinator.invoke("capture", arguments: ["pixel_ratio": 2])
    XCTAssertEqual(captureResult, .null)
    let capture = try await coordinator.invoke("get_capture", arguments: [:])
    guard case .binary(let bytes) = capture else { return XCTFail("Expected PNG bytes") }
    let source = try XCTUnwrap(CGImageSourceCreateWithData(bytes as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    XCTAssertEqual(image.width, 8)
    XCTAssertEqual(image.height, 6)

    let clearResult = try await coordinator.invoke("clear_capture", arguments: [:])
    let clearedCapture = try await coordinator.invoke("get_capture", arguments: [:])
    XCTAssertEqual(clearResult, .null)
    XCTAssertEqual(clearedCapture, .null)
    XCTAssertEqual(backend.events.first?.name, "resize")
    XCTAssertEqual(backend.events.first?.data.map?["w"]?.number, 4)
    XCTAssertEqual(backend.events.first?.data.map?["h"]?.number, 3)
  }

  func testCaptureWaitsForInlineImageLoad() async throws {
    let backend = CanvasTestBackend()
    let png = try XCTUnwrap(solidPNGData())
    let root = RufletControl(
      id: 30,
      type: "Canvas",
      properties: [
        "shapes": [
          wireShape(
            31, "Image",
            [
              "src": .binary(png),
              "x": 1,
              "y": 2,
              "width": 6,
              "height": 4,
              "paint": [
                "anti_alias": false,
                "blend_mode": "srcOver",
                "blur_image": [0, 0],
              ],
            ])
        ]
      ],
      backend: backend)
    let coordinator = RufletCanvasCoordinator()
    coordinator.configure(control: root)
    coordinator.updateSize(CGSize(width: 8, height: 8), resizeIntervalMilliseconds: 10)

    _ = try await coordinator.invoke("capture", arguments: ["pixel_ratio": 1])

    XCTAssertEqual(coordinator.images[31]?.image.width, 1)
    XCTAssertEqual(coordinator.images[31]?.image.height, 1)
    XCTAssertNotNil(coordinator.capturedImage)
  }
}

private let strokePaint: RufletValue = [
  "color": "#FF000000", "style": "stroke", "stroke_width": 1,
  "stroke_cap": "round", "stroke_join": "round", "stroke_dash_pattern": [2, 1],
]

private func paint(color: String) -> RufletValue { ["color": .string(color)] }

private func wireShape(
  _ id: Int,
  _ type: String,
  _ properties: [String: RufletValue]
) -> RufletValue {
  var result = properties
  result["_i"] = .int(Int64(id))
  result["_c"] = .string(type)
  return .map(result)
}

private func solidPNGData() -> Data? {
  guard
    let context = CGContext(
      data: nil,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { return nil }
  context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
  guard let image = context.makeImage() else { return nil }
  let data = NSMutableData()
  guard
    let destination = CGImageDestinationCreateWithData(
      data,
      "public.png" as CFString,
      1,
      nil)
  else { return nil }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { return nil }
  return data as Data
}

@MainActor
private final class CanvasTestBackend: RufletBackendProtocol {
  struct Event {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var events: [Event] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
