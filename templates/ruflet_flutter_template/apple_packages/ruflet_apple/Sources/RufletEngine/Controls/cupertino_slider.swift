import RufletProtocol
import SwiftUI

@MainActor
public struct CupertinoSliderControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            Slider(value: value, in: minimum...maximum, step: step, onEditingChanged: editingChanged)
                .tint(parseColor(control.string("active_color")))
                .disabled(control.disabled)
        }
    }
    private var minimum: Double { control.number("min") ?? 0 }
    private var maximum: Double { control.number("max") ?? 1 }
    private var step: Double {
        guard let divisions = control.integer("divisions"), divisions > 0 else { return (maximum - minimum) / 1000 }
        return (maximum - minimum) / Double(divisions)
    }
    private var value: Binding<Double> {
        Binding(get: { min(max(control.number("value") ?? minimum, minimum), maximum) }, set: {
            control.updateProperties(["value": .double($0)], notify: true)
            control.triggerEvent("change")
        })
    }
    private func editingChanged(_ editing: Bool) {
        control.triggerEvent(editing ? "change_start" : "change_end", data: .double(value.wrappedValue))
    }
}
