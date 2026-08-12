import RufletEngine
import RufletProtocol
@testable import RufletMap
import XCTest

final class MapResidualParityTests: XCTestCase {
  func testEventsAreEnabledOnlyByTheirPinnedOnProperty() {
    let defaults = ControlNode(id: 1, type: "Map")
    for event in [
      "init", "tap", "hover", "secondary_tap", "long_press", "event",
      "position_change", "pointer_down", "pointer_cancel", "pointer_up",
    ] {
      XCTAssertFalse(MapControlSemantics.eventEnabled(event, node: defaults), event)
    }

    let subscribed = ControlNode(
      id: 2, type: "Map",
      props: [
        "on_tap": .bool(true), "on_position_change": .bool(true),
        "on_event": .bool(true),
      ])
    XCTAssertTrue(MapControlSemantics.eventEnabled("tap", node: subscribed))
    XCTAssertTrue(MapControlSemantics.eventEnabled("position_change", node: subscribed))
    XCTAssertTrue(MapControlSemantics.eventEnabled("event", node: subscribed))
    XCTAssertFalse(MapControlSemantics.eventEnabled("hover", node: subscribed))
  }

  func testMethodOptionsParseDurationCurveAndCancellationLikeFlet() {
    let node = ControlNode(
      id: 1, type: "Map",
      props: [
        "animation_duration": .map([
          "seconds": .int(1), "milliseconds": .int(250),
        ]),
        "animation_curve": .string("fastOutSlowIn"),
      ])
    let defaults = MapControlSemantics.methodOptions(
      RufletMethodCall(controlID: 1, callID: "a", name: "zoom_in", args: .map([:])),
      node: node)
    XCTAssertEqual(defaults.duration, 1.25)
    XCTAssertEqual(defaults.curve, "easeinout")
    XCTAssertFalse(defaults.cancelOngoingAnimations)

    let overridden = MapControlSemantics.methodOptions(
      RufletMethodCall(
        controlID: 1, callID: "b", name: "zoom_in",
        args: .map([
          "duration": .extended(type: 3, string: "750000"),
          "curve": .string("ease_out_cubic"),
          "cancel_ongoing_animations": .bool(true),
        ])), node: node)
    XCTAssertEqual(overridden.duration, 0.75)
    XCTAssertEqual(overridden.curve, "easeout")
    XCTAssertTrue(overridden.cancelOngoingAnimations)
  }

  func testDurationParserUsesIntegerMillisecondsAndDurationMaps() {
    XCTAssertEqual(MapControlSemantics.durationSeconds(.int(500)), 0.5)
    XCTAssertEqual(MapControlSemantics.durationSeconds(.string("250")), 0.25)
    XCTAssertEqual(MapControlSemantics.durationSeconds(.double(12.5)), 0)
    XCTAssertEqual(
      MapControlSemantics.durationSeconds(.map([
        "minutes": .int(1), "seconds": .int(2), "milliseconds": .int(3),
        "microseconds": .int(4),
      ])),
      62.003004,
      accuracy: 0.000_000_1)
    XCTAssertEqual(MapControlSemantics.durationSeconds(nil, defaultMilliseconds: 500), 0.5)
  }

  func testOneSidedAndTwoSidedMapZoomLimitsClampCorrectly() {
    XCTAssertEqual(
      MapControlSemantics.clampedZoom(
        2, node: ControlNode(id: 1, type: "Map", props: ["min_zoom": .double(5)])),
      5)
    XCTAssertEqual(
      MapControlSemantics.clampedZoom(
        20, node: ControlNode(id: 1, type: "Map", props: ["max_zoom": .double(15)])),
      15)
    XCTAssertEqual(
      MapControlSemantics.clampedZoom(
        20,
        node: ControlNode(
          id: 1, type: "Map",
          props: ["min_zoom": .double(5), "max_zoom": .double(15)])),
      15)
  }

  func testTapAndPointerEventWireShapesStayDistinct() {
    let coordinate = MapControlSemantics.Coordinate(latitude: 12, longitude: -7)
    XCTAssertEqual(
      MapControlSemantics.tapEvent(
        coordinate: coordinate, globalX: 1, globalY: 2, localX: 3, localY: 4),
      .map([
        "coordinates": coordinate.value,
        "gx": .double(1), "gy": .double(2), "lx": .double(3), "ly": .double(4),
      ]))

    let pointer = MapControlSemantics.pointerEvent(
      coordinate: coordinate, kind: "mouse", globalX: 1, globalY: 2,
      localX: 3, localY: 4, timestampMicroseconds: 5)
    XCTAssertEqual(pointer["coordinates"], coordinate.value)
    XCTAssertEqual(pointer["k"], .string("mouse"))
    XCTAssertEqual(pointer["g"], .map(["x": .double(1), "y": .double(2)]))
    XCTAssertEqual(pointer["l"], .map(["x": .double(3), "y": .double(4)]))
    XCTAssertEqual(pointer["ts"], .extended(type: 3, string: "5"))
    XCTAssertEqual(pointer["ld"], .map(["x": .null, "y": .null]))
    XCTAssertNil(pointer["gx"], "PointerEvent uses Flet's nested g/l shape, not TapPosition")
  }

  func testCameraWireShapeRetainsNullableZoomBounds() {
    XCTAssertEqual(
      MapControlSemantics.Camera(
        center: .init(latitude: 1, longitude: 2), zoom: 3,
        minZoom: nil, maxZoom: nil, rotation: 4
      ).value,
      .map([
        "center": .map(["latitude": .double(1), "longitude": .double(2)]),
        "zoom": .double(3), "min_zoom": .null, "max_zoom": .null,
        "rotation": .double(4),
      ]))
  }

  func testTileResidualDefaultsAndReplacementPrecedence() {
    let defaults = MapTileConfiguration(node: ControlNode(id: 1, type: "TileLayer"))
    XCTAssertEqual(defaults.httpUserAgent, "flutter_map (unknown)")
    XCTAssertTrue(defaults.allowsMemoryCache)

    let configured = MapTileConfiguration(node: ControlNode(
      id: 2, type: "TileLayer",
      props: [
        "url_template": .string("https://tiles.test/{z}/{x}/{r}"),
        "fallback_url": .string("https://fallback.test/{z}/{x}"),
        "enable_retina_mode": .bool(true),
        "user_agent_package_name": .string("Ruflet/1"),
        "additional_options": .map(["x": .string("override"), "r": .string("@3x")]),
        "display_mode": .map([
          "_type": .string("fadein"),
          "duration": .map(["milliseconds": .int(275)]),
        ]),
      ]))
    XCTAssertEqual(
      configured.url(pathX: 3, y: 4, z: 5)?.absoluteString,
      "https://tiles.test/5/override/@3x")
    XCTAssertEqual(configured.displayDuration, 0.275)
    XCTAssertEqual(configured.httpUserAgent, "flutter_map (Ruflet/1)")
    XCTAssertFalse(configured.allowsMemoryCache)
  }
}
