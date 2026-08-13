import RufletEngine
import SwiftUI

@MainActor
public struct Extension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { RufletMapPackage.renderedControlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    switch control.type {
    case "Map": AnyView(MapControl(control: control))
    case "RichAttribution": AnyView(RichAttributionControl(control: control))
    case "SimpleAttribution": AnyView(SimpleAttributionControl(control: control))
    case "TileLayer": AnyView(TileLayerControl(control: control))
    case "MarkerLayer": AnyView(MarkerLayerControl(control: control))
    case "CircleLayer": AnyView(CircleLayerControl(control: control))
    case "PolygonLayer": AnyView(PolygonLayerControl(control: control))
    case "PolylineLayer": AnyView(PolylineLayerControl(control: control))
    default: nil
    }
  }
}
