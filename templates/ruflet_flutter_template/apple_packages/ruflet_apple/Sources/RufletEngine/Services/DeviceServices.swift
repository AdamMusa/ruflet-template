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

/// `Battery` — level, charging state and low-power mode.
@MainActor
public final class BatteryService: RufletStreamingService {
  public static let wireType = "Battery"
  private var stateObserver: NSObjectProtocol?
  private var targetID: Int?
  private var emitEvent: ((_ target: Int, _ name: String, _ data: RufletValue) -> Void)?

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    guard node.handlesEvent("state_change") else { return }
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
      }
    #endif
  }

  deinit {
    if let stateObserver { NotificationCenter.default.removeObserver(stateObserver) }
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
        completion(.success(level < 0 ? .null : .int(Int64((level * 100).rounded()))))
      #elseif canImport(IOKit)
        completion(.success(Self.macBatteryPercentage().map { RufletValue.int(Int64($0)) } ?? .null))
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
      emitEvent(targetID, "state_change", .map(["state": .string(Self.stateName(UIDevice.current.batteryState))]))
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
    private static func macBatteryPercentage() -> Int? {
      guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
      else { return nil }

      for source in sources {
        guard
          let description = IOPSGetPowerSourceDescription(snapshot, source)?
            .takeUnretainedValue() as? [String: Any],
          let current = description[kIOPSCurrentCapacityKey] as? Int,
          let maximum = description[kIOPSMaxCapacityKey] as? Int,
          maximum > 0
        else { continue }
        return Int((Double(current) / Double(maximum) * 100).rounded())
      }
      return nil
    }
  #endif
}

/// `Connectivity` — the current link type, plus `change` events as it moves.
@MainActor
public final class ConnectivityService: RufletStreamingService {
  public static let wireType = "Connectivity"

  #if canImport(Network)
    private let monitor = NWPathMonitor()
    private var monitoring = false
    private var current = "none"
  #endif

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    #if canImport(Network)
      startMonitoring(node: node, context: context)
    #endif
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(Network)
      startMonitoring(node: node, context: context)
      switch call.name {
      case "get_connectivity":
        completion(.success(.array([.string(current)])))
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
    private func startMonitoring(node: ControlNode?, context: RufletServiceContext) {
      guard !monitoring, let node else { return }
      monitoring = true
      let id = node.id
      monitor.pathUpdateHandler = { [weak self] path in
        let kind = Self.describe(path)
        Task { @MainActor in
          guard let self, kind != self.current else { return }
          self.current = kind
          context.emitEvent(id, "change", .map([
            "connectivity": .array([.string(kind)])
          ]))
        }
      }
      monitor.start(queue: DispatchQueue(label: "com.izeesoft.ruflet.connectivity"))
    }

    private nonisolated static func describe(_ path: NWPath) -> String {
      guard path.status == .satisfied else { return "none" }
      if path.usesInterfaceType(.wifi) { return "wifi" }
      if path.usesInterfaceType(.cellular) { return "mobile" }
      if path.usesInterfaceType(.wiredEthernet) { return "ethernet" }
      if path.usesInterfaceType(.other) { return "vpn" }
      return "other"
    }
  #endif
}

/// `PermissionHandler` — the permissions Apple platforms actually gate.
///
/// The gated ones live behind optional modules, so this asks whatever is
/// linked through `RufletPermissions`. Anything nothing can answer reports
/// "granted", which is the truth for a permission the OS does not gate.
@MainActor
public final class PermissionHandlerService: RufletService {
  public static let wireType = "PermissionHandler"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    let permission = call.argument("permission")?.stringValue?.lowercased() ?? ""

    switch call.name {
    // `PermissionHandlerControl#get_status` and `#request` name the methods on
    // the wire; the Flet spellings are accepted too so a control built by hand
    // still works.
    case "get_status", "check_permission":
      completion(.success(.string(RufletPermissions.status(of: permission))))

    case "request", "request_permission":
      RufletPermissions.request(permission) { status in
        completion(.success(.string(status)))
      }

    case "open_app_settings":
      #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
          return completion(.success(.bool(true)))
        }
      #elseif canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
          NSWorkspace.shared.open(url)
          return completion(.success(.bool(true)))
        }
      #endif
      completion(.success(.bool(false)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "PermissionHandler", method: call.name)))
    }
  }
}

/// `ScreenBrightness` — the display's brightness.
///
/// iOS exposes only the system brightness, which `UIScreen` both reads and
/// writes; the application-level distinction Flet draws is honoured by keeping
/// the value this service last set.
@MainActor
public final class ScreenBrightnessService: RufletService {
  public static let wireType = "ScreenBrightness"

  private var applicationBrightness: Double?
  private var systemBrightnessAtStart: Double?
  private var animate = true
  private var autoReset = true

  public init() {}

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
        guard let value = call.argument("value")?.doubleValue else {
          return completion(.failure(RufletServiceError.invalidArguments("value is required")))
        }
        if systemBrightnessAtStart == nil {
          systemBrightnessAtStart = Double(UIScreen.main.brightness)
        }
        applicationBrightness = value
        UIScreen.main.brightness = CGFloat(min(max(value, 0), 1))
        completion(.success(.null))
      case "reset_application_screen_brightness":
        if let original = systemBrightnessAtStart {
          UIScreen.main.brightness = CGFloat(original)
        }
        applicationBrightness = nil
        completion(.success(.null))
      case "is_animate":
        completion(.success(.bool(animate)))
      case "set_animate":
        animate = call.argument("value")?.boolValue ?? true
        completion(.success(.null))
      case "is_auto_reset":
        completion(.success(.bool(autoReset)))
      case "set_auto_reset":
        autoReset = call.argument("value")?.boolValue ?? true
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
}
