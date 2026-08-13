#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

@MainActor
func performRufletSelectionFeedback() {
  #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  #elseif canImport(AppKit)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
  #endif
}
