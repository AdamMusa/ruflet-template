import SwiftUI

@MainActor
public struct SelectionAreaControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        guard let content = control.buildWidget("content") else {
            preconditionFailure("SelectionArea.content must be provided and visible")
        }
        return AnyView(BaseControl(control: control) {
            content.textSelection(.enabled)
        })
    }
}
