import RufletEngine

#if canImport(CoreLocation)
  import CoreLocation
#endif

/// Native Apple implementation of Flet's `flet_geolocator` package.
///
/// This product owns only the `Geolocator` wire service. Applications that do
/// not link it do not carry CoreLocation or its privacy-gated implementation.
@MainActor
public enum RufletGeolocator: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.register(GeolocatorService.self) { GeolocatorService() }

    #if canImport(CoreLocation)
      let manager = CLLocationManager()
      RufletPermissions.installProbe { permission in
        guard permission.hasPrefix("location") else { return nil }
        switch manager.authorizationStatus {
        case .authorizedAlways: return "granted"
        case .notDetermined: return "denied"
        case .denied, .restricted: return "permanently_denied"
        default: return "granted"
        }
      }
      RufletPermissions.installRequest { permission, completion in
        guard permission.hasPrefix("location") else { return false }
        #if os(iOS)
          manager.requestWhenInUseAuthorization()
        #endif
        completion(RufletPermissions.status(of: permission))
        return true
      }
    #endif
  }
}
