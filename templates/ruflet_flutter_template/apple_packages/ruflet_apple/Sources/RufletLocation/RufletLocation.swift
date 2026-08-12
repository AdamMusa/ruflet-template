import RufletEngine
import RufletGeolocator

/// Compatibility aggregate for applications that linked `RufletLocation`
/// before the Flet package boundaries became separate Swift products.
///
/// Linked separately because CoreLocation is what makes iOS require
/// New applications should link `RufletGeolocator` directly. Keeping this
/// wrapper avoids breaking existing hosts without returning service ownership
/// to the legacy aggregate.
///
/// ```swift
/// RufletAppView(services: [RufletLocation.self])
/// ```
@available(*, deprecated, message: "Link and register RufletGeolocator directly")
@MainActor
public enum RufletLocation: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    RufletGeolocator.register(in: registry)
  }
}
