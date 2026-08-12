import Foundation
import RufletEngine
import RufletProtocol

#if canImport(CoreLocation)
  import CoreLocation
#endif
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// `Geolocator` — the separately linked CoreLocation service used by Flet's
/// `flet_geolocator` extension.
@MainActor
public final class GeolocatorService: NSObject, RufletStreamingService {
  public static let wireType = "Geolocator"

  #if canImport(CoreLocation)
    private let streamManager = CLLocationManager()
    private let oneShotManager = CLLocationManager()
    private var configuration: FletGeolocatorSemantics.Settings?
    private var streamNode: ControlNode?
    private var streamContext: RufletServiceContext?
    private var currentPositionCompletion: RufletMethodCompletion?
    private var currentPositionTimeout: DispatchWorkItem?
    private var currentPositionNode: ControlNode?
    private var currentPositionContext: RufletServiceContext?
    private var permissionCompletion: RufletMethodCompletion?
  #endif

  public override init() {
    super.init()
    #if canImport(CoreLocation)
      streamManager.delegate = self
      oneShotManager.delegate = self
    #endif
  }

  public func activate(node: ControlNode, context: RufletServiceContext) {
    #if canImport(CoreLocation)
      streamNode = node
      streamContext = context
      let next = FletGeolocatorSemantics.settings(node.props["configuration"])
      guard next != configuration else { return }
      configuration = next
      apply(next, to: streamManager, streaming: true)
      streamManager.stopUpdatingLocation()
      streamManager.startUpdatingLocation()
    #else
      if node.handlesEvent("error") {
        context.emitEvent(node.id, "error", .string("CoreLocation is not available"))
      }
    #endif
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(CoreLocation)
      switch call.name {
      case "request_permission":
        requestPermission(completion)

      case "get_permission_status":
        completion(.success(.string(Self.permissionName(streamManager.authorizationStatus))))

      case "is_location_service_enabled":
        completion(.success(.bool(CLLocationManager.locationServicesEnabled())))

      case "get_last_known_position":
        guard Self.hasPermission(streamManager.authorizationStatus) else {
          completion(.failure(RufletServiceError.failed(
            "User denied permissions to access the device's location.")))
          return
        }
        completion(.success(streamManager.location.map(Self.positionValue) ?? .null))

      case "get_current_position":
        guard Self.hasPermission(oneShotManager.authorizationStatus) else {
          let message = "User denied permissions to access the device's location."
          if let node, node.handlesEvent("error") {
            context.emitEvent(node.id, "error", .string(message))
          }
          completion(.success(.null))
          return
        }
        guard currentPositionCompletion == nil else {
          completion(.failure(RufletServiceError.unavailable(
            "A request for the current position is already running")))
          return
        }
        let settings = FletGeolocatorSemantics.settings(call.argument("settings"))
        apply(settings, to: oneShotManager, streaming: false)
        currentPositionCompletion = completion
        currentPositionNode = node
        currentPositionContext = context
        if let seconds = settings.timeLimitSeconds {
          let timeout = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.finishCurrentPosition(
              .success(.null),
              eventMessage: "Time limit reached while waiting for the current position")
          }
          currentPositionTimeout = timeout
          DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: timeout)
        }
        oneShotManager.requestLocation()

      case "open_app_settings", "open_location_settings":
        openSettings(completion)

      case "distance_between":
        guard
          let startLatitude = call.argument("start_latitude")?.doubleValue,
          let startLongitude = call.argument("start_longitude")?.doubleValue,
          let endLatitude = call.argument("end_latitude")?.doubleValue,
          let endLongitude = call.argument("end_longitude")?.doubleValue
        else {
          completion(.success(.null))
          return
        }
        let from = CLLocation(latitude: startLatitude, longitude: startLongitude)
        let to = CLLocation(latitude: endLatitude, longitude: endLongitude)
        completion(.success(.double(from.distance(from: to))))

      default:
        completion(.failure(
          RufletServiceError.unsupportedMethod(type: "Geolocator", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.platformUnsupported(
        type: "Geolocator", method: call.name, platform: "this Apple platform")))
    #endif
  }

  #if canImport(CoreLocation)
    private func requestPermission(_ completion: @escaping RufletMethodCompletion) {
      let status = streamManager.authorizationStatus
      guard status == .notDetermined else {
        completion(.success(.string(Self.permissionName(status))))
        return
      }
      guard permissionCompletion == nil else {
        completion(.failure(RufletServiceError.unavailable(
          "A request for location permissions is already running")))
        return
      }
      permissionCompletion = completion
      #if os(macOS)
        guard Bundle.main.object(forInfoDictionaryKey: "NSLocationUsageDescription") != nil else {
          permissionCompletion = nil
          completion(.failure(RufletServiceError.unavailable(
            "NSLocationUsageDescription is missing from Info.plist")))
          return
        }
        streamManager.requestAlwaysAuthorization()
      #else
        let hasWhenInUse = Bundle.main.object(
          forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
        let hasAlways = Bundle.main.object(
          forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") != nil
          || Bundle.main.object(
            forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil
        guard hasWhenInUse || hasAlways else {
          permissionCompletion = nil
          completion(.failure(RufletServiceError.unavailable(
            "A location usage description is missing from Info.plist")))
          return
        }
        if hasWhenInUse { streamManager.requestWhenInUseAuthorization() }
        else { streamManager.requestAlwaysAuthorization() }
      #endif
    }

    private func apply(
      _ settings: FletGeolocatorSemantics.Settings,
      to manager: CLLocationManager,
      streaming: Bool
    ) {
      manager.desiredAccuracy = Self.accuracy(settings.accuracy)
      manager.distanceFilter = streaming ? CLLocationDistance(settings.distanceFilter) : 0
      manager.activityType = Self.activity(settings.activityType)
      manager.pausesLocationUpdatesAutomatically = streaming
        ? settings.pauseLocationUpdatesAutomatically : false
      #if os(iOS)
        manager.showsBackgroundLocationIndicator = streaming
          && settings.showBackgroundLocationIndicator
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        manager.allowsBackgroundLocationUpdates = streaming
          && settings.allowBackgroundLocationUpdates
          && (modes?.contains("location") == true)
      #endif
    }

    private func openSettings(_ completion: @escaping RufletMethodCompletion) {
      #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          completion(.success(.bool(false)))
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          completion(.success(.bool(opened)))
        }
      #elseif canImport(AppKit)
        let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        completion(.success(.bool(url.map(NSWorkspace.shared.open) ?? false)))
      #else
        completion(.success(.bool(false)))
      #endif
    }

    private func reportStream(_ location: CLLocation) {
      guard let node = streamNode, let context = streamContext else { return }
      let position = Self.positionValue(location)
      context.store.setLocalProperty(node.id, key: "position", value: position)
      if node.handlesEvent("position_change") {
        context.emitEvent(node.id, "position_change", .map(["position": position]))
      }
    }

    private func reportError(_ message: String) {
      guard let node = streamNode, node.handlesEvent("error") else { return }
      streamContext?.emitEvent(node.id, "error", .string(message))
    }

    private func finishCurrentPosition(
      _ result: Result<RufletValue, Error>,
      eventMessage: String? = nil
    ) {
      currentPositionTimeout?.cancel()
      currentPositionTimeout = nil
      oneShotManager.stopUpdatingLocation()
      let completion = currentPositionCompletion
      currentPositionCompletion = nil
      if let eventMessage,
        let node = currentPositionNode,
        node.handlesEvent("error")
      {
        currentPositionContext?.emitEvent(node.id, "error", .string(eventMessage))
      }
      currentPositionNode = nil
      currentPositionContext = nil
      completion?(result)
    }

    private static func positionValue(_ location: CLLocation) -> RufletValue {
      var floor: Int?
      if let level = location.floor?.level { floor = level }
      var mocked = false
      if #available(iOS 15.0, macOS 12.0, *) {
        mocked = location.sourceInformation?.isSimulatedBySoftware ?? false
      }
      let speedIsValid = location.speed >= 0 && location.speedAccuracy >= 0
      let altitudeIsValid = location.verticalAccuracy > 0
      return FletGeolocatorSemantics.position(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude,
        accuracy: location.horizontalAccuracy,
        altitude: altitudeIsValid ? location.altitude : 0,
        altitudeAccuracy: altitudeIsValid ? location.verticalAccuracy : 0,
        heading: location.course,
        headingAccuracy: location.courseAccuracy,
        speed: speedIsValid ? location.speed : 0,
        speedAccuracy: speedIsValid ? location.speedAccuracy : 0,
        floor: floor,
        mocked: mocked,
        timestamp: location.timestamp)
    }

    private static func permissionName(_ status: CLAuthorizationStatus) -> String {
      switch status {
      case .notDetermined, .restricted:
        return FletGeolocatorSemantics.permissionName(index: 0)
      case .denied:
        return FletGeolocatorSemantics.permissionName(index: 1)
      #if os(iOS)
        case .authorizedWhenInUse:
          return FletGeolocatorSemantics.permissionName(index: 2)
      #endif
      case .authorizedAlways:
        return FletGeolocatorSemantics.permissionName(index: 3)
      @unknown default:
        return FletGeolocatorSemantics.permissionName(index: 0)
      }
    }

    private static func hasPermission(_ status: CLAuthorizationStatus) -> Bool {
      switch status {
      case .authorizedAlways: return true
      #if os(iOS)
        case .authorizedWhenInUse: return true
      #endif
      default: return false
      }
    }

    private static func accuracy(_ value: FletGeolocatorSemantics.Accuracy) -> CLLocationAccuracy {
      switch value {
      case .lowest: return kCLLocationAccuracyThreeKilometers
      case .low: return kCLLocationAccuracyKilometer
      case .medium: return kCLLocationAccuracyHundredMeters
      case .high: return kCLLocationAccuracyNearestTenMeters
      case .best: return kCLLocationAccuracyBest
      case .bestForNavigation: return kCLLocationAccuracyBestForNavigation
      case .reduced:
        #if os(iOS)
          if #available(iOS 14.0, *) { return kCLLocationAccuracyReduced }
        #endif
        return kCLLocationAccuracyThreeKilometers
      }
    }

    private static func activity(_ value: FletGeolocatorSemantics.Activity) -> CLActivityType {
      switch value {
      case .automotiveNavigation: return .automotiveNavigation
      case .fitness: return .fitness
      case .otherNavigation: return .otherNavigation
      case .airborne:
        if #available(iOS 12.0, macOS 10.15, *) { return .airborne }
        return .other
      case .other: return .other
      }
    }
  #endif

  deinit {
    #if canImport(CoreLocation)
      streamManager.stopUpdatingLocation()
      oneShotManager.stopUpdatingLocation()
      currentPositionTimeout?.cancel()
    #endif
  }
}

#if canImport(CoreLocation)
  extension GeolocatorService: CLLocationManagerDelegate {
    public nonisolated func locationManager(
      _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
      guard let location = locations.last else { return }
      Task { @MainActor in
        if manager === self.oneShotManager {
          // geolocator_apple discards cached one-shot fixes older than five seconds.
          guard -location.timestamp.timeIntervalSinceNow <= 5 else { return }
          self.finishCurrentPosition(.success(Self.positionValue(location)))
        } else {
          self.reportStream(location)
        }
      }
    }

    public nonisolated func locationManager(
      _ manager: CLLocationManager, didFailWithError error: Error
    ) {
      if let locationError = error as? CLError, locationError.code == .locationUnknown {
        return
      }
      Task { @MainActor in
        if manager === self.oneShotManager {
          // Flet catches getCurrentPosition errors, emits `error`, and returns null.
          self.finishCurrentPosition(.success(.null), eventMessage: error.localizedDescription)
        } else {
          self.reportError(error.localizedDescription)
        }
      }
    }

    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
      Task { @MainActor in
        guard manager === self.streamManager,
          manager.authorizationStatus != .notDetermined,
          let completion = self.permissionCompletion
        else { return }
        self.permissionCompletion = nil
        completion(.success(.string(Self.permissionName(manager.authorizationStatus))))
      }
    }
  }
#endif

/// Pure source-derived defaults and wire conversions for focused package tests.
public enum FletGeolocatorSemantics {
  public enum Accuracy: String, Equatable {
    case lowest, low, medium, high, best, bestForNavigation, reduced
  }

  public enum Activity: String, Equatable {
    case automotiveNavigation, fitness, otherNavigation, airborne, other
  }

  public struct Settings: Equatable {
    public let accuracy: Accuracy
    public let distanceFilter: Int
    public let timeLimitSeconds: TimeInterval?
    public let activityType: Activity
    public let pauseLocationUpdatesAutomatically: Bool
    public let showBackgroundLocationIndicator: Bool
    public let allowBackgroundLocationUpdates: Bool
  }

  public static func settings(_ value: RufletValue?) -> Settings {
    let fields = value?.mapValue ?? [:]
    let accuracyName = fields["accuracy"]?.stringValue?.lowercased()
    let accuracy = Accuracy.allCasesValue.first {
      $0.rawValue.lowercased() == accuracyName
    } ?? .best
    let activityName = fields["activity_type"]?.stringValue?.lowercased()
    let activity = Activity.allCasesValue.first {
      $0.rawValue.lowercased() == activityName
    } ?? .other
    return Settings(
      accuracy: accuracy,
      distanceFilter: fields["distance_filter"]?.intValue ?? 0,
      timeLimitSeconds: durationSeconds(fields["time_limit"]),
      activityType: activity,
      pauseLocationUpdatesAutomatically:
        fields["pause_location_updates_automatically"]?.boolValue ?? false,
      showBackgroundLocationIndicator:
        fields["show_background_location_indicator"]?.boolValue ?? false,
      allowBackgroundLocationUpdates:
        fields["allow_background_location_updates"]?.boolValue ?? true)
  }

  public static func permissionName(index: Int) -> String {
    switch index {
    case 1: return "denied_forever"
    case 2: return "while_in_use"
    case 3: return "always"
    default: return "denied"
    }
  }

  public static func position(
    latitude: Double,
    longitude: Double,
    accuracy: Double,
    altitude: Double,
    altitudeAccuracy: Double,
    heading: Double,
    headingAccuracy: Double,
    speed: Double,
    speedAccuracy: Double,
    floor: Int?,
    mocked: Bool,
    timestamp: Date
  ) -> RufletValue {
    .map([
      "latitude": .double(latitude),
      "longitude": .double(longitude),
      "speed": .double(speed),
      "altitude": .double(altitude),
      "timestamp": dateTime(timestamp),
      "accuracy": .double(accuracy),
      "altitude_accuracy": .double(altitudeAccuracy),
      "heading": .double(heading),
      "heading_accuracy": .double(headingAccuracy),
      "speed_accuracy": .double(speedAccuracy),
      "floor": floor.map { .int(Int64($0)) } ?? .null,
      "mocked": .bool(mocked),
    ])
  }

  public static func positionChange(_ position: RufletValue) -> RufletValue {
    .map(["position": position])
  }

  private static func durationSeconds(_ value: RufletValue?) -> TimeInterval? {
    switch value {
    case .extended(type: 3, let microseconds):
      return Double(microseconds).map { $0 / 1_000_000 }
    case .int(let milliseconds): return Double(milliseconds) / 1_000
    case .double(let milliseconds): return milliseconds / 1_000
    case .map(let fields):
      let days = Double(fields["days"]?.intValue ?? 0)
      let hours = Double(fields["hours"]?.intValue ?? 0)
      let minutes = Double(fields["minutes"]?.intValue ?? 0)
      let seconds = Double(fields["seconds"]?.intValue ?? 0)
      let milliseconds = Double(fields["milliseconds"]?.intValue ?? 0)
      let microseconds = Double(fields["microseconds"]?.intValue ?? 0)
      return days * 86_400 + hours * 3_600 + minutes * 60 + seconds
        + milliseconds / 1_000 + microseconds / 1_000_000
    default: return nil
    }
  }

  private static func dateTime(_ date: Date) -> RufletValue {
    let totalMicroseconds = Int64((date.timeIntervalSince1970 * 1_000_000).rounded())
    let seconds = totalMicroseconds / 1_000_000
    let microseconds = abs(totalMicroseconds % 1_000_000)
    let wholeDate = Date(timeIntervalSince1970: Double(seconds))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return .extended(
      type: 1,
      string: String(format: "%@.%06lld+00:00", formatter.string(from: wholeDate), microseconds))
  }
}

private extension FletGeolocatorSemantics.Accuracy {
  static let allCasesValue: [Self] = [
    .lowest, .low, .medium, .high, .best, .bestForNavigation, .reduced,
  ]
}

private extension FletGeolocatorSemantics.Activity {
  static let allCasesValue: [Self] = [
    .automotiveNavigation, .fitness, .otherNavigation, .airborne, .other,
  ]
}
