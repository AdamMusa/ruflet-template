import Foundation
import RufletEngine
import RufletProtocol

#if canImport(AVFoundation)
  import AVFoundation
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

/// The exact permission names exported by flet_permission_handler 0.80.5.
public enum RufletPermissionKind: String, CaseIterable, Sendable {
  case accessMediaLocation
  case accessNotificationPolicy
  case activityRecognition
  case appTrackingTransparency
  case assistant
  case audio
  case backgroundRefresh
  case bluetooth
  case bluetoothAdvertise
  case bluetoothConnect
  case bluetoothScan
  case calendarFullAccess
  case calendarWriteOnly
  case camera
  case contacts
  case criticalAlerts
  case ignoreBatteryOptimizations
  case location
  case locationAlways
  case locationWhenInUse
  case manageExternalStorage
  case mediaLibrary
  case microphone
  case nearbyWifiDevices
  case notification
  case phone
  case photos
  case photosAddOnly
  case reminders
  case requestInstallPackages
  case scheduleExactAlarm
  case sensors
  case sensorsAlways
  case sms
  case speech
  case storage
  case systemAlertWindow
  case unknown
  case videos
}

/// Names returned by Dart's PermissionStatus.name and consumed by Python.
public enum RufletPermissionStatus: String, Equatable, Sendable {
  case granted
  case denied
  case permanentlyDenied
  case limited
  case provisional
  case restricted
}

public enum RufletAppleAuthorizationState: Equatable, Sendable {
  case authorized
  case notDetermined
  case denied
  case restricted
  case limited
  case provisional
}

public enum FletPermissionHandlerSemantics {
  /// `parsePermission()` is case-insensitive but does not accept aliases.
  public static func permission(_ value: RufletValue?) -> RufletPermissionKind? {
    guard case .string(let value)? = value else { return nil }
    return RufletPermissionKind.allCases.first {
      $0.rawValue.caseInsensitiveCompare(value) == .orderedSame
    }
  }

  /// permission_handler_apple's UnknownPermissionStrategy defaults.
  public static func unsupportedStatus(requesting: Bool) -> RufletPermissionStatus {
    requesting ? .permanentlyDenied : .denied
  }

  public static func status(
    for state: RufletAppleAuthorizationState
  ) -> RufletPermissionStatus {
    switch state {
    case .authorized: return .granted
    case .notDetermined: return .denied
    case .denied: return .permanentlyDenied
    case .restricted: return .restricted
    case .limited: return .limited
    case .provisional: return .provisional
    }
  }
}

/// Injectable seam around APIs that may display an Apple permission prompt or
/// leave the process to open Settings.
@MainActor
public protocol RufletPermissionHandling: AnyObject {
  func status(
    of permission: RufletPermissionKind,
    completion: @escaping (RufletPermissionStatus) -> Void)
  func request(
    _ permission: RufletPermissionKind,
    completion: @escaping (RufletPermissionStatus) -> Void)
  func openAppSettings(completion: @escaping (Bool) -> Void)
}

/// Native Apple implementation of the three methods in the pinned Flet
/// PermissionHandler adapter.
@MainActor
public final class PermissionHandlerService: RufletService {
  public static let wireType = "PermissionHandler"

  private let permissions: any RufletPermissionHandling

  public init(permissions: (any RufletPermissionHandling)? = nil) {
    self.permissions = permissions ?? RufletApplePermissionHandler()
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "get_status":
      guard let permission = FletPermissionHandlerSemantics.permission(
        call.argument("permission"))
      else {
        // parsePermission() returns null for an absent or unknown value.
        return completion(.success(.null))
      }
      permissions.status(of: permission) { status in
        completion(.success(.string(status.rawValue)))
      }

    case "request":
      guard let permission = FletPermissionHandlerSemantics.permission(
        call.argument("permission"))
      else {
        return completion(.success(.null))
      }
      permissions.request(permission) { status in
        completion(.success(.string(status.rawValue)))
      }

    case "open_app_settings":
      permissions.openAppSettings { opened in
        completion(.success(.bool(opened)))
      }

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: Self.wireType, method: call.name)))
    }
  }
}

@MainActor
private final class RufletApplePermissionHandler: RufletPermissionHandling {
  func status(
    of permission: RufletPermissionKind,
    completion: @escaping (RufletPermissionStatus) -> Void
  ) {
    #if canImport(AVFoundation)
      switch permission {
      case .camera:
        return completion(Self.status(AVCaptureDevice.authorizationStatus(for: .video)))
      case .microphone:
        return completion(Self.status(AVCaptureDevice.authorizationStatus(for: .audio)))
      default: break
      }
    #endif

    // Apple permission_handler uses UnknownPermissionStrategy for permission
    // groups that have no enabled native strategy on the current target.
    completion(FletPermissionHandlerSemantics.unsupportedStatus(requesting: false))
  }

  func request(
    _ permission: RufletPermissionKind,
    completion: @escaping (RufletPermissionStatus) -> Void
  ) {
    #if canImport(AVFoundation)
      let mediaType: AVMediaType?
      switch permission {
      case .camera: mediaType = .video
      case .microphone: mediaType = .audio
      default: mediaType = nil
      }
      if let mediaType {
        AVCaptureDevice.requestAccess(for: mediaType) { _ in
          let status = Self.status(AVCaptureDevice.authorizationStatus(for: mediaType))
          Task { @MainActor in completion(status) }
        }
        return
      }
    #endif

    completion(FletPermissionHandlerSemantics.unsupportedStatus(requesting: true))
  }

  func openAppSettings(completion: @escaping (Bool) -> Void) {
    #if os(iOS)
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        return completion(false)
      }
      UIApplication.shared.open(url, options: [:], completionHandler: completion)
    #elseif canImport(AppKit)
      guard let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy")
      else {
        return completion(false)
      }
      completion(NSWorkspace.shared.open(url))
    #else
      completion(false)
    #endif
  }

  #if canImport(AVFoundation)
    nonisolated private static func status(
      _ status: AVAuthorizationStatus
    ) -> RufletPermissionStatus {
      let state: RufletAppleAuthorizationState
      switch status {
      case .authorized: state = .authorized
      case .notDetermined: state = .notDetermined
      case .restricted: state = .restricted
      case .denied: state = .denied
      @unknown default: state = .notDetermined
      }
      return FletPermissionHandlerSemantics.status(for: state)
    }
  #endif
}
