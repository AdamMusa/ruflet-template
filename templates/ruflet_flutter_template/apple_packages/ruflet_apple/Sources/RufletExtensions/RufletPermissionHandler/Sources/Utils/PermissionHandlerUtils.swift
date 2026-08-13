import Foundation

/// Permission names that exist in Apple's privacy model. Android-only Flet
/// permissions intentionally do not enter the Apple renderer's type system.
public enum RufletApplePermission: String, CaseIterable, Sendable {
  case calendar
  case camera
  case contacts
  case location
  case locationAlways
  case locationWhenInUse
  case mediaLibrary
  case microphone
  case photos
  case photosAddOnly
  case reminders
  case sensors
  case speech
  case notification
  case activityRecognition
  case bluetooth
  case appTrackingTransparency
  case criticalAlerts
  case calendarWriteOnly
  case calendarFullAccess
  case assistant
  case backgroundRefresh
  case accessLocalNetwork

  public static func parse(_ value: String?) -> Self? {
    guard let value else { return nil }
    return allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
  }
}

public enum RufletPermissionStatus: String, Sendable {
  case denied
  case granted
  case restricted
  case limited
  case permanentlyDenied
  case provisional
}

public enum RufletPermissionHandlerError: Error, Equatable, Sendable {
  case unknownPermission(String?)
  case unsupportedPermission(RufletApplePermission)
  case unknownMethod(String)
}
