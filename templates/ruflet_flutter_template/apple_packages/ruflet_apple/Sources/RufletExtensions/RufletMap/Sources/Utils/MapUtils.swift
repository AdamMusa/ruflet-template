import CoreLocation
import MapKit
import RufletEngine
import RufletProtocol
import SwiftUI

struct RufletMapCoordinate: Equatable {
  let latitude: CLLocationDegrees
  let longitude: CLLocationDegrees

  var mapKit: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
  var value: RufletValue {
    .map(["latitude": .double(latitude), "longitude": .double(longitude)])
  }
}

struct RufletMapBounds {
  let first: RufletMapCoordinate
  let second: RufletMapCoordinate

  var mapRect: MKMapRect {
    let one = MKMapPoint(first.mapKit)
    let two = MKMapPoint(second.mapKit)
    return MKMapRect(
      x: min(one.x, two.x), y: min(one.y, two.y),
      width: max(abs(one.x - two.x), 1), height: max(abs(one.y - two.y), 1))
  }
}

enum RufletStrokePattern: Equatable {
  case solid
  case dotted(spacingFactor: Double)
  case dashed([Double])

  var dashPattern: [NSNumber]? {
    switch self {
    case .solid: nil
    case .dotted(let spacing): [0, NSNumber(value: max(spacing, 0.1))]
    case .dashed(let segments): segments.map(NSNumber.init(value:))
    }
  }
}

struct RufletTileDisplay {
  let initialOpacity: Double
  let duration: TimeInterval
}

struct RufletMapInteraction {
  let scrollEnabled: Bool
  let zoomEnabled: Bool
  let rotateEnabled: Bool
  let pitchEnabled: Bool

  static let all = RufletMapInteraction(
    scrollEnabled: true, zoomEnabled: true, rotateEnabled: true, pitchEnabled: true)
}

func rufletStringMap(_ value: RufletValue?) -> [String: RufletValue]? {
  guard let value else { return nil }
  switch value {
  case .map(let result): return result
  case .keyedMap(let result):
    var mapped: [String: RufletValue] = [:]
    for (key, item) in result {
      guard case .string(let key) = key else { continue }
      mapped[key] = item
    }
    return mapped
  default: return nil
  }
}

func rufletMapCoordinate(_ value: RufletValue?, default defaultValue: RufletMapCoordinate? = nil) -> RufletMapCoordinate? {
  guard let map = rufletStringMap(value) else { return defaultValue }
  return RufletMapCoordinate(
    latitude: map["latitude"]?.number ?? 0,
    longitude: map["longitude"]?.number ?? 0)
}

func rufletMapCoordinates(_ value: RufletValue?) -> [RufletMapCoordinate] {
  value?.array?.compactMap { rufletMapCoordinate($0) } ?? []
}

func rufletMapBounds(_ value: RufletValue?) -> RufletMapBounds? {
  guard let map = rufletStringMap(value),
        let first = rufletMapCoordinate(map["corner_1"]),
        let second = rufletMapCoordinate(map["corner_2"])
  else { return nil }
  return RufletMapBounds(first: first, second: second)
}

func rufletStrokePattern(_ value: RufletValue?) -> RufletStrokePattern {
  guard let map = rufletStringMap(value) else { return .solid }
  switch map["_type"]?.text?.lowercased() {
  case "dotted": return .dotted(spacingFactor: map["spacing_factor"]?.number ?? 1.5)
  case "dashed": return .dashed(map["segments"]?.array?.compactMap(\.number) ?? [])
  default: return .solid
  }
}

func rufletTileDisplay(_ value: RufletValue?) -> RufletTileDisplay {
  guard let map = rufletStringMap(value) else {
    return RufletTileDisplay(initialOpacity: 0, duration: 0.1)
  }
  switch map["_type"]?.text?.lowercased() {
  case "instantaneous":
    return RufletTileDisplay(initialOpacity: map["opacity"]?.number ?? 1, duration: 0)
  default:
    return RufletTileDisplay(
      initialOpacity: map["start_opacity"]?.number ?? 1,
      duration: (map["duration"]?.number ?? 100) / 1_000)
  }
}

func rufletMapInteraction(_ value: RufletValue?) -> RufletMapInteraction {
  guard let flags = rufletStringMap(value)?["flags"]?.integer else { return .all }
  // flutter_map InteractiveFlag values: drag 1, pinchMove 4, pinchZoom 8,
  // doubleTapZoom 16, scrollWheelZoom 64, rotate 128.
  return RufletMapInteraction(
    scrollEnabled: flags & (1 | 4) != 0,
    zoomEnabled: flags & (8 | 16 | 32 | 64) != 0,
    rotateEnabled: flags & 128 != 0,
    pitchEnabled: false)
}

func rufletMapColor(_ value: String?, default defaultColor: Color) -> Color {
  parseColor(value, defaultColor) ?? defaultColor
}

#if os(iOS)
typealias RufletPlatformColor = UIColor
func rufletPlatformColor(_ color: Color) -> UIColor { UIColor(color) }
#elseif os(macOS)
typealias RufletPlatformColor = NSColor
func rufletPlatformColor(_ color: Color) -> NSColor { NSColor(color) }
#endif

func rufletZoomLevel(for region: MKCoordinateRegion) -> Double {
  log2(360 / max(region.span.longitudeDelta, 0.000_001))
}

func rufletRegion(center: CLLocationCoordinate2D, zoom: Double) -> MKCoordinateRegion {
  let longitudeDelta = 360 / pow(2, max(zoom, 0))
  return MKCoordinateRegion(
    center: center,
    span: MKCoordinateSpan(
      latitudeDelta: min(longitudeDelta, 180), longitudeDelta: min(longitudeDelta, 360)))
}

func rufletCameraValue(_ mapView: MKMapView) -> RufletValue {
  .map([
    "center": RufletMapCoordinate(
      latitude: mapView.centerCoordinate.latitude,
      longitude: mapView.centerCoordinate.longitude).value,
    "zoom": .double(rufletZoomLevel(for: mapView.region)),
    "min_zoom": .double(mapView.cameraZoomRange?.minCenterCoordinateDistance ?? 0),
    "max_zoom": .double(mapView.cameraZoomRange?.maxCenterCoordinateDistance ?? 0),
    "rotation": .double(mapView.camera.heading),
  ])
}

func rufletPointValue(_ point: CGPoint, coordinate: CLLocationCoordinate2D) -> RufletValue {
  .map([
    "coordinates": RufletMapCoordinate(
      latitude: coordinate.latitude, longitude: coordinate.longitude).value,
    "gx": .double(point.x), "gy": .double(point.y),
    "lx": .double(point.x), "ly": .double(point.y),
  ])
}

func rufletLineCap(_ value: String?) -> CGLineCap {
  switch value?.lowercased() {
  case "butt": .butt
  case "square": .square
  default: .round
  }
}

func rufletLineJoin(_ value: String?) -> CGLineJoin {
  switch value?.lowercased() {
  case "bevel": .bevel
  case "miter": .miter
  default: .round
  }
}
