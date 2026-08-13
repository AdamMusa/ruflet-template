import SwiftUI

@MainActor
public struct CupertinoSwitchControl: View {
    @ObservedObject public var control: RufletControl
    @FocusState private var focused: Bool
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            HStack(spacing: 6) {
                if labelPosition == .left { label }
                Toggle("", isOn: binding)
                    .labelsHidden().toggleStyle(.switch)
                    .tint(parseColor(control.string("active_track_color")) ?? .accentColor)
                    .disabled(control.disabled).focused($focused)
                if labelPosition == .right { label }
            }
            .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
        }
        .modifier(RufletListTileInputToggleModifier {
            guard !control.disabled else { return }
            binding.wrappedValue = !binding.wrappedValue
        })
    }
    private var binding: Binding<Bool> {
        Binding(get: { control.boolean("value", default: false) }, set: {
            control.updateProperties(["value": .bool($0)], notify: true)
            control.triggerEvent("change")
        })
    }
    private var labelPosition: RufletLabelPosition { parseEnum(RufletLabelPosition.self, control.string("label_position"), .right)! }
    @ViewBuilder private var label: some View { if let label = control.string("label"), !label.isEmpty { Text(label) } }
}
