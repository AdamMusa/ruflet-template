import SwiftUI

#if os(iOS)
  import UIKit
#endif

/// Apple-native port of pinned `cupertino_context_menu.dart`.
@MainActor
public struct CupertinoContextMenuControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if control.children("actions").isEmpty {
      ErrorControl("at least one action in CupertinoContextMenu.actions must be visible")
    } else if let content = control.buildWidget("content") {
      content
        .contextMenu {
          ForEach(control.children("actions")) { action in
            ControlWidget(control: action)
          }
        }
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 0.5).onEnded { _ in hapticFeedback() })
    } else {
      ErrorControl("CupertinoContextMenu.content must be visible")
    }
  }

  private func hapticFeedback() {
    guard control.boolean("enable_haptic_feedback", default: false) else { return }
    #if os(iOS)
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    #endif
  }
}
