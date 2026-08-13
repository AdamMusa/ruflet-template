import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class SemanticsServiceControl: RufletInvokableService {
  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "announce_message", "announce_tooltip":
      guard let message = arguments["message"]?.text else {
        throw RufletServiceError.missingArgument("message")
      }
      #if os(iOS)
      UIAccessibility.post(notification: .announcement, argument: message)
      #elseif os(macOS)
      NSAccessibility.post(
        element: NSApp as Any,
        notification: .announcementRequested,
        userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
      #endif
      return nil
    case "get_accessibility_features": return accessibilityFeatures
    default: throw RufletServiceError.unknownMethod(service: "SemanticsService", method: name)
    }
  }

  private var accessibilityFeatures: RufletValue {
    #if os(iOS)
    return [
      "accessible_navigation": .bool(UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning),
      "bold_text": .bool(UIAccessibility.isBoldTextEnabled),
      "disable_animations": .bool(UIAccessibility.isReduceMotionEnabled),
      "high_contrast": .bool(UIAccessibility.isDarkerSystemColorsEnabled),
      "invert_colors": .bool(UIAccessibility.isInvertColorsEnabled),
      "reduce_motion": .bool(UIAccessibility.isReduceMotionEnabled),
      "on_off_switch_labels": .bool(UIAccessibility.shouldDifferentiateWithoutColor),
      "supports_announcements": .bool(true),
    ]
    #elseif os(macOS)
    let workspace = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    return [
      "accessible_navigation": .bool(NSWorkspace.shared.isVoiceOverEnabled),
      "bold_text": .bool(false),
      "disable_animations": .bool(workspace),
      "high_contrast": .bool(NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast),
      "invert_colors": .bool(NSWorkspace.shared.accessibilityDisplayShouldInvertColors),
      "reduce_motion": .bool(workspace),
      "on_off_switch_labels": .bool(NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor),
      "supports_announcements": .bool(true),
    ]
    #endif
  }
}

