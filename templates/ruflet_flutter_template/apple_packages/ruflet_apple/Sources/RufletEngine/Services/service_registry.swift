import Foundation
import RufletProtocol
import SwiftUI

@MainActor
public final class ServiceRegistry {
  public let control: RufletControl
  public let propertyName: String
  private let backend: RufletBackendProtocol
  private var services: [ServiceBinding] = []
  private var updateListener: UUID?
  private var isDisposed = false

  public init(
    control: RufletControl,
    propertyName: String,
    backend: RufletBackendProtocol
  ) throws {
    self.control = control
    self.propertyName = propertyName
    self.backend = backend
    try synchronize()
    updateListener = control.addListener { [weak self] in self?.synchronizeOrFail() }
  }

  /// Reconciles bindings in wire containment order.
  ///
  /// A control with the same numeric id but a different object identity is a
  /// replacement in Ruflet's immutable control materialization model. Its old
  /// service is disposed before the new service is initialized.
  public func synchronize() throws {
    guard !isDisposed else { return }
    let containedControls = control.children(propertyName, visibleOnly: false)
    let previous = services
    var previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.control.id, $0) })
    var next: [ServiceBinding] = []
    var disposedIDs: Set<Int> = []

    do {
      for serviceControl in containedControls {
        if let existing = previousByID[serviceControl.id],
           existing.control === serviceControl
        {
          previousByID.removeValue(forKey: serviceControl.id)
          next.append(existing)
          continue
        }

        if let replaced = previousByID.removeValue(forKey: serviceControl.id) {
          replaced.dispose()
          disposedIDs.insert(replaced.control.id)
        }
        next.append(try ServiceBinding(control: serviceControl, backend: backend))
      }
    } catch {
      let previousIdentities = Set(previous.map { ObjectIdentifier($0) })
      for binding in next where !previousIdentities.contains(ObjectIdentifier(binding)) {
        binding.dispose()
      }
      services = previous.filter { !disposedIDs.contains($0.control.id) }
      throw error
    }

    // Match pinned Flet ordering: additions/replacements are initialized in
    // containment order, then removed services are disposed in their prior
    // containment order.
    for binding in previous where previousByID[binding.control.id] != nil {
      binding.dispose()
    }
    services = next
  }

  private func synchronizeOrFail() {
    do {
      try synchronize()
    } catch {
      preconditionFailure("Failed to bind service registry \(control.id): \(error)")
    }
  }

  public func dispose() {
    guard !isDisposed else { return }
    isDisposed = true
    if let updateListener {
      control.removeListener(updateListener)
      self.updateListener = nil
    }
    for service in services { service.dispose() }
    services.removeAll()
  }
}

/// Owns the Page-level service lifecycle exactly as Flet's Page state does.
///
/// The `_services` registry is replaced when its wire UID or contained
/// control identity changes. `Window` is intentionally bound separately; it
/// is not a member of the generic service registry.
@MainActor
public final class PageServiceBindings {
  public let page: RufletControl
  private let backend: RufletBackendProtocol
  private var registryControl: RufletControl?
  private var registryUID: RufletValue?
  private var serviceRegistry: ServiceRegistry?
  private var windowControl: RufletControl?
  private var windowBinding: ServiceBinding?
  private var updateListener: UUID?
  private var isDisposed = false

  public init(page: RufletControl, backend: RufletBackendProtocol) throws {
    self.page = page
    self.backend = backend
    do {
      try synchronize()
    } catch {
      serviceRegistry?.dispose()
      windowBinding?.dispose()
      throw error
    }
    updateListener = page.addListener { [weak self] in self?.synchronizeOrFail() }
  }

  public func synchronize() throws {
    guard !isDisposed else { return }
    try synchronizeRegistry()
    try synchronizeWindow()
  }

  private func synchronizeRegistry() throws {
    let containedRegistry = page.child("_services", visibleOnly: false)
    guard let containedRegistry else {
      serviceRegistry?.dispose()
      serviceRegistry = nil
      registryControl = nil
      registryUID = nil
      return
    }

    let containedUID = containedRegistry.internals?["uid"]
    let isReplacement = serviceRegistry == nil
      || registryControl !== containedRegistry
      || registryUID != containedUID
    guard isReplacement else { return }

    serviceRegistry?.dispose()
    serviceRegistry = nil
    registryControl = nil
    registryUID = nil

    let replacement = try ServiceRegistry(
      control: containedRegistry,
      propertyName: "_services",
      backend: backend)
    serviceRegistry = replacement
    registryControl = containedRegistry
    registryUID = containedUID
  }

  private func synchronizeWindow() throws {
    let containedWindow = page.child("window", visibleOnly: false)
    guard let containedWindow else {
      windowBinding?.dispose()
      windowBinding = nil
      windowControl = nil
      return
    }
    guard windowControl !== containedWindow else { return }

    windowBinding?.dispose()
    windowBinding = nil
    windowControl = nil
    let replacement = try ServiceBinding(control: containedWindow, backend: backend)
    windowBinding = replacement
    windowControl = containedWindow
  }

  private func synchronizeOrFail() {
    do {
      try synchronize()
    } catch {
      preconditionFailure("Failed to synchronize Page services \(page.id): \(error)")
    }
  }

  public func dispose() {
    guard !isDisposed else { return }
    isDisposed = true
    if let updateListener {
      page.removeListener(updateListener)
      self.updateListener = nil
    }
    serviceRegistry?.dispose()
    serviceRegistry = nil
    registryControl = nil
    registryUID = nil
    windowBinding?.dispose()
    windowBinding = nil
    windowControl = nil
  }
}

/// Core service factory matching FletCoreExtension's service branch.
@MainActor
public struct RufletCoreServiceExtension: RufletExtension {
  public let serviceControlTypes: Set<String> = [
    "Accelerometer", "Barometer", "Battery", "Clipboard", "Connectivity", "FilePicker",
    "Gyroscope", "HapticFeedback", "Magnetometer", "ScreenBrightness", "SemanticsService",
    "ShakeDetector", "Share", "SharedPreferences", "StoragePaths", "Tester", "UrlLauncher",
    "UserAccelerometer", "Wakelock", "Window",
  ]

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
    case "tester": return TesterService(control: control)
    case "urllauncher": return UrlLauncherService(control: control)
    case "useraccelerometer": return UserAccelerometerService(control: control)
    case "wakelock": return WakelockService(control: control)
    case "window": return WindowService(control: control)
    default: return nil
    }
  }
}
