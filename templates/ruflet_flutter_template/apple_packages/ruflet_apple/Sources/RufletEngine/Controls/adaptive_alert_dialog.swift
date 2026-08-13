import SwiftUI

/// Apple-only port of pinned `adaptive_alert_dialog.dart`.
@MainActor
public struct AdaptiveAlertDialogControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if control.adaptive == true {
      CupertinoAlertDialogControl(control: control)
    } else {
      AlertDialogControl(control: control)
    }
  }
}
