import RufletEngine
import SwiftUI

struct RufletPolygonDescriptor {
  let control: RufletControl
  let coordinates: [RufletMapCoordinate]
  let borderWidth: Double
  let borderColor: Color
  let fillColor: Color
  let label: String?
  let labelStyle: RufletTextStyle?
  let rotatesLabel: Bool
  let lineCap: CGLineCap
  let lineJoin: CGLineJoin
  let polygonCulling: Bool
  let polygonLabels: Bool
  let drawLabelsLast: Bool
  let simplificationTolerance: Double
  let useAlternativeRendering: Bool
}

@MainActor
func rufletPolygonDescriptors(_ layer: RufletControl) -> [RufletPolygonDescriptor] {
  let polygonCulling = layer.boolean("polygon_culling", default: true)
  let polygonLabels = layer.boolean("polygon_labels", default: true)
  let drawLabelsLast = layer.boolean("draw_labels_last", default: false)
  let simplificationTolerance = layer.number("simplification_tolerance", default: 0.3) ?? 0.3
  let useAlternativeRendering = layer.boolean("use_alternative_rendering", default: false)
  return layer.children("polygons", visibleOnly: false).compactMap {
    polygon -> RufletPolygonDescriptor? in
    guard polygon.type == "PolygonMarker" else { return nil }
    let points = rufletMapCoordinates(polygon.value("coordinates"))
    guard points.count >= 3 else { return nil }
    polygon.notifyParent = true
    return RufletPolygonDescriptor(
      control: polygon,
      coordinates: points,
      borderWidth: polygon.number("border_stroke_width", default: 0) ?? 0,
      borderColor: rufletMapColor(polygon.string("border_color"), default: .green),
      fillColor: rufletMapColor(polygon.string("color"), default: .green),
      label: polygon.string("label"),
      labelStyle: parseTextStyle(polygon.value("label_text_style")),
      rotatesLabel: polygon.boolean("rotate_label", default: false),
      lineCap: rufletLineCap(polygon.string("stroke_cap")),
      lineJoin: rufletLineJoin(polygon.string("stroke_join")),
      polygonCulling: polygonCulling,
      polygonLabels: polygonLabels,
      drawLabelsLast: drawLabelsLast,
      simplificationTolerance: simplificationTolerance,
      useAlternativeRendering: useAlternativeRendering)
  }
}

struct PolygonLayerControl: View {
  @ObservedObject var control: RufletControl
  var body: some View { EmptyView() }
}
