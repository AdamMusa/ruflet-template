import MapKit
import RufletEngine
import SwiftUI

struct RufletCircleDescriptor {
  let id: Int
  let coordinate: RufletMapCoordinate
  let color: Color
  let borderColor: Color
  let borderWidth: Double
  let radius: Double
  let usesMeters: Bool
}

@MainActor
func rufletCircleDescriptors(_ layer: RufletControl) -> [RufletCircleDescriptor] {
  layer.children("circles", visibleOnly: false).compactMap { circle in
    guard circle.type == "CircleMarker",
          let coordinate = rufletMapCoordinate(circle.value("coordinates"))
    else { return nil }
    circle.notifyParent = true
    return RufletCircleDescriptor(
      id: circle.id,
      coordinate: coordinate,
      color: rufletMapColor(circle.string("color"), default: .green),
      borderColor: rufletMapColor(circle.string("border_color"), default: .yellow),
      borderWidth: circle.number("border_stroke_width", default: 0) ?? 0,
      radius: circle.number("radius", default: 10) ?? 10,
      usesMeters: circle.boolean("use_radius_in_meter", default: false))
  }
}

struct CircleLayerControl: View {
  @ObservedObject var control: RufletControl
  var body: some View { EmptyView() }
}
