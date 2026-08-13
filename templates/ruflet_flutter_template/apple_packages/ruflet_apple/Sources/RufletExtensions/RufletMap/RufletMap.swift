import RufletEngine

public enum RufletMapPackage {
  public static let packageName = "ruflet_map"
  public static let renderedControlTypes: Set<String> = [
    "Map", "RichAttribution", "SimpleAttribution", "TileLayer",
    "MarkerLayer", "CircleLayer", "PolygonLayer", "PolylineLayer",
  ]
}

public typealias RufletMapExtension = Extension
