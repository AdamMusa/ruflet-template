import RufletProtocol
import SwiftUI

@MainActor
public struct SliderControl: View {
    @ObservedObject public var control: RufletControl
    @FocusState private var focused: Bool
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            Slider(
                value: value,
                in: minimum...maximum,
                step: step,
                onEditingChanged: editingChanged
            )
            .tint(parseColor(control.string("active_color")))
            .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
            .disabled(control.disabled)
            .focused($focused)
            .accessibilityLabel(resolvedLabel)
            .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
        }
    }

    private var minimum: Double { control.number("min") ?? 0 }
    private var maximum: Double { control.number("max") ?? 1 }
    private var step: Double {
        guard let divisions = control.integer("divisions"), divisions > 0 else { return (maximum - minimum) / 1000 }
        return (maximum - minimum) / Double(divisions)
    }

    private var value: Binding<Double> {
        Binding(
            get: { min(max(control.number("value") ?? minimum, minimum), maximum) },
            set: { value in
                control.updateProperties(["value": .double(value)], notify: true)
                control.triggerEvent("change", data: .double(value))
            }
        )
    }

    private var resolvedLabel: String {
        let precision = control.integer("round", default: 0) ?? 0
        return control.string("label")?.replacingOccurrences(
            of: "{value}",
            with: String(format: "%.*f", precision, value.wrappedValue)
        ) ?? ""
    }

    private func editingChanged(_ editing: Bool) {
        control.triggerEvent(editing ? "change_start" : "change_end", data: .double(value.wrappedValue))
    }
}
