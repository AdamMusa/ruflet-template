import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class MapPluginParityTests: XCTestCase {
  func testMapDescriptorMatchesPinnedFletMethodsAndEvents() throws {
    let map = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "Map"))
    XCTAssertEqual(map.supportedMethods, [
      "center_on", "move_to", "reset_rotation", "rotate_from", "zoom_in",
      "zoom_out", "zoom_to",
    ])
    XCTAssertEqual(map.supportedEvents, [
      "event", "hover", "init", "long_press", "pointer_cancel", "pointer_down",
      "pointer_up", "position_change", "secondary_tap", "tap",
    ])
  }

  func testAttributionDescriptorsMatchPinnedFletChildEvents() throws {
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "SimpleAttribution"))
        .supportedEvents,
      ["click"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "TextSourceAttribution"))
        .supportedEvents,
      ["click"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "ImageSourceAttribution"))
        .supportedEvents,
      ["click"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "RichAttribution"))
        .supportedEvents,
      ["click"])
  }

  func testMapUsesPinnedFletCameraDefaults() {
    XCTAssertEqual(
      MapControlSemantics.initialCenter,
      .init(latitude: 50.5, longitude: 30.51))
    XCTAssertEqual(MapControlSemantics.initialZoom, 13)
    XCTAssertEqual(MapControlSemantics.initialRotation, 0)
    XCTAssertEqual(MapControlSemantics.animationDurationMilliseconds, 500)
    XCTAssertEqual(MapControlSemantics.backgroundColor, "grey300")
  }

  func testInteractionFlagsMatchFlutterMapBitContract() {
    typealias Flags = MapControlSemantics.InteractiveFlag
    XCTAssertEqual(Flags.all, 255)
    XCTAssertTrue(Flags.contains(Flags.drag, Flags.drag))
    XCTAssertFalse(Flags.contains(Flags.drag, Flags.rotate, Flags.pinchZoom))
    XCTAssertTrue(Flags.contains(Flags.all, Flags.rotate, Flags.scrollWheelZoom))
  }

  func testCoordinateParserMatchesFletMissingComponentFallbacks() {
    XCTAssertEqual(
      MapControlSemantics.coordinate(.map(["latitude": .double(12.5)])),
      .init(latitude: 12.5, longitude: 0))
    XCTAssertEqual(
      MapControlSemantics.coordinate(.map(["longitude": .double(-7.25)])),
      .init(latitude: 0, longitude: -7.25))
    XCTAssertNil(MapControlSemantics.coordinate(.string("not a LatLng")))
  }

  func testMoveToReadsPinnedNestedDestinationArgument() {
    let call = RufletMethodCall(
      controlID: 1, callID: "move", name: "move_to",
      args: .map([
        "destination": .map([
          "latitude": .double(37.3349), "longitude": .double(-122.009),
        ]),
      ]))
    XCTAssertEqual(
      MapControlSemantics.point(for: call, key: "destination"),
      .init(latitude: 37.3349, longitude: -122.009))
  }

  func testMapCameraEventMatchesPinnedWireShape() {
    XCTAssertEqual(
      MapControlSemantics.cameraEvent(
        source: "mapController", center: .init(latitude: 1, longitude: 2),
        zoom: 3, minZoom: 0, maxZoom: 18, rotation: 4),
      .map([
        "source": .string("mapController"),
        "camera": .map([
          "center": .map(["latitude": .double(1), "longitude": .double(2)]),
          "zoom": .double(3), "min_zoom": .double(0), "max_zoom": .double(18),
          "rotation": .double(4),
        ]),
      ]))
  }

  func testTileLayerUsesPinnedFletDefaultsAndTemplateResolution() {
    let defaults = MapTileConfiguration(node: ControlNode(id: 1, type: "TileLayer"))
    XCTAssertEqual(defaults.subdomains, ["a", "b", "c"])
    XCTAssertEqual(defaults.tileSize, 256)
    XCTAssertEqual(defaults.userAgent, "unknown")
    XCTAssertEqual(defaults.minNativeZoom, 0)
    XCTAssertEqual(defaults.maxNativeZoom, 19)
    XCTAssertFalse(defaults.zoomReverse)
    XCTAssertEqual(defaults.zoomOffset, 0)
    XCTAssertFalse(defaults.tms)
    XCTAssertEqual(defaults.displayOpacity, 0)
    XCTAssertEqual(defaults.displayDuration, 0.1)

    let configured = MapTileConfiguration(node: ControlNode(
      id: 2, type: "TileLayer", props: [
        "url_template": .string("https://{s}.test/{z}/{x}/{y}{r}?d={d}&key={token}"),
        "subdomains": .array([.string("x")]),
        "enable_retina_mode": .bool(true),
        "tile_size": .int(512),
        "additional_options": .map(["token": .string("ruby")]),
      ]))
    XCTAssertEqual(
      configured.url(pathX: 3, y: 4, z: 5)?.absoluteString,
      "https://x.test/5/3/4@2x?d=512&key=ruby")
  }

  func testTileLayerTmsAndReverseZoomMatchFlutterMapContract() {
    let configured = MapTileConfiguration(node: ControlNode(
      id: 3, type: "TileLayer", props: [
        "url_template": .string("https://tiles.test/{z}/{y}"),
        "enable_tms": .bool(true),
        "zoom_reverse": .bool(true),
        "max_zoom": .double(10),
        "zoom_offset": .double(1),
      ]))
    XCTAssertEqual(
      configured.url(pathX: 0, y: 2, z: 4)?.absoluteString,
      "https://tiles.test/7/125")
  }

  func testTileBoundsAndDisplayModeUseFlutterMapSemantics() {
    let configured = MapTileConfiguration(node: ControlNode(
      id: 4, type: "TileLayer", props: [
        "tile_bounds": .map([
          "corner_1": .map(["latitude": .double(-10), "longitude": .double(-10)]),
          "corner_2": .map(["latitude": .double(10), "longitude": .double(10)]),
        ]),
        "display_mode": .map([
          "_type": .string("instantaneous"), "opacity": .double(0.7),
        ]),
      ]))
    XCTAssertTrue(configured.contains(pathX: 0, y: 0, z: 0))
    XCTAssertFalse(configured.contains(pathX: 0, y: 0, z: 1))
    XCTAssertEqual(configured.displayOpacity, 0.7)
    XCTAssertEqual(configured.displayDuration, 0)
  }
}
