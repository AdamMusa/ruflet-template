@testable import RufletUI
@testable import RufletRive
@testable import RufletLottie
import RufletEngine
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

  func testAnimationPluginsHaveTheSameOptionalPackageBoundaryAsFlet() {
    for (type, bundle) in [("Lottie", "RufletLottie"), ("Rive", "RufletRive")] {
      let descriptor = ControlRegistry.builtInDescriptor(for: type)
      XCTAssertEqual(descriptor?.classification, .visible)
      XCTAssertEqual(descriptor?.rendering, .optionalBundle(bundle))
    }
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "RufletSpinKit")?.rendering,
      .optionalBundle("RufletSpinKit"))
  }

  @MainActor
  func testAnimationPluginBundlesInstallTheirNativeViewsInIsolation() {
    let services = ServiceRegistry()
    RufletRive.register(in: services)
    XCTAssertEqual(ControlRegistry.descriptor(for: "Rive")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Rive")?.implementation,
      "RufletRive.RiveControlView")

    RufletLottie.register(in: services)
    XCTAssertEqual(ControlRegistry.descriptor(for: "Lottie")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Lottie")?.supportedEvents,
      ["error", "load"])
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

  func testRivePointerCoordinatesHonorFlutterFitAndAlignment() {
    let centered = RiveControlSemantics.artboardLocation(
      CGPoint(x: 100, y: 50),
      container: CGSize(width: 200, height: 100),
      artboard: CGRect(x: 0, y: 0, width: 100, height: 100),
      fit: .contain,
      alignment: .center)
    XCTAssertEqual(centered.x, 50, accuracy: 0.001)
    XCTAssertEqual(centered.y, 50, accuracy: 0.001)

    let bottomRight = RiveControlSemantics.artboardLocation(
      CGPoint(x: 100, y: 50),
      container: CGSize(width: 200, height: 100),
      artboard: CGRect(x: 10, y: 20, width: 100, height: 50),
      fit: .noFit,
      alignment: .bottomRight)
    XCTAssertEqual(bottomRight.x, 10, accuracy: 0.001)
    XCTAssertEqual(bottomRight.y, 20, accuracy: 0.001)
  }

  func testLottieReverseMatchesPinnedFlutterBehavior() {
    XCTAssertEqual(LottieControlSemantics.loopMode(repeat: true, reverse: false), .loop)
    XCTAssertEqual(LottieControlSemantics.loopMode(repeat: true, reverse: true), .autoReverse)
    // Pinned Flet docs: reverse has no effect unless repeat is enabled.
    XCTAssertEqual(LottieControlSemantics.loopMode(repeat: false, reverse: true), .playOnce)
  }

  func testLottieImplementsEveryFlutterBoxFitAndAlignment() {
    let intrinsic = CGSize(width: 100, height: 50)
    let container = CGSize(width: 200, height: 200)
    XCTAssertEqual(
      LottieControlSemantics.layout(
        intrinsic: intrinsic, container: container, fit: "fill", alignment: "center").size,
      container)
    XCTAssertEqual(
      LottieControlSemantics.layout(
        intrinsic: intrinsic, container: container, fit: "fit_width", alignment: "center").size,
      CGSize(width: 200, height: 100))
    XCTAssertEqual(
      LottieControlSemantics.layout(
        intrinsic: intrinsic, container: container, fit: "fit_height", alignment: "center").size,
      CGSize(width: 400, height: 200))
    XCTAssertEqual(
      LottieControlSemantics.layout(
        intrinsic: intrinsic, container: container, fit: "none", alignment: "bottom_right"),
      LottieControlSemantics.Layout(
        origin: CGPoint(x: 100, y: 150), size: intrinsic))
    XCTAssertEqual(
      LottieControlSemantics.layout(
        intrinsic: CGSize(width: 400, height: 100),
        container: container,
        fit: "scale_down",
        alignment: "top_left"),
      LottieControlSemantics.Layout(
        origin: .zero, size: CGSize(width: 200, height: 50)))
  }

  func testLottieMapsFlutterFilterQualityAndClassifiesRuntimeOptions() {
    XCTAssertEqual(LottieControlSemantics.layerFilter("none"), .nearest)
    XCTAssertEqual(LottieControlSemantics.layerFilter("low"), .linear)
    XCTAssertEqual(LottieControlSemantics.layerFilter("medium"), .trilinear)
    XCTAssertEqual(LottieControlSemantics.layerFilter("high"), .linear)
    XCTAssertEqual(LottieControlSemantics.mergePathsSupport, .nativeRuntimeAlwaysOn)
    XCTAssertEqual(LottieControlSemantics.applyingLayerOpacitySupport, .nativeRuntimeAlwaysOn)
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

  func testCanvasPaintUsesFlutterPaintDefaults() {
    let paint = CanvasPaint(nil)
    XCTAssertEqual(paint.style, "fill")
    XCTAssertEqual(paint.strokeWidth, 0) // Flutter/CoreGraphics device-space hairline.
    XCTAssertEqual(paint.strokeCap, .butt)
    XCTAssertEqual(paint.strokeJoin, .miter)
    XCTAssertEqual(paint.strokeMiterLimit, 4)
    XCTAssertTrue(paint.dash.isEmpty)
    XCTAssertTrue(paint.antiAlias)
  }

  func testCanvasArcToUsesEndpointRadiusInsteadOfDegenerateTangentArc() {
    let path = CanvasControlView.path(from: [
      .map(["_type": .string("MoveTo"), "x": .double(0), "y": .double(0)]),
      .map([
        "_type": .string("ArcTo"), "x": .double(100), "y": .double(0),
        "radius": .double(50), "clockwise": .bool(true), "large_arc": .bool(false),
      ]),
    ])
    XCTAssertEqual(path.boundingRect.width, 100, accuracy: 0.001)
    XCTAssertEqual(path.boundingRect.height, 50, accuracy: 0.001)
  }

  func testCanvasConicQuadraticHonorsWeight() {
    let weighted = CanvasControlView.path(from: [
      .map(["_type": .string("MoveTo"), "x": .double(0), "y": .double(0)]),
      .map([
        "_type": .string("QuadraticTo"), "cp1x": .double(50), "cp1y": .double(100),
        "x": .double(100), "y": .double(0), "w": .double(0.25),
      ]),
    ])
    XCTAssertEqual(weighted.boundingRect.width, 100, accuracy: 0.001)
    XCTAssertGreaterThan(weighted.boundingRect.height, 0)
    XCTAssertLessThan(weighted.boundingRect.height, 50)
  }

  func testCanvasPaintConsumesStrokeAndBlendPropertiesCentrally() {
    let paint = CanvasPaint([
      "style": .string("stroke"),
      "stroke_width": .double(3),
      "stroke_cap": .string("round"),
      "stroke_join": .string("bevel"),
      "stroke_miter_limit": .double(7),
      "stroke_dash_pattern": .array([.double(2), .double(5)]),
      "anti_alias": .bool(false),
      "blend_mode": .string("multiply"),
    ])
    XCTAssertEqual(paint.style, "stroke")
    XCTAssertEqual(paint.strokeWidth, 3)
    XCTAssertEqual(paint.strokeCap, .round)
    XCTAssertEqual(paint.strokeJoin, .bevel)
    XCTAssertEqual(paint.strokeMiterLimit, 7)
    XCTAssertEqual(paint.dash, [2, 5])
    XCTAssertFalse(paint.antiAlias)
    XCTAssertEqual(paint.blendModeName, "multiply")
  }

  func testCanvasPaintConsumesFletGradientAndBlurImage() {
    let gradient: RufletValue = .map([
      "_type": .string("radial"),
      "colors": .array([.string("red"), .string("blue")]),
      "radius": .double(24),
    ])
    let paint = CanvasPaint([
      "gradient": gradient,
      "blur_image": .map(["sigma_x": .double(3), "sigma_y": .double(5)]),
    ])
    XCTAssertEqual(paint.gradient, gradient)
    XCTAssertEqual(paint.blurSigmaX, 3)
    XCTAssertEqual(paint.blurSigmaY, 5)
  }

  func testCanvasCapturePreservesLogicalSizeUntilCleared() {
    var capture = CanvasCaptureBuffer()
    capture.store(Data([0x89, 0x50]), logicalSize: CGSize(width: 320, height: 180))
    XCTAssertEqual(capture.logicalSize, CGSize(width: 320, height: 180))
    XCTAssertEqual(capture.wireValue, .binary([0x89, 0x50]))

    capture.clear()
    XCTAssertNil(capture.logicalSize)
    XCTAssertEqual(capture.wireValue, .null)
  }

  func testChartDefaultsAreSharedAcrossFamilies() {
    XCTAssertEqual(ChartControlSemantics.unboundedHeight, 300)
    let scatter = ControlNode(id: 1, type: "ScatterChart", props: [
      "rotation_quarter_turns": .int(3), "on_event": .bool(true),
    ])
    XCTAssertEqual(ChartControlSemantics.rotationDegrees(for: scatter), 270)
    XCTAssertTrue(ChartControlSemantics.shouldEmitEvent(for: scatter))

    let disabled = ControlNode(id: 2, type: "RadarChart", props: [
      "on_event": .bool(true), "disabled": .bool(true),
    ])
    XCTAssertFalse(ChartControlSemantics.shouldEmitEvent(for: disabled))

    let nonInteractive = ControlNode(id: 3, type: "BarChart", props: [
      "on_event": .bool(true), "interactive": .bool(false),
    ])
    XCTAssertFalse(ChartControlSemantics.shouldEmitEvent(for: nonInteractive))

    let pie = ControlNode(id: 4, type: "PieChart", props: [
      "on_event": .bool(true), "interactive": .bool(false),
    ])
    XCTAssertTrue(ChartControlSemantics.shouldEmitEvent(for: pie))

    XCTAssertEqual(ChartControlSemantics.animationDuration(for: pie), 0.15)
    XCTAssertEqual(ChartControlSemantics.animationCurve(for: pie), "linear")
  }

  func testChartAnimationAxisTooltipAndAlignmentUseFletDefaults() {
    let chart = ControlNode(id: 1, type: "LineChart", props: [
      "animation": .map(["duration": .double(420), "curve": .string("ease_in")]),
    ])
    XCTAssertEqual(ChartControlSemantics.animationDuration(for: chart), 0.42)
    XCTAssertEqual(ChartControlSemantics.animationCurve(for: chart), "ease_in")

    let axis = ControlNode(id: 2, type: "ChartAxis", props: [:])
    let defaults = ChartControlSemantics.axisDefaults(axis)
    XCTAssertTrue(defaults.showLabels)
    XCTAssertEqual(defaults.titleSize, 16)
    XCTAssertEqual(defaults.labelSize, 22)
    XCTAssertTrue(defaults.showMin)
    XCTAssertTrue(defaults.showMax)

    let tooltip = ChartControlSemantics.tooltipDefaults(nil)
    XCTAssertEqual(tooltip.margin, 16)
    XCTAssertEqual(tooltip.maxWidth, 120)
    XCTAssertEqual(tooltip.rotation, 0)
    XCTAssertFalse(tooltip.fitHorizontal)
    XCTAssertFalse(tooltip.fitVertical)

    XCTAssertEqual(
      ChartControlSemantics.groupCenters(count: 3, in: 0...120, alignment: "space_between"),
      [0, 60, 120])
    XCTAssertEqual(
      ChartControlSemantics.groupCenters(count: 3, in: 0...120, alignment: "space_around"),
      [20, 60, 100])
    XCTAssertEqual(
      ChartControlSemantics.nearestIndex(to: 7.9, values: [1, 8, 20]),
      1)
  }

  func testRadarShapeSupportsFletPolygonAndCircleModes() {
    let polygon = ChartControlSemantics.radarPolygon(
      center: CGPoint(x: 50, y: 50), radius: 25, sides: 4, circular: false)
    let circle = ChartControlSemantics.radarPolygon(
      center: CGPoint(x: 50, y: 50), radius: 25, sides: 4, circular: true)
    XCTAssertEqual(polygon.boundingRect, CGRect(x: 25, y: 25, width: 50, height: 50))
    XCTAssertEqual(circle.boundingRect, CGRect(x: 25, y: 25, width: 50, height: 50))
  }

  private func events(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedEvents ?? []
  }

  private func methods(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedMethods ?? []
  }
}
