import SwiftUI

func rufletUsesCupertinoPresentation(adaptive: Bool?, isIOS: Bool) -> Bool {
    adaptive ?? isIOS
}

@MainActor
public struct AdaptiveButtonControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View {
        if control.adaptive == true || rufletUsesAppleDialogAction(
            parentType: control.parent?.type,
            isIOS: rufletIsIOS)
        {
            if rufletUsesAppleDialogAction(parentType: control.parent?.type, isIOS: rufletIsIOS) {
                CupertinoDialogActionControl(control: control)
            } else {
                CupertinoButtonControl(control: control)
            }
        } else {
            ButtonControl(control: control)
        }
    }
}

func rufletUsesAppleDialogAction(parentType: String?, isIOS: Bool) -> Bool {
    isIOS && ["AdaptiveAlertDialog", "AlertDialog", "CupertinoAlertDialog"].contains(parentType)
}
