import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#elseif os(macOS)
import IOKit.ps
#endif

@MainActor
public final class BatteryService: RufletInvokableService {
  private var observerTokens: [NSObjectProtocol] = []
  #if os(macOS)
  private var pollTimer: Timer?
  #endif
  private var previousState: String?

  public override func initialize() {
    super.initialize()
    #if os(iOS)
    UIDevice.current.isBatteryMonitoringEnabled = true
    #endif
    updateListeners()
  }

  public override func update() { updateListeners() }

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "get_battery_level":
      guard let level = batteryLevel else { return .null }
      return .int(Int64(level))
    case "get_battery_state": return .string(batteryState)
    case "is_in_battery_save_mode": return .bool(ProcessInfo.processInfo.isLowPowerModeEnabled)
    default: throw RufletServiceError.unknownMethod(service: "Battery", method: name)
    }
  }

  private var batteryLevel: Int? {
    #if os(iOS)
    let level = UIDevice.current.batteryLevel
    return level < 0 ? nil : Int((level * 100).rounded())
    #elseif os(macOS)
    guard let description = powerSourceDescription(),
          let capacity = description[kIOPSCurrentCapacityKey] as? NSNumber,
          let maximum = description[kIOPSMaxCapacityKey] as? NSNumber,
          maximum.doubleValue > 0 else { return nil }
    return Int((capacity.doubleValue / maximum.doubleValue * 100).rounded())
    #endif
  }

  private var batteryState: String {
    #if os(iOS)
    switch UIDevice.current.batteryState {
    case .charging: return "charging"
    case .full: return "full"
    case .unplugged: return "discharging"
    case .unknown: fallthrough
    @unknown default: return "unknown"
    }
    #elseif os(macOS)
    guard let description = powerSourceDescription() else { return "unknown" }
    let state = description[kIOPSPowerSourceStateKey] as? String
    let charged = description[kIOPSIsChargedKey] as? Bool ?? false
    let charging = description[kIOPSIsChargingKey] as? Bool ?? false
    if charged { return "full" }
    if charging { return "charging" }
    if state == kIOPSBatteryPowerValue { return "discharging" }
    return "connectedNotCharging"
    #endif
  }

  #if os(macOS)
  private func powerSourceDescription() -> [String: Any]? {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
    else { return nil }
    for source in sources {
      if let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
        as? [String: Any], description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType {
        return description
      }
    }
    return nil
  }
  #endif

  private func updateListeners() {
    let shouldListen = control.hasEventHandler("state_change")
    if shouldListen, observerTokens.isEmpty {
      previousState = batteryState
      #if os(iOS)
      observerTokens = [UIDevice.batteryStateDidChangeNotification].map { notification in
        NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) {
          [weak self] _ in Task { @MainActor in self?.emitStateIfChanged() }
        }
      }
      #elseif os(macOS)
      pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.emitStateIfChanged() }
      }
      #endif
    } else if !shouldListen {
      removeObservers()
    }
  }

  private func emitStateIfChanged() {
    let state = batteryState
    guard state != previousState else { return }
    previousState = state
    control.triggerEvent("state_change", data: ["state": .string(state)])
  }

  private func removeObservers() {
    observerTokens.forEach(NotificationCenter.default.removeObserver)
    observerTokens.removeAll()
    #if os(macOS)
    pollTimer?.invalidate()
    pollTimer = nil
    #endif
    previousState = nil
  }

  public override func dispose() {
    removeObservers()
    #if os(iOS)
    UIDevice.current.isBatteryMonitoringEnabled = false
    #endif
    super.dispose()
  }
}

