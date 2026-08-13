import SwiftUI

/// Apple-native port of pinned `cupertino_context_menu_action.dart`.
@MainActor
public struct CupertinoContextMenuActionControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if let content = control.buildTextOrWidget("content") {
      Button(role: control.boolean("destructive", default: false) ? .destructive : nil) {
        if !control.disabled { control.triggerEvent("click") }
      } label: {
        HStack(spacing: 8) {
          content
            .font(control.boolean("default", default: false) ? .body.weight(.semibold) : .body)
            .lineLimit(1)
          Spacer(minLength: 8)
          if let icon = control.buildIconOrWidget("trailing_icon") { icon }
        }
      }
      .disabled(control.disabled)
    } else {
      ErrorControl("content (string or visible Control) must be provided")
    }
  }
}
