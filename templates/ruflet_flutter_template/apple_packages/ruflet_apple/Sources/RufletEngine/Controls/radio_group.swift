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

    public var body: some View {
        guard let content = control.buildWidget("content") else {
            preconditionFailure("RadioGroup.content must be provided and visible")
        }
        return AnyView(content.environment(\.rufletRadioGroupBinding, selection))
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
