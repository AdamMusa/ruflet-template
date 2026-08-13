@preconcurrency import AVFoundation
@preconcurrency import CoreBluetooth
@preconcurrency import CoreLocation
@preconcurrency import CoreMotion
@preconcurrency import EventKit
@preconcurrency import Speech
@preconcurrency import UserNotifications
import Contacts
import Foundation
import Photos
import RufletEngine
import RufletProtocol

#if os(iOS)
import AppTrackingTransparency
import Intents
import MediaPlayer
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class PermissionHandlerService: RufletService {
  private let broker = RufletApplePermissionBroker()
  private var invokeToken: UUID?

  public required init(control: RufletControl) {
    super.init(control: control)
  }

  public override func initialize() {
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try await self.invoke(name, arguments: arguments)
    }
  }

  public override func dispose() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    switch name {
    case "get_status":
      let permission = try parse(arguments["permission"]?.text)
      return .string(try await broker.status(for: permission).rawValue)
    case "request":
      let permission = try parse(arguments["permission"]?.text)
      return .string(try await broker.request(permission).rawValue)
    case "open_app_settings":
      return .bool(broker.openAppSettings())
    default:
      throw RufletPermissionHandlerError.unknownMethod(name)
    }
  }

  private func parse(_ value: String?) throws -> RufletApplePermission {
    guard let permission = RufletApplePermission.parse(value) else {
      throw RufletPermissionHandlerError.unknownPermission(value)
    }
    return permission
  }
}

@MainActor
private final class RufletApplePermissionBroker {
  private var locationRequester: LocationPermissionRequester?
  private var bluetoothRequester: BluetoothPermissionRequester?

  func status(for permission: RufletApplePermission) async throws -> RufletPermissionStatus {
    switch permission {
    case .camera:
      return Self.map(AVCaptureDevice.authorizationStatus(for: .video))
    case .microphone:
      return Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
    case .contacts:
      return Self.map(CNContactStore.authorizationStatus(for: .contacts))
    case .photos, .photosAddOnly:
      let level: PHAccessLevel = permission == .photosAddOnly ? .addOnly : .readWrite
      return Self.map(PHPhotoLibrary.authorizationStatus(for: level))
    case .calendar, .calendarFullAccess:
      return Self.map(EKEventStore.authorizationStatus(for: .event))
    case .calendarWriteOnly:
      if #available(iOS 17.0, macOS 14.0, *) {
        return Self.map(EKEventStore.authorizationStatus(for: .event))
      }
      return Self.map(EKEventStore.authorizationStatus(for: .event))
    case .reminders:
      return Self.map(EKEventStore.authorizationStatus(for: .reminder))
    case .location, .locationWhenInUse, .locationAlways:
      return Self.map(CLLocationManager().authorizationStatus)
    case .speech:
      return Self.map(SFSpeechRecognizer.authorizationStatus())
    case .notification, .criticalAlerts:
      return Self.map(await UNUserNotificationCenter.current().notificationSettings())
    case .activityRecognition, .sensors:
      #if os(iOS)
      return Self.map(CMMotionActivityManager.authorizationStatus())
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .bluetooth:
      return Self.map(CBManager.authorization)
    case .appTrackingTransparency:
      #if os(iOS)
      if #available(iOS 14.0, *) { return Self.map(ATTrackingManager.trackingAuthorizationStatus) }
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .mediaLibrary:
      #if os(iOS)
      return Self.map(MPMediaLibrary.authorizationStatus())
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .assistant:
      #if os(iOS)
      return Self.map(INPreferences.siriAuthorizationStatus())
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .backgroundRefresh:
      #if os(iOS)
      switch UIApplication.shared.backgroundRefreshStatus {
      case .available: return .granted
      case .denied: return .denied
      case .restricted: return .restricted
      @unknown default: return .restricted
      }
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .accessLocalNetwork:
      // Apple exposes no status API for Local Network privacy.
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
    }
  }

  func request(_ permission: RufletApplePermission) async throws -> RufletPermissionStatus {
    switch permission {
    case .camera:
      _ = await AVCaptureDevice.requestAccess(for: .video)
    case .microphone:
      _ = await AVCaptureDevice.requestAccess(for: .audio)
    case .contacts:
      _ = try await CNContactStore().requestAccess(for: .contacts)
    case .photos, .photosAddOnly:
      let level: PHAccessLevel = permission == .photosAddOnly ? .addOnly : .readWrite
      _ = await PHPhotoLibrary.requestAuthorization(for: level)
    case .calendar, .calendarFullAccess:
      let store = EKEventStore()
      if #available(iOS 17.0, macOS 14.0, *) { _ = try await store.requestFullAccessToEvents() }
      else { _ = try await store.requestAccess(to: .event) }
    case .calendarWriteOnly:
      let store = EKEventStore()
      if #available(iOS 17.0, macOS 14.0, *) { _ = try await store.requestWriteOnlyAccessToEvents() }
      else { _ = try await store.requestAccess(to: .event) }
    case .reminders:
      let store = EKEventStore()
      if #available(iOS 17.0, macOS 14.0, *) { _ = try await store.requestFullAccessToReminders() }
      else { _ = try await store.requestAccess(to: .reminder) }
    case .location, .locationWhenInUse, .locationAlways:
      let requester = LocationPermissionRequester(always: permission == .locationAlways)
      locationRequester = requester
      _ = await requester.request()
      locationRequester = nil
    case .speech:
      _ = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
      }
    case .notification, .criticalAlerts:
      var options: UNAuthorizationOptions = [.alert, .badge, .sound]
      if permission == .criticalAlerts { options.insert(.criticalAlert) }
      _ = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    case .activityRecognition, .sensors:
      #if os(iOS)
      guard CMMotionActivityManager.isActivityAvailable() else {
        throw RufletPermissionHandlerError.unsupportedPermission(permission)
      }
      let manager = CMMotionActivityManager()
      let now = Date()
      _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CMMotionActivity], Error>) in
        manager.queryActivityStarting(from: now, to: now, to: .main) { activities, error in
          if let error { continuation.resume(throwing: error) }
          else { continuation.resume(returning: activities ?? []) }
        }
      }
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .bluetooth:
      let requester = BluetoothPermissionRequester()
      bluetoothRequester = requester
      await requester.request()
      bluetoothRequester = nil
    case .appTrackingTransparency:
      #if os(iOS)
      if #available(iOS 14.0, *) { _ = await ATTrackingManager.requestTrackingAuthorization() }
      else { throw RufletPermissionHandlerError.unsupportedPermission(permission) }
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .mediaLibrary:
      #if os(iOS)
      _ = await withCheckedContinuation { continuation in
        MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
      }
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .assistant:
      #if os(iOS)
      _ = await withCheckedContinuation { continuation in
        INPreferences.requestSiriAuthorization { continuation.resume(returning: $0) }
      }
      #elseif os(macOS)
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
      #endif
    case .backgroundRefresh, .accessLocalNetwork:
      throw RufletPermissionHandlerError.unsupportedPermission(permission)
    }
    return try await status(for: permission)
  }

  func openAppSettings() -> Bool {
    #if os(iOS)
    guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return false }
    UIApplication.shared.open(url)
    return true
    #elseif os(macOS)
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else { return false }
    return NSWorkspace.shared.open(url)
    #endif
  }

  private static func map(_ status: AVAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: CNAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .limited: .limited
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: PHAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .limited: .limited
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: EKAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized, .fullAccess, .writeOnly: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: CLAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorizedAlways, .authorizedWhenInUse: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ settings: UNNotificationSettings) -> RufletPermissionStatus {
    switch settings.authorizationStatus {
    case .authorized: .granted
    case .provisional, .ephemeral: .provisional
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    @unknown default: .restricted
    }
  }

  private static func map(_ status: CMAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: CBManagerAuthorization) -> RufletPermissionStatus {
    switch status {
    case .allowedAlways: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  #if os(iOS)
  @available(iOS 14.0, *)
  private static func map(_ status: ATTrackingManager.AuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: MPMediaLibraryAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private static func map(_ status: INSiriAuthorizationStatus) -> RufletPermissionStatus {
    switch status {
    case .authorized: .granted
    case .notDetermined: .denied
    case .denied: .permanentlyDenied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }
  #endif
}

@MainActor
private final class LocationPermissionRequester: NSObject, @preconcurrency CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let always: Bool
  private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

  init(always: Bool) {
    self.always = always
    super.init()
    manager.delegate = self
  }

  func request() async -> CLAuthorizationStatus {
    guard manager.authorizationStatus == .notDetermined else { return manager.authorizationStatus }
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      always ? manager.requestAlwaysAuthorization() : manager.requestWhenInUseAuthorization()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager.authorizationStatus != .notDetermined else { return }
    continuation?.resume(returning: manager.authorizationStatus)
    continuation = nil
  }
}

@MainActor
private final class BluetoothPermissionRequester: NSObject, @preconcurrency CBCentralManagerDelegate {
  private var manager: CBCentralManager?
  private var continuation: CheckedContinuation<Void, Never>?

  func request() async {
    guard CBManager.authorization == .notDetermined else { return }
    await withCheckedContinuation { continuation in
      self.continuation = continuation
      manager = CBCentralManager(delegate: self, queue: .main)
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard CBManager.authorization != .notDetermined else { return }
    continuation?.resume()
    continuation = nil
  }
}
