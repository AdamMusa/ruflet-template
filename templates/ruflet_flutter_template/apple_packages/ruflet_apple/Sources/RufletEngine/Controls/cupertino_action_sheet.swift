import SwiftUI

/// Apple-native port of pinned `cupertino_action_sheet.dart`.
@MainActor
public struct CupertinoActionSheetControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      VStack(spacing: 8) {
        VStack(spacing: 6) {
          if let title = control.buildTextOrWidget("title") {
            title.font(.headline).padding(.top, 16)
          }
          if let message = control.buildTextOrWidget("message") {
            message.font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 12)
          }
          ForEach(control.children("actions")) { action in
            Divider()
            ControlWidget(control: action)
          }
        }
        .frame(maxWidth: .infinity)
        .background(Color.rufletSystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))

        if let cancel = control.buildWidget("cancel") {
          cancel
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.rufletSystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
      }
      .padding(8)
    }
  }
}
