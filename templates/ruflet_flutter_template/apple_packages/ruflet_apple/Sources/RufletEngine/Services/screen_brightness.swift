import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import IOKit.graphics
#endif

@MainActor
public final class ScreenBrightnessService: RufletInvokableService {
  private var systemObserver: NSObjectProtocol?
  private var applicationObserver: NSObjectProtocol?
  private var originalBrightness: Double?
  private var animate = true
  private var autoReset = true
  #if os(macOS)
  private var cachedSystemBrightness: Double?
  private var applicationBrightness: Double?
  private var pollTimer: Timer?
  #endif

  public override func initialize() {
    super.initialize()
    #if os(macOS)
    cachedSystemBrightness = try? displayBrightness()
    #endif
    updateListeners()
  }

  public override func update() { updateListeners() }

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    #if os(iOS)
    switch name {
    case "get_system_screen_brightness": return .double(Double(UIScreen.main.brightness))
    case "can_change_system_screen_brightness": return .bool(true)
    case "set_system_screen_brightness", "set_application_screen_brightness":
      guard let brightness = arguments["value"]?.number else {
        throw RufletServiceError.missingArgument("value")
      }
      if originalBrightness == nil { originalBrightness = Double(UIScreen.main.brightness) }
      setBrightness(brightness)
      return nil
    case "get_application_screen_brightness": return .double(Double(UIScreen.main.brightness))
    case "reset_application_screen_brightness":
      if let originalBrightness { setBrightness(originalBrightness) }
      originalBrightness = nil
      return nil
    case "is_animate": return .bool(animate)
    case "set_animate":
      guard let value = arguments["value"]?.bool else { throw RufletServiceError.missingArgument("value") }
      animate = value
      return nil
    case "is_auto_reset": return .bool(autoReset)
    case "set_auto_reset":
      guard let value = arguments["value"]?.bool else { throw RufletServiceError.missingArgument("value") }
      autoReset = value
      return nil
    default: throw RufletServiceError.unknownMethod(service: "ScreenBrightness", method: name)
    }
    #elseif os(macOS)
    switch name {
    case "get_system_screen_brightness":
      let brightness = try displayBrightness()
      cachedSystemBrightness = applicationBrightness == nil ? brightness : cachedSystemBrightness
      return .double(cachedSystemBrightness ?? brightness)
    case "can_change_system_screen_brightness":
      // screen_brightness_macos reports this capability unconditionally. Keep
      // the native port wire-compatible even on displays whose IOKit driver
      // accepts the request without returning a readable brightness value.
      return .bool(true)
    case "set_system_screen_brightness":
      let brightness = try brightnessArgument(arguments)
      cachedSystemBrightness = brightness
      if applicationBrightness == nil { try setDisplayBrightness(brightness) }
      emit("system_screen_brightness_change", brightness: brightness)
      if applicationBrightness == nil {
        emit("application_screen_brightness_change", brightness: brightness)
      }
      return nil
    case "get_application_screen_brightness":
      return .double(try displayBrightness())
    case "set_application_screen_brightness":
      let brightness = try brightnessArgument(arguments)
      if cachedSystemBrightness == nil { cachedSystemBrightness = try displayBrightness() }
      applicationBrightness = brightness
      try setDisplayBrightness(brightness)
      emit("application_screen_brightness_change", brightness: brightness)
      return nil
    case "reset_application_screen_brightness":
      guard let brightness = cachedSystemBrightness else { return nil }
      try setDisplayBrightness(brightness)
      applicationBrightness = nil
      emit("application_screen_brightness_change", brightness: brightness)
      return nil
    case "is_animate": return .bool(animate)
    case "set_animate":
      guard let value = arguments["value"]?.bool else {
        throw RufletServiceError.missingArgument("value")
      }
      animate = value
      return nil
    case "is_auto_reset": return .bool(autoReset)
    case "set_auto_reset":
      guard let value = arguments["value"]?.bool else {
        throw RufletServiceError.missingArgument("value")
      }
      autoReset = value
      return nil
    default: throw RufletServiceError.unknownMethod(service: "ScreenBrightness", method: name)
    }
    #endif
  }

  #if os(iOS)
  private func setBrightness(_ value: Double) {
    let bounded = CGFloat(min(max(value, 0), 1))
    if animate {
      UIView.animate(withDuration: 0.25) { UIScreen.main.brightness = bounded }
    } else {
      UIScreen.main.brightness = bounded
    }
  }
  #endif

  private func updateListeners() {
    #if os(iOS)
    let center = NotificationCenter.default
    if control.hasEventHandler("system_screen_brightness_change"), systemObserver == nil {
      systemObserver = center.addObserver(
        forName: UIScreen.brightnessDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.control.triggerEvent("system_screen_brightness_change", data: [
            "brightness": .double(Double(UIScreen.main.brightness))
          ])
        }
      }
    } else if !control.hasEventHandler("system_screen_brightness_change"), let systemObserver {
      center.removeObserver(systemObserver)
      self.systemObserver = nil
    }
    if control.hasEventHandler("application_screen_brightness_change"), applicationObserver == nil {
      applicationObserver = center.addObserver(
        forName: UIScreen.brightnessDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.control.triggerEvent("application_screen_brightness_change", data: [
            "brightness": .double(Double(UIScreen.main.brightness))
          ])
        }
      }
    } else if !control.hasEventHandler("application_screen_brightness_change"), let applicationObserver {
      center.removeObserver(applicationObserver)
      self.applicationObserver = nil
    }
    #endif
    #if os(macOS)
    let shouldPoll = control.hasEventHandler("system_screen_brightness_change")
      || control.hasEventHandler("application_screen_brightness_change")
    if shouldPoll, pollTimer == nil {
      pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.pollBrightness() }
      }
    } else if !shouldPoll {
      pollTimer?.invalidate()
      pollTimer = nil
    }
    #endif
  }

  public override func dispose() {
    #if os(iOS)
    if autoReset, let originalBrightness { UIScreen.main.brightness = CGFloat(originalBrightness) }
    if let systemObserver { NotificationCenter.default.removeObserver(systemObserver) }
    if let applicationObserver { NotificationCenter.default.removeObserver(applicationObserver) }
    self.systemObserver = nil
    self.applicationObserver = nil
    #elseif os(macOS)
    pollTimer?.invalidate()
    pollTimer = nil
    if autoReset, let cachedSystemBrightness, applicationBrightness != nil {
      try? setDisplayBrightness(cachedSystemBrightness)
    }
    applicationBrightness = nil
    #endif
    super.dispose()
  }

  #if os(macOS)
  private func brightnessArgument(_ arguments: [String: RufletValue]) throws -> Double {
    guard let value = arguments["value"]?.number else {
      throw RufletServiceError.missingArgument("value")
    }
    return min(max(value, 0), 1)
  }

  private func displayServices() throws -> [io_service_t] {
    var iterator: io_iterator_t = 0
    let port: mach_port_t
    if #available(macOS 12, *) { port = kIOMainPortDefault } else { port = kIOMasterPortDefault }
    guard IOServiceGetMatchingServices(port, IOServiceMatching("IODisplayConnect"), &iterator)
      == kIOReturnSuccess
    else { throw RufletServiceError.unavailable("Display brightness service") }
    defer { IOObjectRelease(iterator) }
    var result: [io_service_t] = []
    while true {
      let service = IOIteratorNext(iterator)
      guard service != 0 else { break }
      result.append(service)
    }
    // The Flutter plugin treats a successful IOKit query with no matching
    // display objects as a readable zero brightness, not as a service error.
    // Preserve that observable result on Apple Silicon/external displays.
    return result
  }

  private func displayBrightness() throws -> Double {
    let services = try displayServices()
    defer { services.forEach { _ = IOObjectRelease($0) } }
    var value: Float = 0
    for service in services {
      // This deliberately mirrors screen_brightness_macos: the plugin returns
      // the value supplied by IOKit (zero when a display does not expose the
      // parameter) and does not turn the IOReturn into a protocol error.
      IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &value)
    }
    return Double(value)
  }

  private func setDisplayBrightness(_ brightness: Double) throws {
    let services = try displayServices()
    defer { services.forEach { _ = IOObjectRelease($0) } }
    for service in services {
      IODisplaySetFloatParameter(
        service, 0, kIODisplayBrightnessKey as CFString, Float(brightness))
    }
  }

  private func pollBrightness() {
    guard let value = try? displayBrightness() else { return }
    if applicationBrightness == nil, value != cachedSystemBrightness {
      cachedSystemBrightness = value
      emit("system_screen_brightness_change", brightness: value)
      emit("application_screen_brightness_change", brightness: value)
    } else if let applicationBrightness, value != applicationBrightness {
      self.applicationBrightness = value
      emit("application_screen_brightness_change", brightness: value)
    }
  }

  private func emit(_ name: String, brightness: Double) {
    guard control.hasEventHandler(name) else { return }
    control.triggerEvent(name, data: ["brightness": .double(brightness)])
  }
  #endif
}
