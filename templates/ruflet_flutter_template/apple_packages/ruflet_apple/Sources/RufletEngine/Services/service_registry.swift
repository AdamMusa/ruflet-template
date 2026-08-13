import Foundation
import SwiftUI

@MainActor
public final class ServiceRegistry {
  public let control: RufletControl
  public let propertyName: String
  private let backend: RufletBackendProtocol
  private var services: [Int: ServiceBinding] = [:]
  private var updateListener: UUID?

  public init(control: RufletControl, propertyName: String, backend: RufletBackendProtocol) {
    self.control = control
    self.propertyName = propertyName
    self.backend = backend
    updateListener = control.addListener { [weak self] in self?.synchronize() }
    synchronize()
  }

  private func synchronize() {
    let controls = control.children(propertyName)
    for serviceControl in controls where services[serviceControl.id] == nil {
      // Flet deliberately isolates an unknown service so later services still bind.
      services[serviceControl.id] = try? ServiceBinding(control: serviceControl, backend: backend)
    }
    let currentIDs = Set(controls.map(\.id))
    for id in services.keys where !currentIDs.contains(id) {
      services.removeValue(forKey: id)?.dispose()
    }
  }

  public func dispose() {
    if let updateListener {
      control.removeListener(updateListener)
      self.updateListener = nil
    }
    for service in services.values { service.dispose() }
    services.removeAll()
  }
}

/// Core service factory matching FletCoreExtension's service branch.
@MainActor
public struct RufletCoreServiceExtension: RufletExtension {
  public init() {}

  public func createService(for control: RufletControl) -> RufletService? {
    switch control.type.lowercased() {
    case "accelerometer": return AccelerometerService(control: control)
    case "barometer": return BarometerService(control: control)
    case "battery": return BatteryService(control: control)
    case "clipboard": return ClipboardService(control: control)
    case "connectivity": return ConnectivityService(control: control)
    case "filepicker": return FilePickerService(control: control)
    case "gyroscope": return GyroscopeService(control: control)
    case "hapticfeedback": return HapticFeedbackService(control: control)
    case "magnetometer": return MagnetometerService(control: control)
    case "screenbrightness": return ScreenBrightnessService(control: control)
    case "semanticsservice": return SemanticsServiceControl(control: control)
    case "shakedetector": return ShakeDetectorService(control: control)
    case "share": return ShareService(control: control)
    case "sharedpreferences": return SharedPreferencesService(control: control)
    case "storagepaths": return StoragePaths(control: control)
    case "urllauncher": return UrlLauncherService(control: control)
    case "useraccelerometer": return UserAccelerometerService(control: control)
    case "wakelock": return WakelockService(control: control)
    default: return nil
    }
  }
}
