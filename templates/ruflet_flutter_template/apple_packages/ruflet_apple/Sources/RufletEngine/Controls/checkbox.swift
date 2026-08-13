import RufletProtocol
import SwiftUI

@MainActor
public struct CheckboxControl: View {
    @ObservedObject public var control: RufletControl
    @FocusState private var focused: Bool

    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            HStack(spacing: 6) {
                if labelPosition == .left { label }
                Button(action: toggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(fillColor)
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(borderColor, lineWidth: 1.5)
                        if value == true {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(parseColor(control.string("check_color")) ?? .white)
                        } else if value == nil {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(parseColor(control.string("check_color")) ?? .white)
                        }
                    }
                    .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(control.disabled)
                .focused($focused)
                .accessibilityLabel(control.string("semantics_label") ?? control.string("label") ?? "")
                .accessibilityValue(value.map(String.init) ?? "mixed")
                if labelPosition == .right { label }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !control.disabled { toggle() } }
            .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
        }
        .modifier(RufletListTileInputToggleModifier {
            if !control.disabled { toggle() }
        })
    }

    private var value: Bool? {
        if control.value("value")?.isNull == true, control.boolean("tristate", default: false) { return nil }
        return control.boolean("value", default: false)
    }

    private var labelPosition: RufletLabelPosition {
        parseEnum(RufletLabelPosition.self, control.string("label_position"), .right)!
    }

    @ViewBuilder
    private var label: some View {
        if let label = control.buildTextOrWidget("label") {
            label.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_style"))))
        }
    }

    private var fillColor: Color {
        if value != false {
            return parseColor(control.string("active_color"))
                ?? parseColor(control.string("fill_color"))
                ?? .accentColor
        }
        return parseColor(control.string("fill_color")) ?? .clear
    }

    private var borderColor: Color {
        if control.boolean("error", default: false) { return .red }
        return value != false ? fillColor : .secondary
    }

    private func toggle() {
        let next: RufletValue
        if !control.boolean("tristate", default: false) {
            next = .bool(!(value ?? false))
        } else if value == nil {
            next = .bool(false)
        } else if value == false {
            next = .bool(true)
        } else {
            next = .null
        }
        control.updateProperties(["value": next], notify: true)
        control.triggerEvent("change", data: next)
    }
}
