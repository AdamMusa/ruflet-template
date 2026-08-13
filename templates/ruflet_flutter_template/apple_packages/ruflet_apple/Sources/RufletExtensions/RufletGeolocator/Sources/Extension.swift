import RufletEngine

@MainActor
public struct RufletGeolocatorExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { [] }
  public var serviceControlTypes: Set<String> { RufletGeolocator.controlTypes }

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "Geolocator" ? GeolocatorService(control: control) : nil
  }
}
