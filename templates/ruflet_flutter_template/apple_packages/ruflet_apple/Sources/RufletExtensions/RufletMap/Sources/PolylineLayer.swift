import RufletEngine
import SwiftUI

struct RufletPolylineDescriptor {
  let control: RufletControl
  let coordinates: [RufletMapCoordinate]
  let borderWidth: Double
  let borderColor: Color
  let color: Color
  let pattern: RufletStrokePattern
  let lineCap: CGLineCap
  let lineJoin: CGLineJoin
  let strokeWidth: Double
  let usesMeters: Bool
  let gradientStops: [Double]
  let gradientColors: [Color]
  let cullingMargin: Double
  let minimumHittableRadius: Double
  let simplificationTolerance: Double
}

@MainActor
func rufletPolylineDescriptors(_ layer: RufletControl) -> [RufletPolylineDescriptor] {
  let cullingMargin = layer.number("culling_margin", default: 10) ?? 10
  let minimumHittableRadius = layer.number("min_hittable_radius", default: 10) ?? 10
  let simplificationTolerance = layer.number("simplification_tolerance", default: 0.3) ?? 0.3
  return layer.children("polylines", visibleOnly: false).compactMap {
    polyline -> RufletPolylineDescriptor? in
    guard polyline.type == "PolylineMarker" else { return nil }
    let points = rufletMapCoordinates(polyline.value("coordinates"))
    guard points.count >= 2 else { return nil }
    polyline.notifyParent = true
    return RufletPolylineDescriptor(
      control: polyline,
      coordinates: points,
      borderWidth: polyline.number("border_stroke_width", default: 0) ?? 0,
      borderColor: rufletMapColor(polyline.string("border_color"), default: .yellow),
      color: rufletMapColor(polyline.string("color"), default: .yellow),
      pattern: rufletStrokePattern(polyline.value("stroke_pattern")),
      lineCap: rufletLineCap(polyline.string("stroke_cap")),
      lineJoin: rufletLineJoin(polyline.string("stroke_join")),
      strokeWidth: polyline.number("stroke_width", default: 1) ?? 1,
      usesMeters: polyline.boolean("use_stroke_width_in_meter", default: false),
      gradientStops: polyline.value("colors_stop")?.array?.compactMap(\.number) ?? [],
      gradientColors: polyline.value("gradient_colors")?.array?.compactMap {
        guard let value = $0.text else { return nil }
        return parseColor(value)
      } ?? [],
      cullingMargin: cullingMargin,
      minimumHittableRadius: minimumHittableRadius,
      simplificationTolerance: simplificationTolerance)
  }
}

struct PolylineLayerControl: View {
  @ObservedObject var control: RufletControl
  var body: some View { EmptyView() }
}
