import Foundation
import RufletEngine
import RufletProtocol

#if canImport(CoreLocation)
  import CoreLocation
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// `Geolocator` — CoreLocation.
@MainActor
public final class GeolocatorService: NSObject, RufletService {
  public static let wireType = "Geolocator"

  private let manager = CLLocationManager()
  private var pending: [RufletMethodCompletion] = []
  private var streamTarget: Int?
  private var context: RufletServiceContext?

  public override init() {
    super.init()
    manager.delegate = self
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    self.context = context
    self.streamTarget = node?.id

    switch call.name {
    case "request_permission":
      #if os(iOS)
        manager.requestWhenInUseAuthorization()
      #endif
      completion(.success(.string(Self.describe(manager.authorizationStatus))))

    case "get_permission_status":
      completion(.success(.string(Self.describe(manager.authorizationStatus))))

    case "is_location_service_enabled":
      // The class method blocks; the authorization status is the non-blocking
      // signal an application actually branches on.
      completion(.success(.bool(manager.authorizationStatus != .denied)))

    case "get_current_position", "get_last_known_position":
      if let location = manager.location {
        return completion(.success(Self.describe(location)))
      }
      pending.append(completion)
      manager.requestLocation()

    case "open_app_settings", "open_location_settings":
      #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      #endif
      completion(.success(.bool(true)))

    case "distance_between":
      let from = CLLocation(
        latitude: call.argument("start_latitude")?.doubleValue ?? 0,
        longitude: call.argument("start_longitude")?.doubleValue ?? 0)
      let to = CLLocation(
        latitude: call.argument("end_latitude")?.doubleValue ?? 0,
        longitude: call.argument("end_longitude")?.doubleValue ?? 0)
      completion(.success(.double(from.distance(from: to))))

    default:
      completion(
        .failure(RufletServiceError.unsupportedMethod(type: "Geolocator", method: call.name)))
    }
  }

  private static func describe(_ location: CLLocation) -> RufletValue {
    .map([
      "latitude": .double(location.coordinate.latitude),
      "longitude": .double(location.coordinate.longitude),
      "accuracy": .double(location.horizontalAccuracy),
      "altitude": .double(location.altitude),
      "speed": .double(location.speed),
      "heading": .double(location.course),
      "timestamp": .double(location.timestamp.timeIntervalSince1970 * 1000)
    ])
  }

  private static func describe(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways: return "always"
    case .notDetermined: return "denied"
    case .restricted: return "denied_forever"
    case .denied: return "denied_forever"
    default: return "while_in_use"
    }
  }
}

extension GeolocatorService: CLLocationManagerDelegate {
  public nonisolated func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.last else { return }
    Task { @MainActor in
      let payload = Self.describe(location)
      self.pending.forEach { $0(.success(payload)) }
      self.pending.removeAll()
      if let target = self.streamTarget {
        self.context?.emitEvent(target, "position_change", payload)
      }
    }
  }

  public nonisolated func locationManager(
    _ manager: CLLocationManager, didFailWithError error: Error
  ) {
    Task { @MainActor in
      if let target = self.streamTarget {
        self.context?.emitEvent(target, "error", .map([
          "error": .string(error.localizedDescription)
        ]))
      }
      self.pending.forEach { $0(.failure(RufletServiceError.failed(error.localizedDescription))) }
      self.pending.removeAll()
    }
  }
}
