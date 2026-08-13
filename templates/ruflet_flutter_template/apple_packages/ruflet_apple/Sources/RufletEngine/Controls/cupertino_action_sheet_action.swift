import SwiftUI

/// Apple-native port of pinned `cupertino_action_sheet_action.dart`.
@MainActor
public struct CupertinoActionSheetActionControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      Button {
        if !control.disabled { control.triggerEvent("click") }
      } label: {
        if let content = control.buildTextOrWidget("content") {
          content
            .font(.body.weight(control.boolean("default", default: false) ? .semibold : .regular))
            .foregroundStyle(control.boolean("destructive", default: false) ? .red : .accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
      }
      .buttonStyle(.plain)
      .disabled(control.disabled)
    }
  }
}
