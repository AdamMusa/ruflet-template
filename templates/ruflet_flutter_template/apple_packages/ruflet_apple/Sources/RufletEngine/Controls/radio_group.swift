import RufletProtocol
import SwiftUI

private struct RufletRadioGroupBindingKey: EnvironmentKey {
    static let defaultValue: Binding<String?>? = nil
}

extension EnvironmentValues {
    var rufletRadioGroupBinding: Binding<String?>? {
        get { self[RufletRadioGroupBindingKey.self] }
        set { self[RufletRadioGroupBindingKey.self] = newValue }
    }
}

@MainActor
public struct RadioGroupControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    @ViewBuilder
    public var body: some View {
        // `@ViewBuilder` instead of returning `AnyView`: type erasure defeats
        // SwiftUI's structural diffing, so an erased subtree is re-evaluated
        // wholesale on every update instead of being compared in place.
        if let content = control.buildWidget("content") {
            content.environment(\.rufletRadioGroupBinding, selection)
        } else {
            ErrorControl("RadioGroup.content must be provided and visible")
        }
    }

    private var selection: Binding<String?> {
        Binding(
            get: { control.string("value") },
            set: { value in
                guard !control.disabled else { return }
                let wireValue = value.map(RufletValue.string) ?? .null
                control.updateProperties(["value": wireValue], notify: true)
                control.triggerEvent("change", data: wireValue)
            }
        )
    }
}
