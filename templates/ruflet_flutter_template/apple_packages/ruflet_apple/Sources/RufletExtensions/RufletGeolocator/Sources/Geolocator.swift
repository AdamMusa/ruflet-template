@preconcurrency import CoreLocation
import Foundation
import RufletEngine
import RufletProtocol

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class GeolocatorService: RufletService {
  private let manager = CLLocationManager()
  private let delegate = LocationManagerDelegate()
  private var invokeToken: UUID?
  private var permissionContinuation: CheckedContinuation<RufletLocationPermission, Never>?
  private var positionContinuation: CheckedContinuation<CLLocation, Error>?
  private var timeoutTask: Task<Void, Never>?
  private var settings = RufletLocationSettings()

  public required init(control: RufletControl) {
    super.init(control: control)
  }

  public override func initialize() {
    delegate.didUpdate = { [weak self] locations in self?.didUpdateLocations(locations) }
    delegate.didFail = { [weak self] error in self?.didFail(error) }
    delegate.didChangeAuthorization = { [weak self] in self?.didChangeAuthorization() }
    manager.delegate = delegate
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try await self.invoke(name, arguments: arguments)
    }
    update()
  }

  public override func update() {
    settings = .parse(control.value("configuration"))
    apply(settings)
    manager.startUpdatingLocation()
  }

  public override func dispose() {
    manager.stopUpdatingLocation()
    timeoutTask?.cancel()
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
    permissionContinuation?.resume(returning: permissionStatus)
    permissionContinuation = nil
    positionContinuation?.resume(throwing: RufletGeolocatorError.cancelled)
    positionContinuation = nil
  }

  private func didUpdateLocations(_ locations: [CLLocation]) {
    guard let location = locations.last else { return }
    let position = RufletPosition(location).value
    control.updateProperties(["position": position])
    control.triggerEvent("position_change", data: .map(["position": position]))
    positionContinuation?.resume(returning: location)
    positionContinuation = nil
    timeoutTask?.cancel()
  }

  private func didFail(_ error: Error) {
    control.triggerEvent("error", data: .string(error.localizedDescription))
    positionContinuation?.resume(throwing: error)
    positionContinuation = nil
    timeoutTask?.cancel()
  }

  private func didChangeAuthorization() {
    guard manager.authorizationStatus != .notDetermined else { return }
    permissionContinuation?.resume(returning: permissionStatus)
    permissionContinuation = nil
  }

  private var permissionStatus: RufletLocationPermission {
    RufletLocationPermission.map(manager.authorizationStatus)
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    switch name {
    case "request_permission":
      return .string((await requestPermission()).rawValue)
    case "get_permission_status":
      return .string(permissionStatus.rawValue)
    case "is_location_service_enabled":
      return .bool(CLLocationManager.locationServicesEnabled())
    case "open_app_settings":
      return .bool(openSettings())
    case "open_location_settings":
      return .bool(openSettings())
    case "get_last_known_position":
      return manager.location.map { RufletPosition($0).value } ?? .null
    case "get_current_position":
      let requestSettings = RufletLocationSettings.parse(arguments["settings"])
      do { return RufletPosition(try await currentPosition(settings: requestSettings)).value }
      catch {
        control.triggerEvent("error", data: .string(String(describing: error)))
        return .null
      }
    case "distance_between":
      guard
        let startLatitude = arguments["start_latitude"]?.number,
        let startLongitude = arguments["start_longitude"]?.number,
        let endLatitude = arguments["end_latitude"]?.number,
        let endLongitude = arguments["end_longitude"]?.number
      else { return .null }
      let start = CLLocation(latitude: startLatitude, longitude: startLongitude)
      let end = CLLocation(latitude: endLatitude, longitude: endLongitude)
      return .double(end.distance(from: start))
    default:
      throw RufletGeolocatorError.unknownMethod(name)
    }
  }

  private func requestPermission() async -> RufletLocationPermission {
    guard manager.authorizationStatus == .notDetermined else { return permissionStatus }
    return await withCheckedContinuation { continuation in
      permissionContinuation = continuation
      manager.requestWhenInUseAuthorization()
    }
  }

  private func currentPosition(settings: RufletLocationSettings) async throws -> CLLocation {
    apply(settings)
    if let current = manager.location { return current }
    return try await withCheckedThrowingContinuation { continuation in
      positionContinuation = continuation
      manager.requestLocation()
      if let timeLimit = settings.timeLimit {
        timeoutTask = Task { @MainActor [weak self] in
          try? await Task.sleep(nanoseconds: UInt64(max(0, timeLimit) * 1_000_000_000))
          guard let self, !Task.isCancelled else { return }
          positionContinuation?.resume(throwing: RufletGeolocatorError.timedOut)
          positionContinuation = nil
        }
      }
    }
  }

  private func apply(_ settings: RufletLocationSettings) {
    manager.desiredAccuracy = settings.accuracy.coreLocationAccuracy
    manager.distanceFilter = settings.distanceFilter
    manager.activityType = settings.activityType.coreLocationActivity
    manager.pausesLocationUpdatesAutomatically = settings.pausesAutomatically
    #if os(iOS)
    manager.showsBackgroundLocationIndicator = settings.showsBackgroundIndicator
    manager.allowsBackgroundLocationUpdates = settings.allowsBackgroundUpdates
    #endif
  }

  private func openSettings() -> Bool {
    #if os(iOS)
    guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return false }
    UIApplication.shared.open(url)
    return true
    #elseif os(macOS)
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return false }
    return NSWorkspace.shared.open(url)
    #endif
  }
}

@MainActor
private final class LocationManagerDelegate: NSObject, @preconcurrency CLLocationManagerDelegate {
  var didUpdate: (([CLLocation]) -> Void)?
  var didFail: ((Error) -> Void)?
  var didChangeAuthorization: (() -> Void)?

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    didUpdate?(locations)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    didFail?(error)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    didChangeAuthorization?()
  }
}

public enum RufletGeolocatorError: Error, Equatable, Sendable {
  case timedOut
  case cancelled
  case unknownMethod(String)
}
