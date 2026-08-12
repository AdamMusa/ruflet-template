import Foundation
import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(MapKit)
  import MapKit
#endif
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Source-defined semantics shared by the MapKit bridge and focused parity tests.
/// The values here come from the pinned `flet_map` Dart controls; they are not
/// presentation constants for Ruflet Explorer.
struct MapControlSemantics {
  struct Coordinate: Equatable {
    var latitude: Double
    var longitude: Double

    var value: RufletValue {
      .map(["latitude": .double(latitude), "longitude": .double(longitude)])
    }
  }

  struct Camera: Equatable {
    var center: Coordinate
    var zoom: Double
    var minZoom: Double?
    var maxZoom: Double?
    var rotation: Double

    var value: RufletValue {
      var result: [String: RufletValue] = [
        "center": center.value,
        "zoom": .double(zoom),
        "rotation": .double(rotation),
      ]
      if let minZoom { result["min_zoom"] = .double(minZoom) }
      if let maxZoom { result["max_zoom"] = .double(maxZoom) }
      return .map(result)
    }
  }

  static let initialCenter = Coordinate(latitude: 50.5, longitude: 30.51)
  static let initialZoom = 13.0
  static let initialRotation = 0.0
  static let animationDurationMilliseconds = 500.0
  static let backgroundColor = "grey300"

  enum InteractiveFlag {
    static let drag = 1 << 0
    static let flingAnimation = 1 << 1
    static let pinchMove = 1 << 2
    static let pinchZoom = 1 << 3
    static let doubleTapZoom = 1 << 4
    static let doubleTapDragZoom = 1 << 5
    static let scrollWheelZoom = 1 << 6
    static let rotate = 1 << 7
    static let all = 255

    static func contains(_ flags: Int, _ values: Int...) -> Bool {
      values.contains { flags & $0 != 0 }
    }
  }

  static func coordinate(_ value: RufletValue?) -> Coordinate? {
    guard let map = value?.mapValue else { return nil }
    // Flet's parseLatLng supplies zero for a missing component once a map exists.
    return Coordinate(
      latitude: map["latitude"]?.doubleValue ?? 0,
      longitude: map["longitude"]?.doubleValue ?? 0)
  }

  static func coordinates(_ value: RufletValue?) -> [Coordinate] {
    value?.arrayValue?.compactMap(coordinate) ?? []
  }

  static func animationDuration(_ call: RufletMethodCall, node: ControlNode?) -> Double {
    let milliseconds = call.argument("duration")?.doubleValue
      ?? node?.double("animation_duration")
      ?? animationDurationMilliseconds
    return max(milliseconds, 0) / 1_000
  }

  static func point(for call: RufletMethodCall, key: String) -> Coordinate? {
    coordinate(call.argument(key))
  }

  static func cameraEvent(
    source: String,
    center: Coordinate,
    zoom: Double,
    minZoom: Double?,
    maxZoom: Double?,
    rotation: Double
  ) -> RufletValue {
    .map([
      "source": .string(source),
      "camera": Camera(
        center: center, zoom: zoom, minZoom: minZoom, maxZoom: maxZoom,
        rotation: rotation
      ).value,
    ])
  }
}

struct MapTileConfiguration: Equatable {
  static let defaultSubdomains = ["a", "b", "c"]

  var urlTemplate: String?
  var fallbackURL: String?
  var subdomains: [String] = defaultSubdomains
  var tileSize = 256
  var userAgent = "unknown"
  var minNativeZoom = 0
  var maxNativeZoom = 19
  var maxZoom: Double?
  var zoomReverse = false
  var zoomOffset = 0.0
  var tms = false
  var retinaMode = false
  var additionalOptions: [String: String] = [:]
  var tileBounds: (corner1: MapControlSemantics.Coordinate, corner2: MapControlSemantics.Coordinate)?
  var displayOpacity = 0.0
  var displayDuration = 0.1

  init(node: ControlNode) {
    urlTemplate = node.string("url_template")
    fallbackURL = node.string("fallback_url")
    if let values = node.array("subdomains") {
      subdomains = values.compactMap(\.stringValue)
    }
    tileSize = node.int("tile_size") ?? 256
    userAgent = node.string("user_agent_package_name") ?? "unknown"
    minNativeZoom = node.int("min_native_zoom") ?? 0
    maxNativeZoom = node.int("max_native_zoom") ?? 19
    maxZoom = node.double("max_zoom")
    zoomReverse = node.bool("zoom_reverse") ?? false
    zoomOffset = node.double("zoom_offset") ?? 0
    tms = node.bool("enable_tms") ?? false
    retinaMode = node.bool("enable_retina_mode") ?? false
    if let bounds = node.map("tile_bounds"),
      let corner1 = MapControlSemantics.coordinate(bounds["corner_1"]),
      let corner2 = MapControlSemantics.coordinate(bounds["corner_2"])
    {
      tileBounds = (corner1, corner2)
    }
    if let display = node.map("display_mode") {
      if display["_type"]?.stringValue?.lowercased() == "instantaneous" {
        displayOpacity = display["opacity"]?.doubleValue ?? 1
        displayDuration = 0
      } else {
        // An explicitly supplied FadeIn follows parseTileDisplay's defaults.
        displayOpacity = display["start_opacity"]?.doubleValue ?? 1
        displayDuration = max(display["duration"]?.doubleValue ?? 100, 0) / 1_000
      }
    }
    additionalOptions = node.map("additional_options")?.reduce(into: [:]) { result, item in
      if let value = item.value.stringValue { result[item.key] = value }
    } ?? [:]
  }

  func url(pathX x: Int, y: Int, z: Int, fallback: Bool = false) -> URL? {
    guard var value = fallback ? fallbackURL : urlTemplate else { return nil }
    let maximum = maxZoom?.isFinite == true ? maxZoom! : Double(maxNativeZoom)
    let resolvedZoom = Int((zoomOffset + (zoomReverse ? maximum - Double(z) : Double(z))).rounded())
    let resolvedY = tms ? ((1 << max(resolvedZoom, 0)) - 1) - y : y
    let subdomain = subdomains.isEmpty ? "" : subdomains[(x + y) % subdomains.count]
    var replacements = additionalOptions
    replacements.merge([
      "x": String(x), "y": String(resolvedY), "z": String(resolvedZoom),
      "s": subdomain, "r": retinaMode ? "@2x" : "", "d": String(tileSize),
    ]) { _, fletValue in fletValue }
    for (key, replacement) in replacements {
      value = value.replacingOccurrences(of: "{\(key)}", with: replacement)
    }
    return URL(string: value)
  }

  func contains(pathX x: Int, y: Int, z: Int) -> Bool {
    guard let tileBounds else { return true }
    let count = pow(2.0, Double(z))
    let longitude = (Double(x) + 0.5) / count * 360 - 180
    let mercator = .pi * (1 - 2 * (Double(y) + 0.5) / count)
    let latitude = atan(sinh(mercator)) * 180 / .pi
    let minLatitude = min(tileBounds.corner1.latitude, tileBounds.corner2.latitude)
    let maxLatitude = max(tileBounds.corner1.latitude, tileBounds.corner2.latitude)
    let minLongitude = min(tileBounds.corner1.longitude, tileBounds.corner2.longitude)
    let maxLongitude = max(tileBounds.corner1.longitude, tileBounds.corner2.longitude)
    return (minLatitude...maxLatitude).contains(latitude)
      && (minLongitude...maxLongitude).contains(longitude)
  }

  static func == (lhs: MapTileConfiguration, rhs: MapTileConfiguration) -> Bool {
    lhs.urlTemplate == rhs.urlTemplate && lhs.fallbackURL == rhs.fallbackURL
      && lhs.subdomains == rhs.subdomains && lhs.tileSize == rhs.tileSize
      && lhs.userAgent == rhs.userAgent && lhs.minNativeZoom == rhs.minNativeZoom
      && lhs.maxNativeZoom == rhs.maxNativeZoom && lhs.maxZoom == rhs.maxZoom
      && lhs.zoomReverse == rhs.zoomReverse && lhs.zoomOffset == rhs.zoomOffset
      && lhs.tms == rhs.tms && lhs.retinaMode == rhs.retinaMode
      && lhs.additionalOptions == rhs.additionalOptions
      && lhs.tileBounds?.corner1 == rhs.tileBounds?.corner1
      && lhs.tileBounds?.corner2 == rhs.tileBounds?.corner2
      && lhs.displayOpacity == rhs.displayOpacity
      && lhs.displayDuration == rhs.displayDuration
  }
}

struct MapControlView: View {
  let node: ControlNode
  @StateObject private var model = MapModel()
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    ZStack {
      #if canImport(MapKit)
        MapContainer(model: model)
      #else
        Color.gray.opacity(0.2)
      #endif
      ForEach(attributionNodes, id: \.id) { attribution in
        switch attribution.type {
        case "RichAttribution":
          MapRichAttributionView(node: attribution)
        default:
          MapSimpleAttributionView(node: attribution)
        }
      }
    }
    .onAppear { model.configure(from: node, store: store, events: events) }
    .onChange(of: store.revision) { _ in
      model.configure(from: node, store: store, events: events)
    }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, completion: completion)
    }
  }

  private var attributionNodes: [ControlNode] {
    let ids = node.controlIDs(forKey: "layers") + node.childIDs
    return ids.compactMap(store.node).filter {
      $0.type == "SimpleAttribution" || $0.type == "RichAttribution"
    }
  }
}

private struct MapSimpleAttributionView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    aligned(alignment) {
      Button { events.fire(node, "click") } label: {
        if let textID = node.controlID(forKey: "text") {
          ControlView(id: textID, axis: .none)
        } else {
          Text(node.string("text") ?? "Placeholder Text")
        }
      }
      .buttonStyle(.plain)
      .padding(4)
      .background(attributionBackground)
    }
    .allowsHitTesting(node.bool("disabled") != true)
  }

  private var alignment: Alignment {
    ControlProps.alignment(node.props["alignment"]) ?? .bottomTrailing
  }
}

private struct MapRichAttributionView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var expanded = false

  var body: some View {
    aligned(alignment) {
      VStack(alignment: .trailing, spacing: 4) {
        if expanded {
          VStack(alignment: .leading, spacing: 4) {
            if node.bool("show_flutter_map_attribution") ?? true {
              Text("flutter_map")
            }
            ForEach(attributions, id: \.id) { child in
              attribution(child)
            }
          }
          .padding(8)
          .background(popupBackground)
          .clipShape(RoundedRectangle(cornerRadius: popupRadius))
        }
        Button { expanded.toggle() } label: {
          Image(systemName: expanded ? "info.circle.fill" : "info.circle")
            .frame(height: node.double("permanent_height") ?? 24)
        }
        .buttonStyle(.plain)
      }
      .task(id: node.props["popup_initial_display_duration"]) {
        guard let duration = node.double("popup_initial_display_duration"), duration > 0 else {
          return
        }
        expanded = true
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000))
        expanded = false
      }
    }
  }

  private var attributions: [ControlNode] {
    let ids = node.controlIDs(forKey: "attributions") + node.childIDs
    return ids.compactMap(store.node).filter {
      $0.type == "TextSourceAttribution" || $0.type == "ImageSourceAttribution"
    }
  }

  @ViewBuilder private func attribution(_ child: ControlNode) -> some View {
    Button { events.fire(child, "click") } label: {
      if child.type == "ImageSourceAttribution", let imageID = child.controlID(forKey: "image") {
        ControlView(id: imageID, axis: .none)
          .frame(height: child.double("height") ?? 24)
      } else {
        Text((child.bool("prepend_copyright") ?? true ? "© " : "")
          + (child.string("text") ?? "Placeholder Text"))
      }
    }
    .buttonStyle(.plain)
    .help(child.string("tooltip") ?? "")
  }

  private var alignment: Alignment {
    ControlProps.alignment(node.props["alignment"]) ?? .bottomTrailing
  }

  private var popupRadius: CGFloat {
    let value = node.props["popup_border_radius"]
    return CGFloat(value?.doubleValue ?? value?["top_left"]?.doubleValue ?? 0)
  }

  private var popupBackground: Color {
    MaterialPalette.color(node.string("popup_bgcolor")) ?? attributionBackground
  }
}

private var attributionBackground: Color {
  #if canImport(UIKit)
    Color(uiColor: .systemBackground)
  #elseif canImport(AppKit)
    Color(nsColor: .windowBackgroundColor)
  #else
    Color.white
  #endif
}

@ViewBuilder private func aligned<Content: View>(
  _ alignment: Alignment,
  @ViewBuilder content: () -> Content
) -> some View {
  VStack {
    if alignment.vertical == .bottom { Spacer(minLength: 0) }
    HStack {
      if alignment.horizontal == .trailing { Spacer(minLength: 0) }
      content()
      if alignment.horizontal == .leading { Spacer(minLength: 0) }
    }
    if alignment.vertical == .top { Spacer(minLength: 0) }
  }
  .padding(4)
}

#if !canImport(MapKit)
  @MainActor
  final class MapModel: ObservableObject {
    func configure(from node: ControlNode, store: ControlStore, events: RufletEventSink) {}
    func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      completion(.failure(rufletUnsupported("Map", call)))
    }
  }
#endif
