import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#endif

@MainActor
public final class WakelockService: RufletInvokableService {
  #if os(macOS)
  private var activity: NSObjectProtocol?
  #endif

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "enable": setEnabled(true); return nil
    case "disable": setEnabled(false); return nil
    case "is_enabled": return .bool(isEnabled)
    default: throw RufletServiceError.unknownMethod(service: "Wakelock", method: name)
    }
  }

  private var isEnabled: Bool {
    #if os(iOS)
    return UIApplication.shared.isIdleTimerDisabled
    #elseif os(macOS)
    return activity != nil
    #endif
  }

  private func setEnabled(_ enabled: Bool) {
    #if os(iOS)
    UIApplication.shared.isIdleTimerDisabled = enabled
    #elseif os(macOS)
    if enabled, activity == nil {
      activity = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .idleSystemSleepDisabled], reason: "Ruflet Wakelock")
    } else if !enabled, let activity {
      ProcessInfo.processInfo.endActivity(activity)
      self.activity = nil
    }
    #endif
  }

  public override func dispose() {
    setEnabled(false)
    super.dispose()
  }
}
