import RufletEngine
import SwiftUI

struct RufletMarkerDescriptor {
  let control: RufletControl
  let coordinate: RufletMapCoordinate
  let rotatesWithMap: Bool
  let width: Double
  let height: Double
  let alignment: RufletAlignment
}

@MainActor
func rufletMarkerDescriptors(_ layer: RufletControl) -> [RufletMarkerDescriptor] {
  let layerRotation = layer.boolean("rotate", default: false)
  let layerAlignment = parseAlignment(layer.value("alignment"), RufletAlignment(x: 0, y: 0))!
  return layer.children("markers", visibleOnly: false).compactMap { marker in
    guard marker.type == "Marker",
          let coordinate = rufletMapCoordinate(marker.value("coordinates"))
    else { return nil }
    marker.notifyParent = true
    return RufletMarkerDescriptor(
      control: marker,
      coordinate: coordinate,
      rotatesWithMap: marker.boolean("rotate") ?? layerRotation,
      width: marker.number("width", default: 30) ?? 30,
      height: marker.number("height", default: 30) ?? 30,
      alignment: parseAlignment(marker.value("alignment"), layerAlignment) ?? layerAlignment)
  }
}

struct MarkerLayerControl: View {
  @ObservedObject var control: RufletControl
  var body: some View { EmptyView() }
}
