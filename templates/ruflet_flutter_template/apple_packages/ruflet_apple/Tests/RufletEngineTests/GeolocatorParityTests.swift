import Foundation
import RufletEngine
@testable import RufletGeolocator
import RufletProtocol
import XCTest

final class GeolocatorParityTests: XCTestCase {
  func testPinnedAppleSettingsDefaultsAndExplicitValues() {
    let defaults = FletGeolocatorSemantics.settings(nil)
    XCTAssertEqual(defaults.accuracy, .best)
    XCTAssertEqual(defaults.distanceFilter, 0)
    XCTAssertNil(defaults.timeLimitSeconds)
    XCTAssertEqual(defaults.activityType, .other)
    XCTAssertFalse(defaults.pauseLocationUpdatesAutomatically)
    XCTAssertFalse(defaults.showBackgroundLocationIndicator)
    XCTAssertTrue(defaults.allowBackgroundLocationUpdates)

    let values = FletGeolocatorSemantics.settings(.map([
      "accuracy": .string("bestForNavigation"),
      "distance_filter": .int(25),
      "time_limit": .extended(type: 3, string: "2500000"),
      "activity_type": .string("automotiveNavigation"),
      "pause_location_updates_automatically": .bool(true),
      "show_background_location_indicator": .bool(true),
      "allow_background_location_updates": .bool(false),
    ]))
    XCTAssertEqual(values.accuracy, .bestForNavigation)
    XCTAssertEqual(values.distanceFilter, 25)
    XCTAssertEqual(values.timeLimitSeconds, 2.5)
    XCTAssertEqual(values.activityType, .automotiveNavigation)
    XCTAssertTrue(values.pauseLocationUpdatesAutomatically)
    XCTAssertTrue(values.showBackgroundLocationIndicator)
    XCTAssertFalse(values.allowBackgroundLocationUpdates)
  }

  func testUnknownAccuracyAndActivityUseFletDefaults() {
    let settings = FletGeolocatorSemantics.settings(.map([
      "accuracy": .string("impossible"),
      "activity_type": .string("impossible"),
    ]))
    XCTAssertEqual(settings.accuracy, .best)
    XCTAssertEqual(settings.activityType, .other)
  }

  func testPermissionNamesMatchGeolocatorEnum() {
    XCTAssertEqual(FletGeolocatorSemantics.permissionName(index: 0), "denied")
    XCTAssertEqual(FletGeolocatorSemantics.permissionName(index: 1), "denied_forever")
    XCTAssertEqual(FletGeolocatorSemantics.permissionName(index: 2), "while_in_use")
    XCTAssertEqual(FletGeolocatorSemantics.permissionName(index: 3), "always")
  }

  func testPositionContainsEveryFletPositionExtensionField() {
    let position = FletGeolocatorSemantics.position(
      latitude: 40.7,
      longitude: -74,
      accuracy: 3,
      altitude: 12,
      altitudeAccuracy: 4,
      heading: 90,
      headingAccuracy: 2,
      speed: 5,
      speedAccuracy: 0.5,
      floor: 7,
      mocked: true,
      timestamp: Date(timeIntervalSince1970: 1_704_067_200.25))
    XCTAssertEqual(position, .map([
      "latitude": .double(40.7),
      "longitude": .double(-74),
      "speed": .double(5),
      "altitude": .double(12),
      "timestamp": .extended(
        type: 1, string: "2024-01-01T00:00:00.250000+00:00"),
      "accuracy": .double(3),
      "altitude_accuracy": .double(4),
      "heading": .double(90),
      "heading_accuracy": .double(2),
      "speed_accuracy": .double(0.5),
      "floor": .int(7),
      "mocked": .bool(true),
    ]))
  }

  func testPositionChangeAndNullableFloorMatchFletEventShape() {
    let position = FletGeolocatorSemantics.position(
      latitude: 0, longitude: 0, accuracy: 0,
      altitude: 0, altitudeAccuracy: 0,
      heading: 0, headingAccuracy: 0,
      speed: 0, speedAccuracy: 0,
      floor: nil, mocked: false, timestamp: Date(timeIntervalSince1970: 0))
    XCTAssertEqual(position.mapValue?["floor"], .null)
    XCTAssertEqual(
      FletGeolocatorSemantics.positionChange(position),
      .map(["position": position]))
  }

  @MainActor
  func testGeolocatorIsAnActivatedStreamingExtension() {
    let registry = ServiceRegistry()
    RufletGeolocator.register(in: registry)
    XCTAssertTrue(registry.handles("Geolocator"))
    XCTAssertTrue(
      registry.service(for: ControlNode(id: 8, type: "Geolocator"))
        is any RufletStreamingService)
  }

  @MainActor
  func testDistanceRequiresAllFourFletArguments() throws {
    let service = GeolocatorService()
    let context = RufletServiceContext(
      store: ControlStore(), emitEvent: { _, _, _ in })
    var missing: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(
        controlID: 1, callID: "missing", name: "distance_between",
        args: .map(["start_latitude": .double(40)])),
      node: ControlNode(id: 1, type: "Geolocator"),
      context: context
    ) { missing = $0 }
    XCTAssertEqual(try missing?.get(), .null)

    var distance: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(
        controlID: 1, callID: "distance", name: "distance_between",
        args: .map([
          "start_latitude": .double(40.7128),
          "start_longitude": .double(-74.0060),
          "end_latitude": .double(40.7138),
          "end_longitude": .double(-74.0060),
        ])),
      node: ControlNode(id: 1, type: "Geolocator"),
      context: context
    ) { distance = $0 }
    XCTAssertGreaterThan(try XCTUnwrap(distance?.get().doubleValue), 100)
  }
}
