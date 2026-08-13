import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#endif

@MainActor
public final class ScreenBrightnessService: RufletInvokableService {
  private var systemObserver: NSObjectProtocol?
  private var applicationObserver: NSObjectProtocol?
  private var originalBrightness: Double?
  private var animate = true
  private var autoReset = true

  public override func initialize() {
    super.initialize()
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
    if name == "can_change_system_screen_brightness" { return .bool(false) }
    throw RufletServiceError.unavailable("Screen brightness is unavailable on macOS")
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
  }

  public override func dispose() {
    #if os(iOS)
    if autoReset, let originalBrightness { UIScreen.main.brightness = CGFloat(originalBrightness) }
    if let systemObserver { NotificationCenter.default.removeObserver(systemObserver) }
    if let applicationObserver { NotificationCenter.default.removeObserver(applicationObserver) }
    self.systemObserver = nil
    self.applicationObserver = nil
    #endif
    super.dispose()
  }
}

