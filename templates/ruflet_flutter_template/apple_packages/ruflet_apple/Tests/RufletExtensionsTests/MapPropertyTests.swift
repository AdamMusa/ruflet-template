import Foundation
import RufletEngine
@testable import RufletMap
import RufletProtocol
import XCTest

@MainActor
final class MapPropertyTests: XCTestCase {
  func testPolygonLayerPropagatesPinnedRendererConfiguration() throws {
    let layer = makeControl(id: 1, type: "PolygonLayer", properties: [
      "polygon_culling": .bool(false),
      "polygon_labels": .bool(false),
      "draw_labels_last": .bool(true),
      "simplification_tolerance": .double(1.25),
      "use_alternative_rendering": .bool(true),
      "polygons": .array([
        controlValue(id: 2, type: "PolygonMarker", properties: [
          "coordinates": coordinates([(1, 2), (3, 4), (5, 6)]),
        ]),
      ]),
    ])

    let polygon = try XCTUnwrap(rufletPolygonDescriptors(layer).first)
    XCTAssertFalse(polygon.polygonCulling)
    XCTAssertFalse(polygon.polygonLabels)
    XCTAssertTrue(polygon.drawLabelsLast)
    XCTAssertEqual(polygon.simplificationTolerance, 1.25)
    XCTAssertTrue(polygon.useAlternativeRendering)
    XCTAssertTrue(polygon.control.notifyParent)
  }

  func testPolylineLayerPropagatesPinnedCullingAndSimplification() throws {
    let layer = makeControl(id: 1, type: "PolylineLayer", properties: [
      "culling_margin": .double(18),
      "min_hittable_radius": .double(12),
      "simplification_tolerance": .double(0.75),
      "polylines": .array([
        controlValue(id: 2, type: "PolylineMarker", properties: [
          "coordinates": coordinates([(1, 2), (3, 4)]),
        ]),
      ]),
    ])

    let polyline = try XCTUnwrap(rufletPolylineDescriptors(layer).first)
    XCTAssertEqual(polyline.cullingMargin, 18)
    XCTAssertEqual(polyline.minimumHittableRadius, 12)
    XCTAssertEqual(polyline.simplificationTolerance, 0.75)
    XCTAssertTrue(polyline.control.notifyParent)
  }

  func testTileLayerBufferAgentAndEvictionDefaultsMatchPinnedFlutterMap() {
    let defaults = rufletTileDescriptor(makeControl(id: 1, type: "TileLayer"))
    XCTAssertEqual(defaults.userAgentPackageName, "unknown")
    XCTAssertEqual(defaults.keepBuffer, 2)
    XCTAssertEqual(defaults.panBuffer, 1)
    XCTAssertEqual(defaults.evictErrorTileStrategy, "none")

    let configured = rufletTileDescriptor(makeControl(id: 2, type: "TileLayer", properties: [
      "user_agent_package_name": .string("com.example.maps"),
      "keep_buffer": .int(5),
      "pan_buffer": .int(3),
      "evict_error_tile_strategy": .string("notVisibleRespectMargin"),
    ]))
    XCTAssertEqual(configured.userAgentPackageName, "com.example.maps")
    XCTAssertEqual(configured.keepBuffer, 5)
    XCTAssertEqual(configured.panBuffer, 3)
    XCTAssertEqual(configured.evictErrorTileStrategy, "notVisibleRespectMargin")
  }

  private func makeControl(
    id: Int,
    type: String,
    properties: [String: RufletValue] = [:]
  ) -> RufletControl {
    RufletControl(
      id: id, type: type, properties: properties,
      backend: MapPropertyTestBackend())
  }

  private func controlValue(
    id: Int,
    type: String,
    properties: [String: RufletValue]
  ) -> RufletValue {
    .map(properties.merging([
      "_c": .string(type), "_i": .int(Int64(id)),
    ]) { current, _ in current })
  }

  private func coordinates(_ values: [(Double, Double)]) -> RufletValue {
    .array(values.map { latitude, longitude in
      .map(["latitude": .double(latitude), "longitude": .double(longitude)])
    })
  }
}

@MainActor
private final class MapPropertyTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ value: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
