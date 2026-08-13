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
}

@MainActor
func rufletPolygonDescriptors(_ layer: RufletControl) -> [RufletPolygonDescriptor] {
  layer.children("polygons", visibleOnly: false).compactMap { polygon in
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
      lineJoin: rufletLineJoin(polygon.string("stroke_join")))
  }
}

struct PolygonLayerControl: View {
  @ObservedObject var control: RufletControl
  var body: some View { EmptyView() }
}
