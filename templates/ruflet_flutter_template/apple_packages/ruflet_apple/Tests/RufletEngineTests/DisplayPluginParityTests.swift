@testable import RufletUI
import RufletProtocol
import XCTest

final class DisplayPluginParityTests: XCTestCase {
  func testDisplayEventsUseFletWireNames() {
    XCTAssertEqual(events("Text"), ["selection_change", "tap"])
    XCTAssertEqual(events("TextSpan"), ["click", "enter", "exit"])
    XCTAssertEqual(events("CircleAvatar"), ["image_error"])
    XCTAssertEqual(events("Markdown"), ["selection_change", "tap_link", "tap_text"])
    XCTAssertEqual(events("Lottie"), ["error", "load"])
    XCTAssertEqual(events("Rive"), [])
  }

  func testCanvasAndChartsAdvertiseFletCommandsAndEvents() {
    XCTAssertEqual(events("Canvas"), ["resize"])
    XCTAssertEqual(methods("Canvas"), ["capture", "clear_capture", "get_capture"])
    for type in ["BarChart", "CandlestickChart", "LineChart", "PieChart", "RadarChart",
                 "ScatterChart"] {
      XCTAssertEqual(events(type), ["event"], type)
    }
  }

  func testAnimationPluginsAreNativeViews() {
    for type in ["Lottie", "Rive", "RufletSpinKit"] {
      let descriptor = ControlRegistry.builtInDescriptor(for: type)
      XCTAssertEqual(descriptor?.classification, .visible)
      XCTAssertEqual(descriptor?.rendering, .nativeView)
    }
  }

  func testRiveClipRectUsesFlutterLTRBGeometry() {
    let clip = RufletRiveClipRect(.map([
      "left": .double(10), "top": .double(20),
      "right": .double(70), "bottom": .double(55),
    ]))
    XCTAssertEqual(clip?.rect, CGRect(x: 10, y: 20, width: 60, height: 35))
  }

  func testRiveRejectsIncompleteOrInvertedClipRects() {
    XCTAssertNil(RufletRiveClipRect(.map(["left": .double(1)])))
    XCTAssertNil(RufletRiveClipRect(.map([
      "left": .double(9), "top": .double(0),
      "right": .double(2), "bottom": .double(10),
    ])))
  }

  func testCanvasCaptureBufferReturnsFletBinaryAndClearsIt() {
    var capture = CanvasCaptureBuffer()
    XCTAssertEqual(capture.wireValue, .null)

    capture.store(Data([0x89, 0x50, 0x4E, 0x47]))
    XCTAssertEqual(capture.wireValue, .binary([0x89, 0x50, 0x4E, 0x47]))

    capture.clear()
    XCTAssertEqual(capture.wireValue, .null)
  }

  func testCanvasArcUsesFlutterRadiansInsteadOfDrawingAFullOval() {
    let arc = CanvasControlView.ellipticalArc(
      in: CGRect(x: 10, y: 20, width: 100, height: 60),
      startAngle: 0,
      sweepAngle: .pi / 2,
      useCenter: false)

    let bounds = arc.boundingRect
    XCTAssertEqual(bounds.minX, 60, accuracy: 0.001)
    XCTAssertEqual(bounds.maxX, 110, accuracy: 0.001)
    XCTAssertEqual(bounds.minY, 50, accuracy: 0.001)
    XCTAssertEqual(bounds.maxY, 80, accuracy: 0.001)
  }

  func testCanvasCenteredArcIncludesTheEllipseCenter() {
    let arc = CanvasControlView.ellipticalArc(
      in: CGRect(x: 10, y: 20, width: 100, height: 60),
      startAngle: .pi,
      sweepAngle: .pi / 2,
      useCenter: true)

    let bounds = arc.boundingRect
    XCTAssertEqual(bounds.minX, 10, accuracy: 0.001)
    XCTAssertEqual(bounds.maxX, 60, accuracy: 0.001)
    XCTAssertEqual(bounds.minY, 20, accuracy: 0.001)
    XCTAssertEqual(bounds.maxY, 50, accuracy: 0.001)
  }

  func testCanvasPathArcHonorsStartAndSweepAngles() {
    let path = CanvasControlView.path(from: [
      .map([
        "_type": .string("Arc"),
        "x": .double(0),
        "y": .double(0),
        "width": .double(80),
        "height": .double(40),
        "start_angle": .double(0),
        "sweep_angle": .double(.pi / 2),
      ])
    ])

    XCTAssertEqual(path.boundingRect.width, 40, accuracy: 0.001)
    XCTAssertEqual(path.boundingRect.height, 20, accuracy: 0.001)
  }

  private func events(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedEvents ?? []
  }

  private func methods(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedMethods ?? []
  }
}
