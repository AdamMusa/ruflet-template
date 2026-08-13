import RufletEngine

@MainActor
public struct RufletGeolocatorExtension: RufletExtension {
  public init() {}

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "Geolocator" ? GeolocatorService(control: control) : nil
  }
}
