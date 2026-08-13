import SwiftUI

@MainActor
public struct AdaptiveButtonControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View {
        if control.adaptive == true {
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
