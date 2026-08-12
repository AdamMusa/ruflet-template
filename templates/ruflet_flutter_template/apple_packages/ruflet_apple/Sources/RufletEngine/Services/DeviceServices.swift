import Foundation
import RufletProtocol

#if canImport(Network)
  import Network
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif
#if canImport(IOKit)
  import IOKit.ps
#endif

/// Pure Flet wire conversions for device services. Keeping this separate from
/// Apple framework objects lets the translated contract tests exercise result
/// shapes and argument validation deterministically.
public enum FletDeviceServiceSemantics {
  public static func connectivityNames(
    wifi: Bool,
    mobile: Bool,
    ethernet: Bool,
    other: Bool,
    satellite: Bool = false,
    satisfied: Bool
  ) -> [String] {
    guard satisfied else { return ["none"] }
    var values: [String] = []
    if wifi { values.append("wifi") }
    if mobile { values.append("mobile") }
    if ethernet { values.append("ethernet") }
    if other { values.append("other") }
    if satellite { values.append("satellite") }
    return values.isEmpty ? ["none"] : values
  }

  public static func batteryStateEvent(_ state: String) -> RufletValue {
    .map(["state": .string(state)])
  }

  public static func connectivityEvent(_ names: [String]) -> RufletValue {
    .map(["connectivity": .array(names.map(RufletValue.string))])
  }

  /// battery_plus converts UIDevice's fractional level with an integer cast,
  /// so 50.9% is reported as 50 rather than rounded to 51.
  public static func batteryPercentage(fraction: Double?) -> Int? {
    guard let fraction, fraction.isFinite, fraction >= 0 else { return nil }
    return Int(fraction * 100)
  }

  /// battery_plus's macOS adapter distinguishes external power without active
  /// charging from a full battery and exposes Dart's camel-case enum name.
  public static func macBatteryStateName(
    hasBattery: Bool,
    isFull: Bool?,
    isCharging: Bool?,
    onACPower: Bool
  ) -> String {
    guard hasBattery else { return "connectedNotCharging" }
    if isFull == true { return "full" }
    guard let isCharging else { return "unknown" }
    if isCharging { return "charging" }
    return onACPower ? "connectedNotCharging" : "discharging"
  }

  public static func requiredBool(_ value: RufletValue?, name: String) throws -> Bool {
    guard let value = value?.boolValue else {
      throw RufletServiceError.invalidArguments("\(name) is required")
    }
    return value
  }

  public static func validatedBrightness(_ value: RufletValue?) throws -> Double {
    guard let value = value?.doubleValue else {
      throw RufletServiceError.invalidArguments("value is required")
    }
    guard (0...1).contains(value) else {
      throw RufletServiceError.invalidArguments("value must be between 0 and 1")
    }
    return value
  }
}

/// `Battery` — level, charging state and low-power mode.
@MainActor
public final class BatteryService: RufletStreamingService {
  public static let wireType = "Battery"
  private var stateObserver: NSObjectProtocol?
  private var targetID: Int?
  private var emitEvent: ((_ target: Int, _ name: String, _ data: RufletValue) -> Void)?
  #if canImport(IOKit) && os(macOS)
    private var powerSourceRunLoop: CFRunLoop?
    private var powerSourceRunLoopSource: CFRunLoopSource?
  #endif

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    guard node.handlesEvent("state_change") else {
      stopListening()
      return
    }
    targetID = node.id
    emitEvent = context.emitEvent
    #if os(iOS)
      UIDevice.current.isBatteryMonitoringEnabled = true
      if stateObserver == nil {
        stateObserver = NotificationCenter.default.addObserver(
          forName: UIDevice.batteryStateDidChangeNotification,
          object: UIDevice.current,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor in self?.reportBatteryState() }
        }
        reportBatteryState()
      }
    #elseif canImport(IOKit) && os(macOS)
      startMacBatteryListening()
    #endif
  }

  deinit {
    if let stateObserver { NotificationCenter.default.removeObserver(stateObserver) }
    #if os(iOS)
      UIDevice.current.isBatteryMonitoringEnabled = false
    #endif
    #if canImport(IOKit) && os(macOS)
      if let powerSourceRunLoop, let powerSourceRunLoopSource {
        CFRunLoopRemoveSource(powerSourceRunLoop, powerSourceRunLoopSource, .defaultMode)
      }
    #endif
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if os(iOS)
      UIDevice.current.isBatteryMonitoringEnabled = true
    #endif
    switch call.name {
    case "get_battery_level":
      #if os(iOS)
        let level = UIDevice.current.batteryLevel
        completion(
          .success(
            FletDeviceServiceSemantics.batteryPercentage(fraction: Double(level))
              .map { .int(Int64($0)) } ?? .null))
      #elseif canImport(IOKit)
        completion(.success(Self.macBatteryLevel().map { RufletValue.int(Int64($0)) } ?? .null))
      #else
        completion(.success(.null))
      #endif

    case "get_battery_state":
      #if os(iOS)
        switch UIDevice.current.batteryState {
        case .charging: completion(.success(.string("charging")))
        case .full: completion(.success(.string("full")))
        case .unplugged: completion(.success(.string("discharging")))
        default: completion(.success(.string("unknown")))
        }
      #elseif canImport(IOKit) && os(macOS)
        completion(.success(.string(Self.macBatteryState())))
      #else
        completion(.success(.string("unknown")))
      #endif

    case "is_in_battery_save_mode":
      completion(.success(.bool(ProcessInfo.processInfo.isLowPowerModeEnabled)))

    default:
      completion(
        .failure(RufletServiceError.unsupportedMethod(type: "Battery", method: call.name)))
    }
  }

  private func reportBatteryState() {
    guard let targetID, let emitEvent else { return }
    #if os(iOS)
      emitEvent(
        targetID, "state_change",
        FletDeviceServiceSemantics.batteryStateEvent(Self.stateName(UIDevice.current.batteryState)))
    #elseif canImport(IOKit) && os(macOS)
      emitEvent(
        targetID, "state_change",
        FletDeviceServiceSemantics.batteryStateEvent(Self.macBatteryState()))
    #endif
  }

  private func stopListening() {
    if let stateObserver { NotificationCenter.default.removeObserver(stateObserver) }
    stateObserver = nil
    targetID = nil
    emitEvent = nil
    #if os(iOS)
      UIDevice.current.isBatteryMonitoringEnabled = false
    #elseif canImport(IOKit) && os(macOS)
      if let powerSourceRunLoop, let powerSourceRunLoopSource {
        CFRunLoopRemoveSource(powerSourceRunLoop, powerSourceRunLoopSource, .defaultMode)
      }
      powerSourceRunLoop = nil
      powerSourceRunLoopSource = nil
    #endif
  }

  #if os(iOS)
    private static func stateName(_ state: UIDevice.BatteryState) -> String {
      switch state {
      case .charging: return "charging"
      case .full: return "full"
      case .unplugged: return "discharging"
      default: return "unknown"
      }
    }
  #endif

  #if canImport(IOKit) && os(macOS)
    /// Reads the charge percentage out of IOKit's power-source snapshot.
    private static func macPowerSourceDescription() -> [String: Any]? {
      guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
      else { return nil }

      for source in sources {
        if let description = IOPSGetPowerSourceDescription(snapshot, source)?
          .takeUnretainedValue() as? [String: Any]
        {
          return description
        }
      }
      return nil
    }

    private static func macBatteryLevel() -> Int? {
      macPowerSourceDescription()?[kIOPSCurrentCapacityKey] as? Int
    }

    private static func macBatteryState() -> String {
      guard let description = macPowerSourceDescription() else {
        return FletDeviceServiceSemantics.macBatteryStateName(
          hasBattery: false, isFull: nil, isCharging: nil, onACPower: true)
      }
      return FletDeviceServiceSemantics.macBatteryStateName(
        hasBattery: true,
        isFull: description[kIOPSIsChargedKey] as? Bool,
        isCharging: description[kIOPSIsChargingKey] as? Bool,
        onACPower: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
    }

    private func startMacBatteryListening() {
      guard powerSourceRunLoopSource == nil else { return }
      let context = Unmanaged.passUnretained(self).toOpaque()
      guard let source = IOPSNotificationCreateRunLoopSource({ context in
        guard let context else { return }
        let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in service.reportBatteryState() }
      }, context)?.takeRetainedValue() else { return }
      let runLoop = CFRunLoopGetMain()
      powerSourceRunLoop = runLoop
      powerSourceRunLoopSource = source
      CFRunLoopAddSource(runLoop, source, .defaultMode)
      reportBatteryState()
    }
  #endif
}

/// `Connectivity` — the current link type, plus `change` events as it moves.
@MainActor
public final class ConnectivityService: RufletStreamingService {
  public static let wireType = "Connectivity"

  #if canImport(Network)
    private var monitor = NWPathMonitor()
    private var monitoring = false
    private var current = ["none"]
    private var targetID: Int?
    private var emitEvent: ((_ target: Int, _ name: String, _ data: RufletValue) -> Void)?
  #endif

  public init() {}

  deinit {
    #if canImport(Network)
      monitor.cancel()
    #endif
  }

  public func activate(node: ControlNode, context: RufletServiceContext) {
    #if canImport(Network)
      if node.handlesEvent("change") {
        startMonitoring(node: node, context: context)
      } else {
        stopMonitoring()
      }
    #endif
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(Network)
      startMonitoring(node: node, context: context, emitsChanges: node?.handlesEvent("change") == true)
      switch call.name {
      case "get_connectivity":
        completion(.success(.array(current.map(RufletValue.string))))
      default:
        completion(
          .failure(
            RufletServiceError.unsupportedMethod(type: "Connectivity", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("Network framework unavailable")))
    #endif
  }

  #if canImport(Network)
    /// Starts on first use and pushes `change` the way Flet's connectivity
    /// service does, so a Ruby `on_change` handler fires without polling.
    private func startMonitoring(
      node: ControlNode?, context: RufletServiceContext, emitsChanges: Bool = true
    ) {
      let startsListener = emitsChanges && targetID == nil
      if emitsChanges, let node {
        targetID = node.id
        emitEvent = context.emitEvent
      }
      guard !monitoring else {
        if startsListener, let targetID, let emitEvent {
          emitEvent(targetID, "change", FletDeviceServiceSemantics.connectivityEvent(current))
        }
        return
      }
      monitoring = true
      monitor.pathUpdateHandler = { [weak self] path in
        let values = Self.describe(path)
        Task { @MainActor in
          guard let self, values != self.current else { return }
          self.current = values
          guard let targetID = self.targetID, let emitEvent = self.emitEvent else { return }
          emitEvent(targetID, "change", FletDeviceServiceSemantics.connectivityEvent(values))
        }
      }
      monitor.start(queue: DispatchQueue(label: "com.izeesoft.ruflet.connectivity"))
      current = Self.describe(monitor.currentPath)
      if startsListener, let targetID, let emitEvent {
        emitEvent(targetID, "change", FletDeviceServiceSemantics.connectivityEvent(current))
      }
    }

    private func stopMonitoring() {
      guard monitoring else { return }
      monitor.cancel()
      // NWPathMonitor instances cannot be restarted after cancellation.
      monitor = NWPathMonitor()
      monitoring = false
      targetID = nil
      emitEvent = nil
    }

    private nonisolated static func describe(_ path: NWPath) -> [String] {
      FletDeviceServiceSemantics.connectivityNames(
        wifi: path.usesInterfaceType(.wifi),
        mobile: path.usesInterfaceType(.cellular),
        ethernet: path.usesInterfaceType(.wiredEthernet),
        other: path.usesInterfaceType(.other),
        satellite: {
          if #available(iOS 26.0, macOS 26.0, *) { return path.isUltraConstrained }
          return false
        }(),
        satisfied: path.status == .satisfied)
    }
  #endif
}

/// `ScreenBrightness` — the display's brightness.
///
/// iOS exposes only the system brightness, which `UIScreen` both reads and
/// writes; the application-level distinction Flet draws is honoured by keeping
/// the value this service last set.
@MainActor
public final class ScreenBrightnessService: RufletStreamingService {
  public static let wireType = "ScreenBrightness"

  private var applicationBrightness: Double?
  private var systemBrightnessAtStart: Double?
  private var animate = true
  private var autoReset = true
  private var eventNode: ControlNode?
  private var eventContext: RufletServiceContext?
  private var brightnessObserver: NSObjectProtocol?

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    let listensForSystem = node.handlesEvent("system_screen_brightness_change")
    let listensForApplication = node.handlesEvent("application_screen_brightness_change")
    guard listensForSystem || listensForApplication else {
      eventNode = nil
      eventContext = nil
      stopBrightnessObservation()
      return
    }
    eventNode = node
    eventContext = context
    #if os(iOS)
      guard listensForSystem else {
        stopBrightnessObservation()
        return
      }
      guard brightnessObserver == nil else {
        return
      }
      brightnessObserver = NotificationCenter.default.addObserver(
        forName: UIScreen.brightnessDidChangeNotification,
        object: UIScreen.main,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.emitSystemBrightness() }
      }
    #endif
  }

  deinit {
    if let brightnessObserver { NotificationCenter.default.removeObserver(brightnessObserver) }
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if os(iOS)
      switch call.name {
      case "can_change_system_screen_brightness":
        completion(.success(.bool(true)))
      case "get_system_screen_brightness":
        completion(.success(.double(Double(UIScreen.main.brightness))))
      case "get_application_screen_brightness":
        completion(
          .success(.double(applicationBrightness ?? Double(UIScreen.main.brightness))))
      case "set_application_screen_brightness", "set_system_screen_brightness":
        let value: Double
        do {
          value = try FletDeviceServiceSemantics.validatedBrightness(call.argument("value"))
        } catch {
          return completion(.failure(error))
        }
        if call.name == "set_application_screen_brightness" {
          if systemBrightnessAtStart == nil {
            systemBrightnessAtStart = Double(UIScreen.main.brightness)
          }
          applicationBrightness = value
          UIScreen.main.brightness = CGFloat(value)
          emitApplicationBrightness(value)
        } else {
          UIScreen.main.brightness = CGFloat(value)
          emitSystemBrightness(value)
        }
        completion(.success(.null))
      case "reset_application_screen_brightness":
        if let original = systemBrightnessAtStart {
          UIScreen.main.brightness = CGFloat(original)
        }
        applicationBrightness = nil
        emitApplicationBrightness(Double(UIScreen.main.brightness))
        completion(.success(.null))
      case "is_animate":
        completion(.success(.bool(animate)))
      case "set_animate":
        do {
          animate = try FletDeviceServiceSemantics.requiredBool(
            call.argument("value"), name: "value")
        } catch {
          return completion(.failure(error))
        }
        completion(.success(.null))
      case "is_auto_reset":
        completion(.success(.bool(autoReset)))
      case "set_auto_reset":
        do {
          autoReset = try FletDeviceServiceSemantics.requiredBool(
            call.argument("value"), name: "value")
        } catch {
          return completion(.failure(error))
        }
        completion(.success(.null))
      default:
        completion(
          .failure(
            RufletServiceError.unsupportedMethod(type: "ScreenBrightness", method: call.name)))
      }
    #else
      completion(
        .failure(
          RufletServiceError.unavailable("Screen brightness is not settable on this platform")))
    #endif
  }

  private func emitApplicationBrightness(_ value: Double) {
    guard let eventNode, eventNode.handlesEvent("application_screen_brightness_change"),
      let eventContext
    else { return }
    eventContext.emitEvent(eventNode.id, "application_screen_brightness_change", .map([
      "brightness": .double(value)
    ]))
  }

  private func stopBrightnessObservation() {
    if let brightnessObserver { NotificationCenter.default.removeObserver(brightnessObserver) }
    brightnessObserver = nil
  }

  private func emitSystemBrightness(_ value: Double? = nil) {
    guard let eventNode, eventNode.handlesEvent("system_screen_brightness_change"),
      let eventContext
    else { return }
    #if os(iOS)
      let brightness = value ?? Double(UIScreen.main.brightness)
      eventContext.emitEvent(eventNode.id, "system_screen_brightness_change", .map([
        "brightness": .double(brightness)
      ]))
    #endif
  }
}
