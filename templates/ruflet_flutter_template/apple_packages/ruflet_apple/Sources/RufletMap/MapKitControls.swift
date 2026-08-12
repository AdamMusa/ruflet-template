#if canImport(MapKit)
import Foundation
import MapKit
import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

private final class RufletMapView: MKMapView {
  var pointerDown: ((CGPoint) -> Void)?
  var pointerUp: ((CGPoint) -> Void)?
  var pointerCancel: ((CGPoint) -> Void)?
  var pointerHover: ((CGPoint) -> Void)?
  var secondaryTap: ((CGPoint) -> Void)?

  #if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      if let point = touches.first?.location(in: self) { pointerDown?(point) }
      super.touchesBegan(touches, with: event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      if let point = touches.first?.location(in: self) { pointerUp?(point) }
      super.touchesEnded(touches, with: event)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      if let point = touches.first?.location(in: self) { pointerCancel?(point) }
      super.touchesCancelled(touches, with: event)
    }
  #elseif canImport(AppKit)
    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      for area in trackingAreas { removeTrackingArea(area) }
      addTrackingArea(NSTrackingArea(
        rect: bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
        owner: self, userInfo: nil))
    }
    override func mouseDown(with event: NSEvent) {
      pointerDown?(convert(event.locationInWindow, from: nil))
      super.mouseDown(with: event)
    }
    override func mouseUp(with event: NSEvent) {
      pointerUp?(convert(event.locationInWindow, from: nil))
      super.mouseUp(with: event)
    }
    override func mouseMoved(with event: NSEvent) {
      pointerHover?(convert(event.locationInWindow, from: nil))
      super.mouseMoved(with: event)
    }
    override func rightMouseUp(with event: NSEvent) {
      secondaryTap?(convert(event.locationInWindow, from: nil))
      super.rightMouseUp(with: event)
    }
  #endif
}

private final class HostedMapAnnotation: NSObject, MKAnnotation {
  dynamic var coordinate: CLLocationCoordinate2D
  let contentID: Int
  let size: CGSize
  let alignment: Alignment
  let rotates: Bool

  init(
    coordinate: CLLocationCoordinate2D, contentID: Int, size: CGSize,
    alignment: Alignment, rotates: Bool
  ) {
    self.coordinate = coordinate
    self.contentID = contentID
    self.size = size
    self.alignment = alignment
    self.rotates = rotates
  }
}

private final class LabelMapAnnotation: NSObject, MKAnnotation {
  dynamic var coordinate: CLLocationCoordinate2D
  let text: String
  init(coordinate: CLLocationCoordinate2D, text: String) {
    self.coordinate = coordinate
    self.text = text
  }
}

private struct CircleMapStyle {
  var fill: String
  var border: String
  var borderWidth: CGFloat
}

private struct PolylineMapStyle {
  var color: String
  var borderColor: String
  var width: CGFloat
  var borderWidth: CGFloat
  var gradientColors: [String]
  var colorStops: [CGFloat]
  var usesMeterWidth: Bool
  var dash: [CGFloat]?
  var cap: CGLineCap
  var join: CGLineJoin
}

private struct PolygonMapStyle {
  var fill: String
  var border: String
  var borderWidth: CGFloat
  var cap: CGLineCap
  var join: CGLineJoin
}

@MainActor
final class MapModel: NSObject, ObservableObject, MKMapViewDelegate {
  fileprivate let view = RufletMapView()
  private var control: ControlNode?
  private weak var store: ControlStore?
  private var events = RufletEventSink()
  private var applyingConfiguration = false
  private var initialized = false
  private var circleStyles: [ObjectIdentifier: CircleMapStyle] = [:]
  private var lineStyles: [ObjectIdentifier: PolylineMapStyle] = [:]
  private var polygonStyles: [ObjectIdentifier: PolygonMapStyle] = [:]

  override init() {
    super.init()
    view.delegate = self
    #if canImport(UIKit)
      let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
      tap.delegate = self
      let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
      longPress.delegate = self
      view.addGestureRecognizer(tap)
      view.addGestureRecognizer(longPress)
      if #available(iOS 13.4, *) {
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(didHover(_:)))
        hover.delegate = self
        view.addGestureRecognizer(hover)
      }
    #elseif canImport(AppKit)
      let tap = NSClickGestureRecognizer(target: self, action: #selector(didClick(_:)))
      tap.delegate = self
      let longPress = NSPressGestureRecognizer(target: self, action: #selector(didPress(_:)))
      longPress.delegate = self
      view.addGestureRecognizer(tap)
      view.addGestureRecognizer(longPress)
    #endif
    view.pointerDown = { [weak self] in self?.firePointer("pointer_down", at: $0) }
    view.pointerUp = { [weak self] in self?.firePointer("pointer_up", at: $0) }
    view.pointerCancel = { [weak self] in self?.firePointer("pointer_cancel", at: $0) }
    view.pointerHover = { [weak self] in self?.firePointer("hover", at: $0) }
    view.secondaryTap = { [weak self] in self?.fireTap("secondary_tap", at: $0) }
  }

  static func span(forZoom zoom: Double) -> MKCoordinateSpan {
    let degrees = 360 / pow(2, max(zoom, 0))
    return MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees)
  }

  static func zoom(forSpan span: MKCoordinateSpan) -> Double {
    log2(360 / max(span.latitudeDelta, 0.000_000_1))
  }

  func configure(from node: ControlNode, store: ControlStore, events: RufletEventSink) {
    control = node
    self.store = store
    self.events = events
    applyingConfiguration = true
    applyInteraction(node)
    applyBackground(node)
    if !initialized { applyInitialCamera(node) }
    view.removeAnnotations(view.annotations)
    view.removeOverlays(view.overlays)
    circleStyles.removeAll(keepingCapacity: true)
    lineStyles.removeAll(keepingCapacity: true)
    polygonStyles.removeAll(keepingCapacity: true)
    installLayers(from: node, store: store)
    applyingConfiguration = false
    if !initialized {
      initialized = true
      if MapControlSemantics.eventEnabled("init", node: node) {
        events.fire(node, "init")
      }
    }
  }

  private func applyInteraction(_ node: ControlNode) {
    let flags = node.map("interaction_configuration")?["flags"]?.intValue
      ?? MapControlSemantics.InteractiveFlag.all
    view.isScrollEnabled = MapControlSemantics.InteractiveFlag.contains(
      flags, MapControlSemantics.InteractiveFlag.drag,
      MapControlSemantics.InteractiveFlag.pinchMove)
    view.isZoomEnabled = MapControlSemantics.InteractiveFlag.contains(
      flags, MapControlSemantics.InteractiveFlag.pinchZoom,
      MapControlSemantics.InteractiveFlag.doubleTapZoom,
      MapControlSemantics.InteractiveFlag.doubleTapDragZoom,
      MapControlSemantics.InteractiveFlag.scrollWheelZoom)
    view.isRotateEnabled = MapControlSemantics.InteractiveFlag.contains(
      flags, MapControlSemantics.InteractiveFlag.rotate)
    view.isPitchEnabled = false
  }

  private func applyBackground(_ node: ControlNode) {
    guard let color = MaterialPalette.color(
      node.string("bgcolor") ?? MapControlSemantics.backgroundColor) else { return }
    #if canImport(UIKit)
      view.backgroundColor = UIColor(color)
    #elseif canImport(AppKit)
      view.wantsLayer = true
      view.layer?.backgroundColor = NSColor(color).cgColor
    #endif
  }

  private func applyInitialCamera(_ node: ControlNode) {
    let center = MapControlSemantics.coordinate(node.props["initial_center"])
      ?? MapControlSemantics.initialCenter
    let zoom = clampedZoom(node.double("initial_zoom") ?? MapControlSemantics.initialZoom)
    view.setRegion(MKCoordinateRegion(center: center.native, span: Self.span(forZoom: zoom)), animated: false)
    let camera = view.camera.copy() as! MKMapCamera
    camera.heading = node.double("initial_rotation") ?? MapControlSemantics.initialRotation
    view.setCamera(camera, animated: false)
    if let fit = node.map("initial_camera_fit") { applyCameraFit(fit) }
  }

  private func applyCameraFit(_ fit: [String: RufletValue]) {
    var coordinates: [CLLocationCoordinate2D] = []
    if let bounds = fit["bounds"]?.mapValue {
      coordinates += [
        MapControlSemantics.coordinate(bounds["corner_1"])?.native,
        MapControlSemantics.coordinate(bounds["corner_2"])?.native,
      ].compactMap { $0 }
    } else {
      coordinates = MapControlSemantics.coordinates(fit["coordinates"]).map(\.native)
    }
    guard coordinates.count >= 2 else { return }
    var rect = MKMapRect.null
    for coordinate in coordinates {
      let point = MKMapPoint(coordinate)
      rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
    }
    view.setVisibleMapRect(rect, edgePadding: platformInsets(fit["padding"]), animated: false)
    let minZoom = fit["min_zoom"]?.doubleValue ?? 0
    let maxZoom = fit["max_zoom"]?.doubleValue
    var zoom = max(Self.zoom(forSpan: view.region.span), minZoom)
    if let maxZoom { zoom = min(zoom, maxZoom) }
    if fit["force_integer_zoom_level"]?.boolValue == true { zoom.round() }
    view.setRegion(MKCoordinateRegion(center: view.region.center, span: Self.span(forZoom: zoom)), animated: false)
  }

  private func installLayers(from node: ControlNode, store: ControlStore) {
    for layerID in orderedUnique(node.controlIDs(forKey: "layers") + node.childIDs) {
      guard let layer = store.node(layerID) else { continue }
      switch layer.type {
      case "TileLayer": installTile(layer)
      case "MarkerLayer": installMarkers(layer, store: store)
      case "CircleLayer": installCircles(layer, store: store)
      case "PolylineLayer": installPolylines(layer, store: store)
      case "PolygonLayer": installPolygons(layer, store: store)
      default: break
      }
    }
  }

  private func installTile(_ layer: ControlNode) {
    let configuration = MapTileConfiguration(node: layer)
    guard configuration.urlTemplate != nil else { return }
    let overlay = FletTileOverlay(configuration: configuration)
    overlay.minimumZ = configuration.minNativeZoom
    overlay.maximumZ = configuration.maxNativeZoom
    overlay.tileSize = CGSize(width: configuration.tileSize, height: configuration.tileSize)
    overlay.canReplaceMapContent = true
    overlay.onError = { [weak self] message in
      Task { @MainActor in self?.events.fire(layer, "image_error", data: .string(message)) }
    }
    view.addOverlay(overlay, level: .aboveLabels)
  }

  private func installMarkers(_ layer: ControlNode, store: ControlStore) {
    let layerAlignment = ControlProps.alignment(layer.props["alignment"]) ?? .center
    let layerRotates = layer.bool("rotate") ?? false
    for id in orderedUnique(layer.controlIDs(forKey: "markers") + layer.childIDs) {
      guard let marker = store.node(id), marker.type == "Marker",
        let coordinate = MapControlSemantics.coordinate(marker.props["coordinates"]),
        let contentID = marker.controlID(forKey: "content")
      else { continue }
      view.addAnnotation(HostedMapAnnotation(
        coordinate: coordinate.native, contentID: contentID,
        size: CGSize(width: marker.double("width") ?? 30, height: marker.double("height") ?? 30),
        alignment: ControlProps.alignment(marker.props["alignment"]) ?? layerAlignment,
        rotates: marker.bool("rotate") ?? layerRotates))
    }
  }

  private func installCircles(_ layer: ControlNode, store: ControlStore) {
    for id in orderedUnique(layer.controlIDs(forKey: "circles") + layer.childIDs) {
      guard let circle = store.node(id), circle.type == "CircleMarker",
        let coordinate = MapControlSemantics.coordinate(circle.props["coordinates"])
      else { continue }
      let radius = circle.double("radius") ?? 10
      let meters = circle.bool("use_radius_in_meter") == true
        ? radius : screenRadiusInMeters(radius, at: coordinate.native)
      let overlay = MKCircle(center: coordinate.native, radius: meters)
      circleStyles[ObjectIdentifier(overlay)] = CircleMapStyle(
        fill: circle.string("color") ?? "green",
        border: circle.string("border_color") ?? "yellow",
        borderWidth: CGFloat(circle.double("border_stroke_width") ?? 0))
      view.addOverlay(overlay)
    }
  }

  private func installPolylines(_ layer: ControlNode, store: ControlStore) {
    for id in orderedUnique(layer.controlIDs(forKey: "polylines") + layer.childIDs) {
      guard let line = store.node(id), line.type == "PolylineMarker" else { continue }
      var coordinates = MapControlSemantics.coordinates(line.props["coordinates"]).map(\.native)
      guard coordinates.count > 1 else { continue }
      let width = CGFloat(line.double("stroke_width") ?? 1)
      let borderWidth = CGFloat(line.double("border_stroke_width") ?? 0)
      if borderWidth > 0 {
        let borderOverlay = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        lineStyles[ObjectIdentifier(borderOverlay)] = PolylineMapStyle(
          color: line.string("border_color") ?? "yellow",
          borderColor: line.string("border_color") ?? "yellow",
          width: width + borderWidth * 2, borderWidth: 0,
          gradientColors: [], colorStops: [], usesMeterWidth: false,
          dash: dashPattern(line.props["stroke_pattern"]),
          cap: lineCap(line.string("stroke_cap")), join: lineJoin(line.string("stroke_join")))
        view.addOverlay(borderOverlay)
      }
      let overlay = MKPolyline(coordinates: &coordinates, count: coordinates.count)
      lineStyles[ObjectIdentifier(overlay)] = PolylineMapStyle(
        color: line.string("color") ?? "yellow",
        borderColor: line.string("border_color") ?? "yellow",
        width: width, borderWidth: borderWidth,
        gradientColors: line.array("gradient_colors")?.compactMap(\.stringValue) ?? [],
        colorStops: line.array("colors_stop")?.compactMap { value in
          value.doubleValue.map { CGFloat($0) }
        } ?? [],
        usesMeterWidth: line.bool("use_stroke_width_in_meter") ?? false,
        dash: dashPattern(line.props["stroke_pattern"]),
        cap: lineCap(line.string("stroke_cap")), join: lineJoin(line.string("stroke_join")))
      view.addOverlay(overlay)
    }
  }

  private func installPolygons(_ layer: ControlNode, store: ControlStore) {
    for id in orderedUnique(layer.controlIDs(forKey: "polygons") + layer.childIDs) {
      guard let polygon = store.node(id), polygon.type == "PolygonMarker" else { continue }
      var coordinates = MapControlSemantics.coordinates(polygon.props["coordinates"]).map(\.native)
      guard coordinates.count > 2 else { continue }
      let overlay = MKPolygon(coordinates: &coordinates, count: coordinates.count)
      polygonStyles[ObjectIdentifier(overlay)] = PolygonMapStyle(
        fill: polygon.string("color") ?? "green", border: polygon.string("border_color") ?? "green",
        borderWidth: CGFloat(polygon.double("border_stroke_width") ?? 0),
        cap: lineCap(polygon.string("stroke_cap")), join: lineJoin(polygon.string("stroke_join")))
      view.addOverlay(overlay)
      if layer.bool("polygon_labels") ?? true, let label = polygon.string("label") {
        let sum = coordinates.reduce((latitude: 0.0, longitude: 0.0)) {
          ($0.latitude + $1.latitude, $0.longitude + $1.longitude)
        }
        view.addAnnotation(LabelMapAnnotation(
          coordinate: CLLocationCoordinate2D(
            latitude: sum.latitude / Double(coordinates.count),
            longitude: sum.longitude / Double(coordinates.count)), text: label))
      }
    }
  }

  private func orderedUnique(_ ids: [Int]) -> [Int] {
    var seen = Set<Int>()
    return ids.filter { seen.insert($0).inserted }
  }

  private func screenRadiusInMeters(_ radius: Double, at coordinate: CLLocationCoordinate2D) -> Double {
    let center = view.convert(coordinate, toPointTo: view)
    let edge = CGPoint(x: center.x + radius, y: center.y)
    return MKMapPoint(coordinate).distance(
      to: MKMapPoint(view.convert(edge, toCoordinateFrom: view)))
  }

  private func dashPattern(_ value: RufletValue?) -> [CGFloat]? {
    guard let map = value?.mapValue, let type = map["_type"]?.stringValue else { return nil }
    switch type.lowercased() {
    case "dotted": return [1, CGFloat(map["spacing_factor"]?.doubleValue ?? 1.5)]
    case "dashed":
      return map["segments"]?.arrayValue?.compactMap { value in
        value.doubleValue.map { CGFloat($0) }
      }
    default: return nil
    }
  }

  private func lineCap(_ value: String?) -> CGLineCap {
    switch value?.lowercased() {
    case "butt": return .butt
    case "square": return .square
    default: return .round
    }
  }

  private func lineJoin(_ value: String?) -> CGLineJoin {
    switch value?.lowercased() {
    case "bevel": return .bevel
    case "miter": return .miter
    default: return .round
    }
  }

  private func clampedZoom(_ zoom: Double) -> Double {
    MapControlSemantics.clampedZoom(zoom, node: control)
  }

  private func hasGesture(_ mapView: MKMapView) -> Bool {
    #if canImport(UIKit)
    mapView.gestureRecognizers?.contains { $0.state == .began || $0.state == .changed } ?? false
    #else
    mapView.gestureRecognizers.contains { $0.state == .began || $0.state == .changed }
    #endif
  }

  private func coordinateAndGlobalPoint(_ point: CGPoint) -> (
    MapControlSemantics.Coordinate, CGPoint
  ) {
    let coordinate = view.convert(point, toCoordinateFrom: view)
    let global = view.convert(point, to: nil)
    return (.init(latitude: coordinate.latitude, longitude: coordinate.longitude), global)
  }

  private func tapData(_ point: CGPoint) -> RufletValue {
    let (coordinate, global) = coordinateAndGlobalPoint(point)
    return MapControlSemantics.tapEvent(
      coordinate: coordinate, globalX: Double(global.x), globalY: Double(global.y),
      localX: Double(point.x), localY: Double(point.y))
  }

  private func pointerData(_ point: CGPoint, kind: String) -> RufletValue {
    let (coordinate, global) = coordinateAndGlobalPoint(point)
    return MapControlSemantics.pointerEvent(
      coordinate: coordinate, kind: kind,
      globalX: Double(global.x), globalY: Double(global.y),
      localX: Double(point.x), localY: Double(point.y),
      timestampMicroseconds: Int64(ProcessInfo.processInfo.systemUptime * 1_000_000))
  }

  private func fireTap(_ name: String, at point: CGPoint) {
    guard let control, MapControlSemantics.eventEnabled(name, node: control) else { return }
    events.fire(control, name, data: tapData(point))
  }
  private func firePointer(_ name: String, at point: CGPoint) {
    guard let control, MapControlSemantics.eventEnabled(name, node: control) else { return }
    #if canImport(UIKit)
      let kind = name == "hover" ? "mouse" : "touch"
    #else
      let kind = "mouse"
    #endif
    events.fire(control, name, data: pointerData(point, kind: kind))
  }

  func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
    guard !applyingConfiguration, let control else { return }
    let center = MapControlSemantics.Coordinate(
      latitude: mapView.region.center.latitude, longitude: mapView.region.center.longitude)
    let zoom = Self.zoom(forSpan: mapView.region.span)
    let rotation = mapView.camera.heading
    let camera = MapControlSemantics.Camera(
      center: center, zoom: zoom, minZoom: control.double("min_zoom"),
      maxZoom: control.double("max_zoom"), rotation: rotation)
    let gesture = hasGesture(mapView)
    if MapControlSemantics.eventEnabled("position_change", node: control) {
      events.fire(control, "position_change", data: .map([
        "coordinates": center.value, "has_gesture": .bool(gesture), "camera": camera.value,
      ]))
    }
    if MapControlSemantics.eventEnabled("event", node: control) {
      events.fire(control, "event", data: MapControlSemantics.cameraEvent(
        source: gesture ? "dragUpdate" : "mapController", center: center, zoom: zoom,
        minZoom: control.double("min_zoom"), maxZoom: control.double("max_zoom"), rotation: rotation))
    }
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if let hosted = annotation as? HostedMapAnnotation, let store {
      return hostedAnnotationView(hosted, store: store)
    }
    if let label = annotation as? LabelMapAnnotation {
      let annotationView = MKMarkerAnnotationView(annotation: label, reuseIdentifier: nil)
      annotationView.glyphText = label.text
      annotationView.markerTintColor = .clear
      return annotationView
    }
    return nil
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let tile = overlay as? FletTileOverlay {
      let renderer = MKTileOverlayRenderer(tileOverlay: tile)
      renderer.alpha = tile.configuration.displayOpacity
      if tile.configuration.displayDuration > 0 {
        let duration = tile.configuration.displayDuration
        DispatchQueue.main.async {
          #if canImport(UIKit)
            UIView.animate(withDuration: duration) { renderer.alpha = 1 }
          #elseif canImport(AppKit)
            NSAnimationContext.runAnimationGroup { context in
              context.duration = duration
              renderer.alpha = 1
            }
          #endif
        }
      }
      return renderer
    }
    if let tile = overlay as? MKTileOverlay { return MKTileOverlayRenderer(tileOverlay: tile) }
    if let circle = overlay as? MKCircle, let style = circleStyles[ObjectIdentifier(circle)] {
      let renderer = MKCircleRenderer(circle: circle)
      renderer.fillColor = platformColor(style.fill)
      renderer.strokeColor = platformColor(style.border)
      renderer.lineWidth = style.borderWidth
      return renderer
    }
    if let line = overlay as? MKPolyline, let style = lineStyles[ObjectIdentifier(line)] {
      let renderer: MKPolylineRenderer
      if style.gradientColors.count > 1 {
        let gradient = MKGradientPolylineRenderer(polyline: line)
        let colors = style.gradientColors.map(platformColor)
        let locations = style.colorStops.count == colors.count
          ? style.colorStops : (0..<colors.count).map { CGFloat($0) / CGFloat(colors.count - 1) }
        gradient.setColors(colors, locations: locations)
        renderer = gradient
      } else {
        let plain = MKPolylineRenderer(polyline: line)
        plain.strokeColor = platformColor(style.color)
        renderer = plain
      }
      renderer.lineWidth = style.usesMeterWidth
        ? meterWidthInPoints(style.width, overlay: line, mapView: mapView) : style.width
      renderer.lineCap = style.cap
      renderer.lineJoin = style.join
      renderer.lineDashPattern = style.dash?.map { NSNumber(value: Double($0)) }
      return renderer
    }
    if let polygon = overlay as? MKPolygon, let style = polygonStyles[ObjectIdentifier(polygon)] {
      let renderer = MKPolygonRenderer(polygon: polygon)
      renderer.fillColor = platformColor(style.fill)
      renderer.strokeColor = platformColor(style.border)
      renderer.lineWidth = style.borderWidth
      renderer.lineCap = style.cap
      renderer.lineJoin = style.join
      return renderer
    }
    return MKOverlayRenderer(overlay: overlay)
  }

  private func centerOffset(_ annotation: HostedMapAnnotation) -> CGPoint {
    let x: CGFloat = annotation.alignment.horizontal == .leading ? annotation.size.width / 2
      : annotation.alignment.horizontal == .trailing ? -annotation.size.width / 2 : 0
    let y: CGFloat = annotation.alignment.vertical == .top ? annotation.size.height / 2
      : annotation.alignment.vertical == .bottom ? -annotation.size.height / 2 : 0
    return CGPoint(x: x, y: y)
  }

  private func meterWidthInPoints(
    _ meters: CGFloat, overlay: MKPolyline, mapView: MKMapView
  ) -> CGFloat {
    let coordinate = MKMapPoint(
      x: overlay.boundingMapRect.midX, y: overlay.boundingMapRect.midY).coordinate
    let onePointInMeters = screenRadiusInMeters(1, at: coordinate)
    return onePointInMeters > 0 ? meters / CGFloat(onePointInMeters) : meters
  }

  func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    let options = MapControlSemantics.methodOptions(call, node: control)
    var didAnimate = false
    switch call.name {
    case "move_to":
      let destination = MapControlSemantics.point(for: call, key: "destination")?.native
      let zoom = call.argument("zoom")?.doubleValue
      let rotation = call.argument("rotation")?.doubleValue
      let offset = call.argument("offset")?.mapValue
      var region = view.region
      if let destination { region.center = destination }
      if let zoom { region.span = Self.span(forZoom: clampedZoom(zoom)) }
      let offsetX = offset?["x"]?.doubleValue ?? 0
      let offsetY = offset?["y"]?.doubleValue ?? 0
      if offset != nil {
        let centerPoint = view.convert(region.center, toPointTo: view)
        let shifted = CGPoint(
          x: centerPoint.x - CGFloat(offsetX), y: centerPoint.y - CGFloat(offsetY))
        region.center = view.convert(shifted, toCoordinateFrom: view)
      }
      if destination != nil || zoom != nil || offsetX != 0 || offsetY != 0 {
        animate(options: options) { self.view.setRegion(region, animated: false) }
        didAnimate = true
      }
      if let rotation {
        setRotation(rotation, relative: false, options: options)
        didAnimate = true
      }
    case "center_on":
      if let point = MapControlSemantics.point(for: call, key: "point")?.native {
        var region = view.region
        region.center = point
        if let zoom = call.argument("zoom")?.doubleValue {
          region.span = Self.span(forZoom: clampedZoom(zoom))
        }
        animate(options: options) { self.view.setRegion(region, animated: false) }
        didAnimate = true
      }
    case "zoom_to":
      if let zoom = call.argument("zoom")?.doubleValue {
        setZoom(zoom, options: options)
        didAnimate = true
      }
    case "zoom_in":
      setZoom(Self.zoom(forSpan: view.region.span) + 1, options: options)
      didAnimate = true
    case "zoom_out":
      setZoom(Self.zoom(forSpan: view.region.span) - 1, options: options)
      didAnimate = true
    case "rotate_from":
      if let degree = call.argument("degree")?.doubleValue {
        setRotation(degree, relative: true, options: options)
        didAnimate = degree != 0
      }
    case "reset_rotation":
      didAnimate = view.camera.heading != 0
      setRotation(0, relative: false, options: options)
    default:
      completion(.failure(rufletUnsupported("Map", call)))
      return
    }
    complete(completion, after: didAnimate ? options.duration : 0)
  }

  private func setZoom(_ zoom: Double, options: MapControlSemantics.MethodOptions) {
    let region = MKCoordinateRegion(center: view.region.center, span: Self.span(forZoom: clampedZoom(zoom)))
    animate(options: options) { self.view.setRegion(region, animated: false) }
  }
  private func setRotation(
    _ rotation: Double, relative: Bool, options: MapControlSemantics.MethodOptions
  ) {
    let camera = view.camera.copy() as! MKMapCamera
    camera.heading = relative ? camera.heading + rotation : rotation
    animate(options: options) { self.view.setCamera(camera, animated: false) }
  }
  private func animate(
    options: MapControlSemantics.MethodOptions, changes: @escaping () -> Void
  ) {
    guard options.duration > 0 else { changes(); return }
    #if canImport(UIKit)
      var animationOptions: UIView.AnimationOptions = [.allowUserInteraction]
      if options.cancelOngoingAnimations { animationOptions.insert(.beginFromCurrentState) }
      switch options.curve {
      case "linear": animationOptions.insert(.curveLinear)
      case "easein": animationOptions.insert(.curveEaseIn)
      case "easeout": animationOptions.insert(.curveEaseOut)
      default: animationOptions.insert(.curveEaseInOut)
      }
      UIView.animate(
        withDuration: options.duration, delay: 0,
        options: animationOptions, animations: changes)
    #elseif canImport(AppKit)
      if options.cancelOngoingAnimations { view.layer?.removeAllAnimations() }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = options.duration
        switch options.curve {
        case "linear": context.timingFunction = CAMediaTimingFunction(name: .linear)
        case "easein": context.timingFunction = CAMediaTimingFunction(name: .easeIn)
        case "easeout": context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        default: context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        }
        changes()
      }
    #endif
  }

  private func complete(
    _ completion: @escaping RufletMethodCompletion, after duration: TimeInterval
  ) {
    guard duration > 0 else { completion(.success(.null)); return }
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      completion(.success(.null))
    }
  }
}

#if canImport(UIKit)
  extension MapModel: UIGestureRecognizerDelegate {
    @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
      guard recognizer.state == .ended else { return }
      fireTap("tap", at: recognizer.location(in: view))
    }
    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
      guard recognizer.state == .began else { return }
      fireTap("long_press", at: recognizer.location(in: view))
    }
    @available(iOS 13.4, *)
    @objc private func didHover(_ recognizer: UIHoverGestureRecognizer) {
      guard recognizer.state == .began || recognizer.state == .changed else { return }
      firePointer("hover", at: recognizer.location(in: view))
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

    private func hostedAnnotationView(_ annotation: HostedMapAnnotation, store: ControlStore) -> MKAnnotationView {
      let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
      let root = AnyView(ControlView(id: annotation.contentID, axis: .none)
        .environmentObject(store).environment(\.rufletEvents, events)
        .frame(width: annotation.size.width, height: annotation.size.height))
      let host = UIHostingController(rootView: root)
      host.view.backgroundColor = .clear
      host.view.frame = CGRect(origin: .zero, size: annotation.size)
      annotationView.frame.size = annotation.size
      annotationView.addSubview(host.view)
      annotationView.centerOffset = centerOffset(annotation)
      return annotationView
    }
    private func platformColor(_ name: String) -> UIColor {
      UIColor(MaterialPalette.color(name, default: .primary))
    }
    private func platformInsets(_ value: RufletValue?) -> UIEdgeInsets {
      let value = ControlProps.edgeInsets(value) ?? EdgeInsets()
      return UIEdgeInsets(top: value.top, left: value.leading, bottom: value.bottom, right: value.trailing)
    }
  }
#elseif canImport(AppKit)
  extension MapModel: NSGestureRecognizerDelegate {
    @objc private func didClick(_ recognizer: NSClickGestureRecognizer) {
      guard recognizer.state == .ended else { return }
      fireTap("tap", at: recognizer.location(in: view))
    }
    @objc private func didPress(_ recognizer: NSPressGestureRecognizer) {
      guard recognizer.state == .began else { return }
      fireTap("long_press", at: recognizer.location(in: view))
    }
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool { true }

    private func hostedAnnotationView(_ annotation: HostedMapAnnotation, store: ControlStore) -> MKAnnotationView {
      let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
      let root = AnyView(ControlView(id: annotation.contentID, axis: .none)
        .environmentObject(store).environment(\.rufletEvents, events)
        .frame(width: annotation.size.width, height: annotation.size.height))
      let host = NSHostingView(rootView: root)
      host.frame = CGRect(origin: .zero, size: annotation.size)
      annotationView.frame.size = annotation.size
      annotationView.addSubview(host)
      annotationView.centerOffset = centerOffset(annotation)
      return annotationView
    }
    private func platformColor(_ name: String) -> NSColor {
      NSColor(MaterialPalette.color(name, default: .primary))
    }
    private func platformInsets(_ value: RufletValue?) -> NSEdgeInsets {
      let value = ControlProps.edgeInsets(value) ?? EdgeInsets()
      return NSEdgeInsets(top: value.top, left: value.leading, bottom: value.bottom, right: value.trailing)
    }
  }
#endif

private final class FletTileOverlay: MKTileOverlay {
  private static let cache = NSCache<NSURL, NSData>()
  let configuration: MapTileConfiguration
  var onError: ((String) -> Void)?

  init(configuration: MapTileConfiguration) {
    self.configuration = configuration
    super.init(urlTemplate: nil)
  }

  override func url(forTilePath path: MKTileOverlayPath) -> URL {
    configuration.url(pathX: path.x, y: path.y, z: path.z) ?? URL(string: "about:blank")!
  }

  override func loadTile(at path: MKTileOverlayPath,
    result: @escaping (Data?, (any Error)?) -> Void) {
    guard configuration.contains(pathX: path.x, y: path.y, z: path.z) else {
      result(nil, nil); return
    }
    guard let url = configuration.url(pathX: path.x, y: path.y, z: path.z) else {
      result(nil, URLError(.badURL)); return
    }
    if configuration.allowsMemoryCache,
      let data = Self.cache.object(forKey: url as NSURL)
    {
      result(data as Data, nil); return
    }
    load(url: url,
      fallback: configuration.url(pathX: path.x, y: path.y, z: path.z, fallback: true),
      result: result)
  }

  private func load(url: URL, fallback: URL?,
    result: @escaping (Data?, (any Error)?) -> Void) {
    var request = URLRequest(url: url)
    request.setValue(configuration.httpUserAgent, forHTTPHeaderField: "User-Agent")
    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      let status = (response as? HTTPURLResponse)?.statusCode ?? 200
      if let data, error == nil, (200..<300).contains(status) {
        if self?.configuration.allowsMemoryCache == true {
          Self.cache.setObject(data as NSData, forKey: url as NSURL)
        }
        result(data, nil)
      } else if let fallback, fallback != url {
        self?.load(url: fallback, fallback: nil, result: result)
      } else {
        let failure = error ?? URLError(.badServerResponse)
        self?.onError?(failure.localizedDescription)
        result(nil, failure)
      }
    }.resume()
  }
}

struct MapContainer {
  let model: MapModel
}

#if canImport(UIKit)
  extension MapContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView { model.view }
    func updateUIView(_ view: MKMapView, context: Context) {}
  }
#elseif canImport(AppKit)
  extension MapContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> MKMapView { model.view }
    func updateNSView(_ view: MKMapView, context: Context) {}
  }
#endif

private extension MapControlSemantics.Coordinate {
  var native: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
#endif
