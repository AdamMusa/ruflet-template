import RufletProtocol
import SwiftUI

@MainActor
public struct RangeSliderControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            RufletRangeSlider(
                start: start,
                end: end,
                range: minimum...maximum,
                step: step,
                tint: parseColor(control.string("active_color")) ?? .accentColor,
                disabled: control.disabled,
                onEditingChanged: editingChanged
            )
        }
    }

    private var minimum: Double { control.number("min") ?? 0 }
    private var maximum: Double { control.number("max") ?? 1 }
    private var step: Double {
        guard let divisions = control.integer("divisions"), divisions > 0 else { return (maximum - minimum) / 1000 }
        return (maximum - minimum) / Double(divisions)
    }
    private var start: Binding<Double> { binding("start_value", upper: { end.wrappedValue }) }
    private var end: Binding<Double> { binding("end_value", lower: { start.wrappedValue }) }

    private func binding(
        _ property: String,
        lower: @escaping () -> Double = { -.infinity },
        upper: @escaping () -> Double = { .infinity }
    ) -> Binding<Double> {
        Binding(
            get: { control.number(property) ?? 0 },
            set: { value in
                let clamped = min(max(value, max(minimum, lower())), min(maximum, upper()))
                let startValue = property == "start_value" ? clamped : (control.number("start_value") ?? 0)
                let endValue = property == "end_value" ? clamped : (control.number("end_value") ?? 0)
                control.updateProperties(["start_value": .double(startValue), "end_value": .double(endValue)], notify: true)
                control.triggerEvent("change")
            }
        )
    }

    private func editingChanged(_ editing: Bool) {
        control.triggerEvent(editing ? "change_start" : "change_end")
    }
}

private struct RufletRangeSlider: View {
    @Binding var start: Double
    @Binding var end: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    let disabled: Bool
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width - 20, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.25)).frame(height: 4)
                Capsule().fill(tint).frame(width: max(endX(width) - startX(width), 0), height: 4).offset(x: startX(width))
                thumb(value: $start, width: width, limits: range.lowerBound...end)
                thumb(value: $end, width: width, limits: start...range.upperBound)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 30)
        .disabled(disabled)
    }

    private func thumb(value: Binding<Double>, width: Double, limits: ClosedRange<Double>) -> some View {
        Circle()
            .fill(tint)
            .frame(width: 20, height: 20)
            .offset(x: position(value.wrappedValue, width: width))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    onEditingChanged(true)
                    let raw = range.lowerBound + (range.upperBound - range.lowerBound) * drag.location.x / width
                    let snapped = (raw / step).rounded() * step
                    value.wrappedValue = min(max(snapped, limits.lowerBound), limits.upperBound)
                }
                .onEnded { _ in onEditingChanged(false) })
    }

    private func position(_ value: Double, width: Double) -> Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound) * width
    }
    private func startX(_ width: Double) -> Double { position(start, width: width) }
    private func endX(_ width: Double) -> Double { position(end, width: width) }
}
