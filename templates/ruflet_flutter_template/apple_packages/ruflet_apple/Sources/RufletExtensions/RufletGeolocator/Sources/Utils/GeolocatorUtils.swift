import CoreLocation
import Foundation
import RufletProtocol

public enum RufletLocationAccuracy: String, CaseIterable, Sendable {
  case lowest
  case low
  case medium
  case high
  case best
  case bestForNavigation

  static func parse(_ value: String?) -> Self {
    guard let value else { return .best }
    return allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame } ?? .best
  }

  var coreLocationAccuracy: CLLocationAccuracy {
    switch self {
    case .lowest: kCLLocationAccuracyReduced
    case .low: kCLLocationAccuracyKilometer
    case .medium: kCLLocationAccuracyHundredMeters
    case .high: kCLLocationAccuracyNearestTenMeters
    case .best: kCLLocationAccuracyBest
    case .bestForNavigation: kCLLocationAccuracyBestForNavigation
    }
  }
}

public enum RufletLocationActivityType: String, CaseIterable, Sendable {
  case other
  case automotiveNavigation
  case fitness
  case otherNavigation
  case airborne

  static func parse(_ value: String?) -> Self {
    guard let value else { return .other }
    return allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame } ?? .other
  }

  var coreLocationActivity: CLActivityType {
    switch self {
    case .other: .other
    case .automotiveNavigation: .automotiveNavigation
    case .fitness: .fitness
    case .otherNavigation: .otherNavigation
    case .airborne: .airborne
    }
  }
}

public struct RufletLocationSettings: Equatable, Sendable {
  public var distanceFilter: Double
  public var accuracy: RufletLocationAccuracy
  public var timeLimit: TimeInterval?
  public var activityType: RufletLocationActivityType
  public var pausesAutomatically: Bool
  public var showsBackgroundIndicator: Bool
  public var allowsBackgroundUpdates: Bool

  public init(
    distanceFilter: Double = 0,
    accuracy: RufletLocationAccuracy = .best,
    timeLimit: TimeInterval? = nil,
    activityType: RufletLocationActivityType = .other,
    pausesAutomatically: Bool = false,
    showsBackgroundIndicator: Bool = false,
    allowsBackgroundUpdates: Bool = true
  ) {
    self.distanceFilter = distanceFilter
    self.accuracy = accuracy
    self.timeLimit = timeLimit
    self.activityType = activityType
    self.pausesAutomatically = pausesAutomatically
    self.showsBackgroundIndicator = showsBackgroundIndicator
    self.allowsBackgroundUpdates = allowsBackgroundUpdates
  }

  public static func parse(_ value: RufletValue?) -> Self {
    guard let map = value?.map else { return Self() }
    return Self(
      distanceFilter: map["distance_filter"]?.number ?? 0,
      accuracy: .parse(map["accuracy"]?.text),
      timeLimit: duration(map["time_limit"]),
      activityType: .parse(map["activity_type"]?.text),
      pausesAutomatically: map["pause_location_updates_automatically"]?.bool ?? false,
      showsBackgroundIndicator: map["show_background_location_indicator"]?.bool ?? false,
      allowsBackgroundUpdates: map["allow_background_location_updates"]?.bool ?? true)
  }

  private static func duration(_ value: RufletValue?) -> TimeInterval? {
    guard let value else { return nil }
    if let milliseconds = value.number { return milliseconds / 1_000 }
    guard let map = value.map else { return nil }
    return (map["days"]?.number ?? 0) * 86_400
      + (map["hours"]?.number ?? 0) * 3_600
      + (map["minutes"]?.number ?? 0) * 60
      + (map["seconds"]?.number ?? 0)
      + (map["milliseconds"]?.number ?? 0) / 1_000
      + (map["microseconds"]?.number ?? 0) / 1_000_000
  }
}

public struct RufletPosition: Equatable, Sendable {
  public let latitude: Double
  public let longitude: Double
  public let speed: Double
  public let altitude: Double
  public let timestamp: Date
  public let accuracy: Double
  public let altitudeAccuracy: Double
  public let heading: Double
  public let headingAccuracy: Double
  public let speedAccuracy: Double
  public let floor: Int?
  public let mocked: Bool

  public init(_ location: CLLocation) {
    latitude = location.coordinate.latitude
    longitude = location.coordinate.longitude
    speed = location.speed
    altitude = location.altitude
    timestamp = location.timestamp
    accuracy = location.horizontalAccuracy
    altitudeAccuracy = location.verticalAccuracy
    heading = location.course
    if #available(iOS 13.4, macOS 10.15.4, *) { headingAccuracy = location.courseAccuracy }
    else { headingAccuracy = -1 }
    if #available(iOS 10.0, macOS 10.15, *) { speedAccuracy = location.speedAccuracy }
    else { speedAccuracy = -1 }
    floor = location.floor?.level
    mocked = false
  }

  public var value: RufletValue {
    var map: [String: RufletValue] = [
      "latitude": .double(latitude), "longitude": .double(longitude),
      "speed": .double(speed), "altitude": .double(altitude),
      "timestamp": .string(ISO8601DateFormatter().string(from: timestamp)),
      "accuracy": .double(accuracy), "altitude_accuracy": .double(altitudeAccuracy),
      "heading": .double(heading), "heading_accuracy": .double(headingAccuracy),
      "speed_accuracy": .double(speedAccuracy), "mocked": .bool(mocked),
    ]
    if let floor { map["floor"] = .int(Int64(floor)) }
    return .map(map)
  }
}

public enum RufletLocationPermission: String, Sendable {
  case denied
  case deniedForever
  case whileInUse
  case always
  case unableToDetermine

  static func map(_ status: CLAuthorizationStatus) -> Self {
    switch status {
    case .notDetermined: .denied
    case .restricted: .denied
    case .denied: .deniedForever
    case .authorizedWhenInUse: .whileInUse
    case .authorizedAlways: .always
    @unknown default: .unableToDetermine
    }
  }
}
