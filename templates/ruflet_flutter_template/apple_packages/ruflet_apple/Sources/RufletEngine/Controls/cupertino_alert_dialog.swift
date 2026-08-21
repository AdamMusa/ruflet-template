import SwiftUI

/// Apple-native port of pinned `cupertino_alert_dialog.dart`.
@MainActor
public struct CupertinoAlertDialogControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleDialogPresenter(control: control)
  }
}
