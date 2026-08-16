import SwiftUI

func rufletUsesCupertinoPresentation(adaptive: Bool?, isIOS: Bool) -> Bool {
    adaptive ?? isIOS
}

@MainActor
private func rufletUsesCupertinoPresentation(_ control: RufletControl) -> Bool {
    #if os(iOS)
    rufletUsesCupertinoPresentation(adaptive: control.adaptive, isIOS: true)
    #else
    rufletUsesCupertinoPresentation(adaptive: control.adaptive, isIOS: false)
    #endif
}

@MainActor
public struct AdaptiveButtonControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View {
        if rufletUsesCupertinoPresentation(control) {
            if ["AlertDialog", "CupertinoAlertDialog"].contains(control.parent?.type) {
                CupertinoDialogActionControl(control: control)
            } else {
                CupertinoButtonControl(control: control)
            }
        } else {
            ButtonControl(control: control)
        }
    }
}
