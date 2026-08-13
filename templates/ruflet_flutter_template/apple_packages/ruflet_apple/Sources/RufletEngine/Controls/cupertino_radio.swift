import SwiftUI

@MainActor
public struct CupertinoRadioControl: View {
    @ObservedObject public var control: RufletControl
    @Environment(\.rufletRadioGroupBinding) private var groupSelection
    @FocusState private var focused: Bool
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        guard groupSelection != nil else { preconditionFailure("CupertinoRadio must be enclosed within RadioGroup") }
        return AnyView(LayoutControl(control: control) {
            Button(action: select) {
                HStack(spacing: 6) {
                    if labelPosition == .left { label }
                    ZStack {
                        Circle().stroke(parseColor(control.string("inactive_color")) ?? .secondary, lineWidth: 1.5)
                        if selected {
                            if control.boolean("use_checkmark_style", default: false) {
                                Image(systemName: "checkmark").font(.caption.bold())
                            } else {
                                Circle().fill(parseColor(control.string("active_color")) ?? .accentColor).padding(4)
                            }
                        }
                    }.frame(width: 18, height: 18)
                    if labelPosition == .right { label }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(control.disabled).focused($focused)
            .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
        })
    }

    private var selected: Bool { groupSelection?.wrappedValue == control.string("value", default: "")! }
    private var labelPosition: RufletLabelPosition { parseEnum(RufletLabelPosition.self, control.string("label_position"), .right)! }
    @ViewBuilder private var label: some View { if let value = control.string("label"), !value.isEmpty { Text(value) } }
    private func select() {
        guard let groupSelection else { return }
        rufletActivateRadio(
            selection: groupSelection,
            selected: selected,
            toggleable: control.boolean("toggleable", default: false),
            value: control.string("value", default: "")!)
    }
}
