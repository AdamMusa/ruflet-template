import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class HapticFeedbackService: RufletInvokableService {
  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    #if os(iOS)
    switch name {
    case "heavy_impact": UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case "light_impact": UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case "medium_impact", "vibrate": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case "selection_click": UISelectionFeedbackGenerator().selectionChanged()
    default: throw RufletServiceError.unknownMethod(service: "HapticFeedback", method: name)
    }
    #elseif os(macOS)
    switch name {
    case "heavy_impact", "light_impact", "medium_impact", "vibrate", "selection_click":
      NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    default: throw RufletServiceError.unknownMethod(service: "HapticFeedback", method: name)
    }
    #endif
    return nil
  }
}

