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
            Button(action: select) {
                HStack(spacing: 6) {
                    if labelPosition == .left { label }
                    ZStack {
                        Circle().stroke(parseColor(control.string("fill_color")) ?? .secondary, lineWidth: 1.5)
                        if selected {
                            Circle()
                                .fill(parseColor(control.string("active_color")) ?? parseColor(control.string("fill_color")) ?? .accentColor)
                                .padding(4)
                        }
                    }
                    .frame(width: 18, height: 18)
                    if labelPosition == .right { label }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(control.disabled)
            .focused($focused)
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
        rufletActivateRadio(
            selection: groupSelection,
            selected: selected,
            toggleable: control.boolean("toggleable", default: false),
            value: control.string("value", default: "")!)
    }
}

func rufletNextRadioSelection(selected: Bool, toggleable: Bool, value: String) -> String? {
    selected && toggleable ? nil : value
}

@MainActor
func rufletActivateRadio(
    selection: Binding<String?>,
    selected: Bool,
    toggleable: Bool,
    value: String
) {
    selection.wrappedValue = rufletNextRadioSelection(
        selected: selected,
        toggleable: toggleable,
        value: value)
}
