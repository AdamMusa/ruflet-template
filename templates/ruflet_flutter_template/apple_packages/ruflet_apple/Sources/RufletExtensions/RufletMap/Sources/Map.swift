import Combine
import MapKit
import QuartzCore
import RufletEngine
import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MapControl: View {
  @ObservedObject var control: RufletControl
  @StateObject private var controller: RufletMapController

  init(control: RufletControl) {
    self.control = control
    _controller = StateObject(wrappedValue: RufletMapController(control: control))
  }

  var body: some View {
    ZStack {
      RufletMapSurface(control: control, controller: controller)
      ForEach(attributionLayers, id: \.id) { layer in
        if layer.type == "RichAttribution" {
          RichAttributionControl(control: layer)
        } else if layer.type == "SimpleAttribution" {
          SimpleAttributionControl(control: layer)
        }
      }
    }
    .background(rufletMapColor(control.string("bgcolor"), default: Color.gray.opacity(0.3)))
    .onAppear { controller.attach() }
    .onDisappear { controller.detach() }
  }

  private var attributionLayers: [RufletControl] {
    control.children("layers", visibleOnly: false).filter {
      $0.type == "RichAttribution" || $0.type == "SimpleAttribution"
    }
  }
}

enum RufletMapInvocationError: LocalizedError {
  case unknownMethod(String)
  case missingArgument(String)

  var errorDescription: String? {
    switch self {
    case .unknownMethod(let name): "Unknown Map method: \(name)"
    case .missingArgument(let name): "Map method is missing required argument: \(name)"
    }
  }
}

@MainActor
final class RufletMapController: ObservableObject {
  let control: RufletControl
  weak var mapView: MKMapView?
  private var invokeToken: UUID?

  init(control: RufletControl) { self.control = control }

  func attach() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try await self.invoke(name, arguments: arguments)
    }
  }

  func detach() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    guard let mapView else { return .null }
    let args = rufletStringMap(arguments) ?? [:]
    let duration = (args["duration"]?.number
      ?? control.number("animation_duration", default: 500)
      ?? 500) / 1_000
    if args["cancel_ongoing_animations"]?.bool == true { cancelAnimations(mapView) }

    switch name {
    case "rotate_from":
      guard let degree = args["degree"]?.number else {
        throw RufletMapInvocationError.missingArgument("degree")
      }
      let camera = mapView.camera
      camera.heading += degree
      setCamera(camera, on: mapView, duration: duration)
    case "reset_rotation":
      let camera = mapView.camera
      camera.heading = 0
      setCamera(camera, on: mapView, duration: duration)
    case "zoom_in":
      setZoom(rufletZoomLevel(for: mapView.region) + 1, on: mapView, duration: duration)
    case "zoom_out":
      setZoom(rufletZoomLevel(for: mapView.region) - 1, on: mapView, duration: duration)
    case "zoom_to":
      guard let zoom = args["zoom"]?.number else {
        throw RufletMapInvocationError.missingArgument("zoom")
      }
      setZoom(zoom, on: mapView, duration: duration)
    case "move_to":
      let destination = rufletMapCoordinate(args["destination"])
      let zoom = args["zoom"]?.number
      let rotation = args["rotation"]?.number
      move(
        mapView,
        center: destination?.mapKit,
        zoom: zoom,
        rotation: rotation,
        offset: rufletOffset(args["offset"]),
        duration: duration)
    case "center_on":
      guard let point = rufletMapCoordinate(args["point"]) else {
        throw RufletMapInvocationError.missingArgument("point")
      }
      move(
        mapView, center: point.mapKit, zoom: args["zoom"]?.number,
        rotation: nil, offset: .zero, duration: duration)
    default:
      throw RufletMapInvocationError.unknownMethod(name)
    }
    return .null
  }

  private func setZoom(_ zoom: Double, on mapView: MKMapView, duration: TimeInterval) {
    let minimum = control.number("min_zoom") ?? -.infinity
    let maximum = control.number("max_zoom") ?? .infinity
    let region = rufletRegion(center: mapView.centerCoordinate, zoom: min(max(zoom, minimum), maximum))
    performAnimation(duration: duration) { mapView.setRegion(region, animated: duration > 0) }
  }

  private func move(
    _ mapView: MKMapView,
    center: CLLocationCoordinate2D?,
    zoom: Double?,
    rotation: Double?,
    offset: CGPoint,
    duration: TimeInterval
  ) {
    var destination = center ?? mapView.centerCoordinate
    if offset != .zero, mapView.bounds.width > 0, mapView.bounds.height > 0 {
      let centerPoint = CGPoint(
        x: mapView.bounds.midX - offset.x,
        y: mapView.bounds.midY - offset.y)
      let offsetCoordinate = mapView.convert(centerPoint, toCoordinateFrom: mapView)
      destination.latitude += destination.latitude - offsetCoordinate.latitude
      destination.longitude += destination.longitude - offsetCoordinate.longitude
    }
    if let zoom {
      performAnimation(duration: duration) {
        mapView.setRegion(rufletRegion(center: destination, zoom: zoom), animated: duration > 0)
      }
    } else {
      performAnimation(duration: duration) { mapView.setCenter(destination, animated: duration > 0) }
    }
    if let rotation {
      let camera = mapView.camera
      camera.heading = rotation
      setCamera(camera, on: mapView, duration: duration)
    }
  }

  private func setCamera(_ camera: MKMapCamera, on mapView: MKMapView, duration: TimeInterval) {
    performAnimation(duration: duration) { mapView.setCamera(camera, animated: duration > 0) }
  }

  private func performAnimation(duration: TimeInterval, changes: () -> Void) {
    CATransaction.begin()
    CATransaction.setAnimationDuration(max(duration, 0))
    changes()
    CATransaction.commit()
  }

  private func cancelAnimations(_ mapView: MKMapView) {
    #if os(iOS)
    mapView.layer.removeAllAnimations()
    #elseif os(macOS)
    mapView.layer?.removeAllAnimations()
    #endif
  }

  private func rufletOffset(_ value: RufletValue?) -> CGPoint {
    guard let map = rufletStringMap(value) else { return .zero }
    return CGPoint(x: map["x"]?.number ?? 0, y: map["y"]?.number ?? 0)
  }
}

private final class RufletMarkerAnnotation: NSObject, MKAnnotation {
  dynamic var coordinate: CLLocationCoordinate2D
  let descriptor: RufletMarkerDescriptor

  init(_ descriptor: RufletMarkerDescriptor) {
    self.descriptor = descriptor
    coordinate = descriptor.coordinate.mapKit
  }
}

private final class RufletLabelAnnotation: NSObject, MKAnnotation {
  dynamic var coordinate: CLLocationCoordinate2D
  let text: String
  let style: RufletTextStyle?
  let rotatesWithMap: Bool

  init(coordinate: CLLocationCoordinate2D, text: String, style: RufletTextStyle?, rotatesWithMap: Bool) {
    self.coordinate = coordinate
    self.text = text
    self.style = style
    self.rotatesWithMap = rotatesWithMap
  }
}

private final class RufletPointCircleOverlay: NSObject, MKOverlay {
  let coordinate: CLLocationCoordinate2D
  let radius: CGFloat
  let boundingMapRect = MKMapRect.world

  init(coordinate: CLLocationCoordinate2D, radius: CGFloat) {
    self.coordinate = coordinate
    self.radius = radius
  }
}

private enum RufletOverlayStyle {
  case tile(RufletTileDisplay)
  case circle(fill: RufletPlatformColor, stroke: RufletPlatformColor, width: CGFloat)
  case polygon(fill: RufletPlatformColor, stroke: RufletPlatformColor, width: CGFloat, cap: CGLineCap, join: CGLineJoin)
  case polyline(
    color: RufletPlatformColor, width: CGFloat, pattern: RufletStrokePattern,
    cap: CGLineCap, join: CGLineJoin, usesMeters: Bool,
    gradient: [RufletPlatformColor], stops: [Double])
}

private final class RufletPointCircleRenderer: MKOverlayRenderer {
  let style: RufletOverlayStyle

  init(overlay: MKOverlay, style: RufletOverlayStyle) {
    self.style = style
    super.init(overlay: overlay)
  }

  override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
    guard let circle = overlay as? RufletPointCircleOverlay,
          case .circle(let fill, let stroke, let width) = style
    else { return }
    let center = point(for: MKMapPoint(circle.coordinate))
    let rect = CGRect(
      x: center.x - circle.radius, y: center.y - circle.radius,
      width: circle.radius * 2, height: circle.radius * 2)
    context.setFillColor(fill.cgColor)
    context.fillEllipse(in: rect)
    if width > 0 {
      context.setStrokeColor(stroke.cgColor)
      context.setLineWidth(width)
      context.strokeEllipse(in: rect.insetBy(dx: width / 2, dy: width / 2))
    }
  }
}

#if os(iOS)
private final class RufletHostingAnnotationView: MKAnnotationView {
  var host: UIHostingController<AnyView>?
}
#elseif os(macOS)
private final class RufletHostingAnnotationView: MKAnnotationView {
  var host: NSHostingView<AnyView>?
}
#endif

@MainActor
private final class RufletMapCoordinator: NSObject, MKMapViewDelegate {
  let control: RufletControl
  let controller: RufletMapController
  private var configuredInitialCamera = false
  private var sentReady = false
  private var overlayStyles: [ObjectIdentifier: RufletOverlayStyle] = [:]

  init(control: RufletControl, controller: RufletMapController) {
    self.control = control
    self.controller = controller
  }

  func install(on mapView: MKMapView) {
    controller.mapView = mapView
    mapView.delegate = self
    installGestures(on: mapView)
    reconcile(mapView)
  }

  func update(_ mapView: MKMapView) {
    controller.mapView = mapView
    configureInteraction(mapView)
    configureZoomRange(mapView)
    if !configuredInitialCamera { configureInitialCamera(mapView) }
    reconcile(mapView)
    if !sentReady {
      sentReady = true
      if control.hasEventHandler("init") { control.triggerEvent("init") }
    }
  }

  private func configureInteraction(_ mapView: MKMapView) {
    let interaction = rufletMapInteraction(control.value("interaction_configuration"))
    mapView.isScrollEnabled = interaction.scrollEnabled
    mapView.isZoomEnabled = interaction.zoomEnabled
    mapView.isRotateEnabled = interaction.rotateEnabled
    mapView.isPitchEnabled = interaction.pitchEnabled
  }

  private func configureZoomRange(_ mapView: MKMapView) {
    let minimumZoom = control.number("min_zoom")
    let maximumZoom = control.number("max_zoom")
    guard minimumZoom != nil || maximumZoom != nil else {
      mapView.cameraZoomRange = nil
      return
    }
    let circumference = 40_075_016.686
    let minimumDistance = maximumZoom.map { circumference / pow(2, $0) }
    let maximumDistance = minimumZoom.map { circumference / pow(2, $0) }
    if let minimumDistance, let maximumDistance {
      mapView.cameraZoomRange = MKMapView.CameraZoomRange(
        minCenterCoordinateDistance: minimumDistance,
        maxCenterCoordinateDistance: maximumDistance)
    } else if let minimumDistance {
      mapView.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: minimumDistance)
    } else if let maximumDistance {
      mapView.cameraZoomRange = MKMapView.CameraZoomRange(maxCenterCoordinateDistance: maximumDistance)
    }
  }

  private func configureInitialCamera(_ mapView: MKMapView) {
    configuredInitialCamera = true
    if let fit = rufletStringMap(control.value("initial_camera_fit")),
       applyCameraFit(fit, to: mapView) {
      return
    }
    let center = rufletMapCoordinate(
      control.value("initial_center"),
      default: RufletMapCoordinate(latitude: 50.5, longitude: 30.51))!
    mapView.setRegion(
      rufletRegion(center: center.mapKit, zoom: control.number("initial_zoom", default: 13) ?? 13),
      animated: false)
    let camera = mapView.camera
    camera.heading = control.number("initial_rotation", default: 0) ?? 0
    mapView.setCamera(camera, animated: false)
  }

  private func applyCameraFit(_ fit: [String: RufletValue], to mapView: MKMapView) -> Bool {
    let mapRect: MKMapRect?
    if let bounds = rufletMapBounds(fit["bounds"]) {
      mapRect = bounds.mapRect
    } else {
      let points = rufletMapCoordinates(fit["coordinates"])
      mapRect = points.reduce(nil as MKMapRect?) { result, coordinate in
        let point = MKMapPoint(coordinate.mapKit)
        let rect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
        return result?.union(rect) ?? rect
      }
    }
    guard let mapRect else { return false }
    let padding = rufletEdgeInsets(fit["padding"])
    mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: false)
    return true
  }

  private func reconcile(_ mapView: MKMapView) {
    mapView.removeAnnotations(mapView.annotations)
    mapView.removeOverlays(mapView.overlays)
    overlayStyles.removeAll(keepingCapacity: true)

    for layer in control.children("layers", visibleOnly: false) where layer.visible {
      layer.notifyParent = true
      switch layer.type {
      case "TileLayer": addTile(layer, to: mapView)
      case "CircleLayer": addCircles(layer, to: mapView)
      case "MarkerLayer": addMarkers(layer, to: mapView)
      case "PolygonLayer": addPolygons(layer, to: mapView)
      case "PolylineLayer": addPolylines(layer, to: mapView)
      default: break
      }
    }
  }

  private func addTile(_ control: RufletControl, to mapView: MKMapView) {
    let descriptor = rufletTileDescriptor(control)
    guard descriptor.urlTemplate != nil else { return }
    let overlay = RufletTileOverlay(descriptor: descriptor)
    overlayStyles[ObjectIdentifier(overlay)] = .tile(descriptor.display)
    mapView.addOverlay(overlay, level: .aboveRoads)
  }

  private func addCircles(_ layer: RufletControl, to mapView: MKMapView) {
    for item in rufletCircleDescriptors(layer) {
      let overlay: MKOverlay
      if item.usesMeters {
        overlay = MKCircle(center: item.coordinate.mapKit, radius: max(item.radius, 0))
      } else {
        overlay = RufletPointCircleOverlay(
          coordinate: item.coordinate.mapKit, radius: max(item.radius, 0))
      }
      overlayStyles[ObjectIdentifier(overlay as AnyObject)] = .circle(
        fill: rufletPlatformColor(item.color),
        stroke: rufletPlatformColor(item.borderColor),
        width: item.borderWidth)
      mapView.addOverlay(overlay, level: .aboveLabels)
    }
  }

  private func addMarkers(_ layer: RufletControl, to mapView: MKMapView) {
    mapView.addAnnotations(rufletMarkerDescriptors(layer).map(RufletMarkerAnnotation.init))
  }

  private func addPolygons(_ layer: RufletControl, to mapView: MKMapView) {
    for item in rufletPolygonDescriptors(layer) {
      var coordinates = item.coordinates.map(\.mapKit)
      let overlay = MKPolygon(coordinates: &coordinates, count: coordinates.count)
      overlayStyles[ObjectIdentifier(overlay)] = .polygon(
        fill: rufletPlatformColor(item.fillColor),
        stroke: rufletPlatformColor(item.borderColor),
        width: item.borderWidth, cap: item.lineCap, join: item.lineJoin)
      mapView.addOverlay(overlay, level: .aboveLabels)
      if let label = item.label {
        let center = polygonCentroid(item.coordinates)
        mapView.addAnnotation(RufletLabelAnnotation(
          coordinate: center.mapKit, text: label,
          style: item.labelStyle, rotatesWithMap: item.rotatesLabel))
      }
    }
  }

  private func addPolylines(_ layer: RufletControl, to mapView: MKMapView) {
    for item in rufletPolylineDescriptors(layer) {
      var coordinates = item.coordinates.map(\.mapKit)
      if item.borderWidth > 0 {
        let border = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        overlayStyles[ObjectIdentifier(border)] = .polyline(
          color: rufletPlatformColor(item.borderColor),
          width: item.strokeWidth + item.borderWidth * 2,
          pattern: item.pattern, cap: item.lineCap, join: item.lineJoin,
          usesMeters: item.usesMeters, gradient: [], stops: [])
        mapView.addOverlay(border, level: .aboveLabels)
      }
      let line = MKPolyline(coordinates: &coordinates, count: coordinates.count)
      overlayStyles[ObjectIdentifier(line)] = .polyline(
        color: rufletPlatformColor(item.color), width: item.strokeWidth,
        pattern: item.pattern, cap: item.lineCap, join: item.lineJoin,
        usesMeters: item.usesMeters,
        gradient: item.gradientColors.map(rufletPlatformColor), stops: item.gradientStops)
      mapView.addOverlay(line, level: .aboveLabels)
    }
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let style = overlayStyles[ObjectIdentifier(overlay as AnyObject)] else {
      preconditionFailure("Missing MapKit renderer style for \(type(of: overlay))")
    }
    switch style {
    case .tile(let display):
      let renderer = MKTileOverlayRenderer(tileOverlay: overlay as! MKTileOverlay)
      renderer.alpha = display.initialOpacity
      if display.duration > 0 {
        DispatchQueue.main.async {
          CATransaction.begin()
          CATransaction.setAnimationDuration(display.duration)
          renderer.alpha = 1
          CATransaction.commit()
        }
      }
      return renderer
    case .circle(let fill, let stroke, let width):
      if let circle = overlay as? MKCircle {
        let renderer = MKCircleRenderer(circle: circle)
        renderer.fillColor = fill
        renderer.strokeColor = stroke
        renderer.lineWidth = width
        return renderer
      }
      return RufletPointCircleRenderer(overlay: overlay, style: style)
    case .polygon(let fill, let stroke, let width, let cap, let join):
      let renderer = MKPolygonRenderer(polygon: overlay as! MKPolygon)
      renderer.fillColor = fill
      renderer.strokeColor = stroke
      renderer.lineWidth = width
      renderer.lineCap = cap
      renderer.lineJoin = join
      return renderer
    case .polyline(let color, let width, let pattern, let cap, let join, let usesMeters, let gradient, let stops):
      let renderer: MKPolylineRenderer
      if !gradient.isEmpty {
        let gradientRenderer = MKGradientPolylineRenderer(polyline: overlay as! MKPolyline)
        let locations: [CGFloat]
        if stops.count == gradient.count {
          locations = stops.map { CGFloat($0) }
        } else if gradient.count == 1 {
          locations = [0]
        } else {
          locations = gradient.indices.map { CGFloat($0) / CGFloat(gradient.count - 1) }
        }
        gradientRenderer.setColors(gradient, locations: locations)
        renderer = gradientRenderer
      } else {
        renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.strokeColor = color
      }
      renderer.lineWidth = usesMeters ? points(forMeters: width, on: mapView) : width
      renderer.lineDashPattern = pattern.dashPattern
      renderer.lineCap = cap
      renderer.lineJoin = join
      return renderer
    }
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if let marker = annotation as? RufletMarkerAnnotation {
      return markerView(marker, mapView: mapView)
    }
    if let label = annotation as? RufletLabelAnnotation {
      return labelView(label, mapView: mapView)
    }
    return nil
  }

  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    reportMapEvent(mapView, source: hasActiveGesture(mapView) ? "gesture" : "mapController")
  }

  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    let gesture = hasActiveGesture(mapView)
    if control.hasEventHandler("position_change") {
      control.triggerEvent("position_change", data: .map([
        "coordinates": RufletMapCoordinate(
          latitude: mapView.centerCoordinate.latitude,
          longitude: mapView.centerCoordinate.longitude).value,
        "has_gesture": .bool(gesture),
        "camera": rufletCameraValue(mapView),
      ]))
    }
    reportMapEvent(mapView, source: gesture ? "gesture" : "mapController")
    updateAnnotationRotation(mapView)
  }

  private func reportMapEvent(_ mapView: MKMapView, source: String) {
    guard control.hasEventHandler("event") else { return }
    control.triggerEvent("event", data: .map([
      "source": .string(source), "camera": rufletCameraValue(mapView),
    ]))
  }

  private func hasActiveGesture(_ mapView: MKMapView) -> Bool {
    #if os(iOS)
    return mapView.gestureRecognizers?.contains {
      $0.state == .began || $0.state == .changed
    } == true
    #elseif os(macOS)
    return mapView.gestureRecognizers.contains {
      $0.state == .began || $0.state == .changed
    }
    #endif
  }

  private func points(forMeters meters: Double, on mapView: MKMapView) -> CGFloat {
    guard mapView.bounds.width > 0 else { return CGFloat(meters) }
    let metersPerMapPoint = MKMetersPerMapPointAtLatitude(mapView.centerCoordinate.latitude)
    let mapPointsPerPoint = mapView.visibleMapRect.width / mapView.bounds.width
    return CGFloat(meters / max(metersPerMapPoint * mapPointsPerPoint, 0.000_001))
  }

  private func polygonCentroid(_ coordinates: [RufletMapCoordinate]) -> RufletMapCoordinate {
    RufletMapCoordinate(
      latitude: coordinates.reduce(0) { $0 + $1.latitude } / Double(coordinates.count),
      longitude: coordinates.reduce(0) { $0 + $1.longitude } / Double(coordinates.count))
  }

  private func updateAnnotationRotation(_ mapView: MKMapView) {
    for annotation in mapView.annotations {
      let rotates = (annotation as? RufletMarkerAnnotation)?.descriptor.rotatesWithMap
        ?? (annotation as? RufletLabelAnnotation)?.rotatesWithMap
        ?? false
      guard rotates, let view = mapView.view(for: annotation) else { continue }
      #if os(iOS)
      view.transform = CGAffineTransform(rotationAngle: mapView.camera.heading * .pi / 180)
      #elseif os(macOS)
      view.layer?.setAffineTransform(CGAffineTransform(rotationAngle: mapView.camera.heading * .pi / 180))
      #endif
    }
  }

  #if os(iOS)
  private func markerView(_ annotation: RufletMarkerAnnotation, mapView: MKMapView) -> MKAnnotationView {
    let reuse = "RufletMarker"
    let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuse) as? RufletHostingAnnotationView
      ?? RufletHostingAnnotationView(annotation: annotation, reuseIdentifier: reuse)
    view.annotation = annotation
    view.frame.size = CGSize(width: annotation.descriptor.width, height: annotation.descriptor.height)
    view.centerOffset = CGPoint(
      x: -annotation.descriptor.alignment.x * annotation.descriptor.width / 2,
      y: -annotation.descriptor.alignment.y * annotation.descriptor.height / 2)
    view.subviews.forEach { $0.removeFromSuperview() }
    let content = annotation.descriptor.control.buildWidget("content")
      ?? AnyView(Text("Marker content is required").foregroundStyle(.red))
    let host = UIHostingController(rootView: content)
    host.view.backgroundColor = .clear
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(host.view)
    view.host = host
    return view
  }

  private func labelView(_ annotation: RufletLabelAnnotation, mapView: MKMapView) -> MKAnnotationView {
    let reuse = "RufletPolygonLabel"
    let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuse) as? RufletHostingAnnotationView
      ?? RufletHostingAnnotationView(annotation: annotation, reuseIdentifier: reuse)
    view.annotation = annotation
    view.subviews.forEach { $0.removeFromSuperview() }
    let text = AnyView(Text(annotation.text)
      .font(.system(size: annotation.style?.size ?? 12, weight: annotation.style?.weight ?? .regular))
      .foregroundStyle(annotation.style?.color ?? .primary)
      .padding(3))
    let host = UIHostingController(rootView: text)
    let size = host.sizeThatFits(in: CGSize(width: 320, height: 100))
    view.frame.size = size
    host.view.backgroundColor = .clear
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(host.view)
    view.host = host
    return view
  }
  #elseif os(macOS)
  private func markerView(_ annotation: RufletMarkerAnnotation, mapView: MKMapView) -> MKAnnotationView {
    let reuse = "RufletMarker"
    let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuse) as? RufletHostingAnnotationView
      ?? RufletHostingAnnotationView(annotation: annotation, reuseIdentifier: reuse)
    view.annotation = annotation
    view.frame.size = CGSize(width: annotation.descriptor.width, height: annotation.descriptor.height)
    view.centerOffset = CGPoint(
      x: -annotation.descriptor.alignment.x * annotation.descriptor.width / 2,
      y: -annotation.descriptor.alignment.y * annotation.descriptor.height / 2)
    view.subviews.forEach { $0.removeFromSuperview() }
    let content = annotation.descriptor.control.buildWidget("content")
      ?? AnyView(Text("Marker content is required").foregroundStyle(.red))
    let host = NSHostingView(rootView: content)
    host.frame = view.bounds
    host.autoresizingMask = [.width, .height]
    view.addSubview(host)
    view.host = host
    return view
  }

  private func labelView(_ annotation: RufletLabelAnnotation, mapView: MKMapView) -> MKAnnotationView {
    let reuse = "RufletPolygonLabel"
    let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuse) as? RufletHostingAnnotationView
      ?? RufletHostingAnnotationView(annotation: annotation, reuseIdentifier: reuse)
    view.annotation = annotation
    view.subviews.forEach { $0.removeFromSuperview() }
    let content = AnyView(Text(annotation.text)
      .font(.system(size: annotation.style?.size ?? 12, weight: annotation.style?.weight ?? .regular))
      .foregroundStyle(annotation.style?.color ?? .primary)
      .padding(3))
    let host = NSHostingView(rootView: content)
    host.frame.size = host.fittingSize
    view.frame.size = host.fittingSize
    host.autoresizingMask = [.width, .height]
    view.addSubview(host)
    view.host = host
    return view
  }
  #endif

  #if os(iOS)
  private func rufletEdgeInsets(_ value: RufletValue?) -> UIEdgeInsets {
    guard let map = rufletStringMap(value) else { return .zero }
    return UIEdgeInsets(
      top: map["top"]?.number ?? 0,
      left: map["left"]?.number ?? 0,
      bottom: map["bottom"]?.number ?? 0,
      right: map["right"]?.number ?? 0)
  }
  #elseif os(macOS)
  private func rufletEdgeInsets(_ value: RufletValue?) -> NSEdgeInsets {
    guard let map = rufletStringMap(value) else {
      return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    return NSEdgeInsets(
      top: map["top"]?.number ?? 0,
      left: map["left"]?.number ?? 0,
      bottom: map["bottom"]?.number ?? 0,
      right: map["right"]?.number ?? 0)
  }
  #endif

  #if os(iOS)
  private func installGestures(on mapView: MKMapView) {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tap.cancelsTouchesInView = false
    mapView.addGestureRecognizer(tap)

    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    longPress.minimumPressDuration = 0.5
    longPress.cancelsTouchesInView = false
    mapView.addGestureRecognizer(longPress)

    let pointer = UILongPressGestureRecognizer(target: self, action: #selector(handlePointer(_:)))
    pointer.minimumPressDuration = 0
    pointer.cancelsTouchesInView = false
    mapView.addGestureRecognizer(pointer)

    if #available(iOS 13.4, *) {
      let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
      mapView.addGestureRecognizer(hover)
      let secondary = UITapGestureRecognizer(target: self, action: #selector(handleSecondaryTap(_:)))
      secondary.buttonMaskRequired = .secondary
      secondary.cancelsTouchesInView = false
      mapView.addGestureRecognizer(secondary)
    }
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    guard gesture.state == .ended, control.hasEventHandler("tap"), let map = gesture.view as? MKMapView else { return }
    reportPoint("tap", gesture.location(in: map), map: map)
  }

  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began, control.hasEventHandler("long_press"), let map = gesture.view as? MKMapView else { return }
    reportPoint("long_press", gesture.location(in: map), map: map)
  }

  @objc private func handlePointer(_ gesture: UILongPressGestureRecognizer) {
    guard let map = gesture.view as? MKMapView else { return }
    let name: String?
    switch gesture.state {
    case .began: name = "pointer_down"
    case .ended: name = "pointer_up"
    case .cancelled, .failed: name = "pointer_cancel"
    default: name = nil
    }
    if let name, control.hasEventHandler(name) { reportPoint(name, gesture.location(in: map), map: map) }
  }

  @available(iOS 13.4, *)
  @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
    guard control.hasEventHandler("hover"), let map = gesture.view as? MKMapView else { return }
    reportPoint("hover", gesture.location(in: map), map: map)
  }

  @available(iOS 13.4, *)
  @objc private func handleSecondaryTap(_ gesture: UITapGestureRecognizer) {
    guard gesture.state == .ended, control.hasEventHandler("secondary_tap"), let map = gesture.view as? MKMapView else { return }
    reportPoint("secondary_tap", gesture.location(in: map), map: map)
  }
  #elseif os(macOS)
  private func installGestures(on mapView: MKMapView) {
    let tap = NSClickGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tap.buttonMask = 0x1
    mapView.addGestureRecognizer(tap)
    let secondary = NSClickGestureRecognizer(target: self, action: #selector(handleSecondaryTap(_:)))
    secondary.buttonMask = 0x2
    mapView.addGestureRecognizer(secondary)
    let longPress = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    longPress.minimumPressDuration = 0.5
    mapView.addGestureRecognizer(longPress)
    let pointer = NSPressGestureRecognizer(target: self, action: #selector(handlePointer(_:)))
    pointer.minimumPressDuration = 0
    mapView.addGestureRecognizer(pointer)
    if let trackingMap = mapView as? RufletTrackingMapView {
      trackingMap.onMouseMoved = { [weak self, weak trackingMap] point in
        guard let self, let trackingMap, self.control.hasEventHandler("hover") else { return }
        self.reportPoint("hover", point, map: trackingMap)
      }
    }
  }

  @objc private func handleTap(_ gesture: NSClickGestureRecognizer) {
    guard gesture.state == .ended, control.hasEventHandler("tap"), let map = gesture.view as? MKMapView else { return }
    reportPoint("tap", gesture.location(in: map), map: map)
  }

  @objc private func handleSecondaryTap(_ gesture: NSClickGestureRecognizer) {
    guard gesture.state == .ended, control.hasEventHandler("secondary_tap"), let map = gesture.view as? MKMapView else { return }
    reportPoint("secondary_tap", gesture.location(in: map), map: map)
  }

  @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
    guard gesture.state == .began, control.hasEventHandler("long_press"), let map = gesture.view as? MKMapView else { return }
    reportPoint("long_press", gesture.location(in: map), map: map)
  }

  @objc private func handlePointer(_ gesture: NSPressGestureRecognizer) {
    guard let map = gesture.view as? MKMapView else { return }
    let name: String?
    switch gesture.state {
    case .began: name = "pointer_down"
    case .ended: name = "pointer_up"
    case .cancelled, .failed: name = "pointer_cancel"
    default: name = nil
    }
    if let name, control.hasEventHandler(name) { reportPoint(name, gesture.location(in: map), map: map) }
  }

  #endif

  private func reportPoint(_ name: String, _ point: CGPoint, map: MKMapView) {
    control.triggerEvent(name, data: rufletPointValue(
      point, coordinate: map.convert(point, toCoordinateFrom: map)))
  }
}

#if os(iOS)
private struct RufletMapSurface: UIViewRepresentable {
  let control: RufletControl
  let controller: RufletMapController

  func makeCoordinator() -> RufletMapCoordinator {
    RufletMapCoordinator(control: control, controller: controller)
  }

  func makeUIView(context: Context) -> MKMapView {
    let view = MKMapView(frame: .zero)
    context.coordinator.install(on: view)
    return view
  }

  func updateUIView(_ view: MKMapView, context: Context) {
    context.coordinator.update(view)
  }
}
#elseif os(macOS)
@MainActor
private final class RufletTrackingMapView: MKMapView {
  var onMouseMoved: ((CGPoint) -> Void)?
  private var hoverTrackingArea: NSTrackingArea?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
      owner: self,
      userInfo: nil)
    addTrackingArea(area)
    hoverTrackingArea = area
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
    onMouseMoved?(convert(event.locationInWindow, from: nil))
  }
}

private struct RufletMapSurface: NSViewRepresentable {
  let control: RufletControl
  let controller: RufletMapController

  func makeCoordinator() -> RufletMapCoordinator {
    RufletMapCoordinator(control: control, controller: controller)
  }

  func makeNSView(context: Context) -> MKMapView {
    let view = RufletTrackingMapView(frame: .zero)
    context.coordinator.install(on: view)
    return view
  }

  func updateNSView(_ view: MKMapView, context: Context) {
    context.coordinator.update(view)
  }
}
#endif
