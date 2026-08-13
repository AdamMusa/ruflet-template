import SwiftUI

@MainActor
public struct CupertinoDialogActionControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View {
        guard let content = control.buildTextOrWidget("content") else {
            preconditionFailure("CupertinoDialogAction.content must be a string or visible Control")
        }
        return AnyView(BaseControl(control: control) {
            Button(action: { control.triggerEvent("click") }) { content }
                .buttonStyle(.borderless)
                .font(.body.weight(control.boolean("default", default: false) ? .bold : .regular))
                .foregroundStyle(control.boolean("destructive", default: false) ? .red : .accentColor)
                .disabled(control.disabled)
        })
    }
}
