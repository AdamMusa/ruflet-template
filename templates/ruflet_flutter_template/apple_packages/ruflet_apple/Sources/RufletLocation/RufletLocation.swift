import RufletEngine

#if canImport(CoreLocation)
  import CoreLocation
#endif

/// The CoreLocation service.
///
/// Linked separately because CoreLocation is what makes iOS require
/// `NSLocationWhenInUseUsageDescription`, and because App Store review flags
/// the framework whether or not an app ever calls it.
///
/// ```swift
/// RufletAppView(services: [RufletLocation.self])
/// ```
@MainActor
public enum RufletLocation: RufletServiceBundle {
  public static let bundleName = "RufletLocation"

  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("Geolocator") { GeolocatorService() }

    // The core permission service asks whoever is linked; without this module
    // a location permission simply reports "granted", which is the honest
    // answer for an app that cannot ask for one.
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
