import RufletProtocol
import SwiftUI

@MainActor
public struct SwitchControl: View {
    @ObservedObject public var control: RufletControl
    @FocusState private var focused: Bool
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            HStack(spacing: 6) {
                if labelPosition == .left { label }
                Toggle("", isOn: binding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(parseColor(control.string("active_color")) ?? parseColor(control.string("active_track_color")))
                    .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
                    .disabled(control.disabled)
                    .focused($focused)
                if labelPosition == .right { label }
            }
            .contentShape(Rectangle())
            .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
        }
        .modifier(RufletListTileInputToggleModifier {
            guard !control.disabled else { return }
            binding.wrappedValue = !binding.wrappedValue
        })
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { control.boolean("value", default: false) },
            set: { value in
                control.updateProperties(["value": .bool(value)], notify: true)
                control.triggerEvent("change", data: .bool(value))
            }
        )
    }

    private var labelPosition: RufletLabelPosition { parseEnum(RufletLabelPosition.self, control.string("label_position"), .right)! }

    @ViewBuilder
    private var label: some View {
        if let label = control.buildTextOrWidget("label") {
            label.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_text_style"))))
        }
    }
}
