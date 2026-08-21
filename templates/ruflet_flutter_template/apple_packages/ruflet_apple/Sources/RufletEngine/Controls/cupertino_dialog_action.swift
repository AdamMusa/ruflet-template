import SwiftUI

@MainActor
public struct CupertinoDialogActionControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View {
        guard let content = control.buildTextOrWidget("content") else {
            return AnyView(
                ErrorControl("CupertinoDialogAction.content must be a string or visible Control"))
        }
        return AnyView(BaseControl(control: control) {
            Button(action: { control.triggerEvent("click") }) {
                content
                    .environment(\.rufletInheritsTextColor, true)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
                .buttonStyle(.plain)
                .font(
                    .system(
                        size: 17,
                        weight: control.boolean("default", default: false) ? .semibold : .regular))
                .foregroundStyle(control.boolean("destructive", default: false) ? .red : .accentColor)
                .tint(control.boolean("destructive", default: false) ? .red : .accentColor)
                .modifier(
                    RufletTextStyleModifier(
                        style: parseTextStyle(control.dynamicValue("text_style"))))
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(control.disabled)
        })
    }
}
