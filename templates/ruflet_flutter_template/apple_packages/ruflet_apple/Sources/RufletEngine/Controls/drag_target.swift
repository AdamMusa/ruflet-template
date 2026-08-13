import SwiftUI

/// Apple-native port of Flet's `DragTargetControl`.
@MainActor
public struct DragTargetControl: View {
    @ObservedObject public var control: RufletControl

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        if let content = control.buildWidget("content") {
            content.modifier(RufletDragTargetRegistration(
                control: control,
                group: control.string("group", default: "default")!
            ))
        } else {
            ErrorControl("DragTarget.content must be visible")
        }
    }
}
