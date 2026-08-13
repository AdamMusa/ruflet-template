import SwiftUI

@MainActor
public struct RadioControl: View {
    @ObservedObject public var control: RufletControl
    @Environment(\.rufletRadioGroupBinding) private var groupSelection
    @FocusState private var focused: Bool

    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        guard groupSelection != nil else {
            preconditionFailure("Radio must be enclosed within RadioGroup")
        }
        return AnyView(LayoutControl(control: control) {
            HStack(spacing: 6) {
                if labelPosition == .left { label }
                Button(action: select) {
                    ZStack {
                        Circle().stroke(parseColor(control.string("fill_color")) ?? .secondary, lineWidth: 1.5)
                        if selected {
                            Circle()
                                .fill(parseColor(control.string("active_color")) ?? parseColor(control.string("fill_color")) ?? .accentColor)
                                .padding(4)
                        }
                    }
                    .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(control.disabled)
                .focused($focused)
                if labelPosition == .right { label }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !control.disabled { select() } }
            .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
        }
        .modifier(RufletListTileInputToggleModifier {
            if !control.disabled { select() }
        }))
    }

    private var selected: Bool { groupSelection?.wrappedValue == control.string("value", default: "")! }
    private var labelPosition: RufletLabelPosition { parseEnum(RufletLabelPosition.self, control.string("label_position"), .right)! }

    @ViewBuilder
    private var label: some View {
        if let label = control.string("label"), !label.isEmpty {
            Text(label).modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_style"))))
        }
    }

    private func select() {
        guard let groupSelection else { return }
        if selected, control.boolean("toggleable", default: false) {
            groupSelection.wrappedValue = nil
        } else {
            groupSelection.wrappedValue = control.string("value", default: "")!
        }
    }
}
