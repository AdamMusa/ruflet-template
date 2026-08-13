import SwiftUI

/// Apple-native port of Flet's `ReorderableDragHandleControl`.
@MainActor
public struct ReorderableDragHandleControl: View {
    @ObservedObject public var control: RufletControl
    @Environment(\.reorderableItemIndex) private var index
    @Environment(\.rufletReorderItemActions) private var actions

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        if let index, let actions, let content = control.buildWidget("content") {
            if control.disabled {
                content
            } else {
                content
                    .onDrag { actions.beginDragging(index) }
                    .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor")))
            }
        } else if index == nil || actions == nil {
            ErrorControl("ReorderableDragHandle must be placed inside ReorderableListView.")
        } else {
            ErrorControl("ReorderableDragHandle.content must be set and visible")
        }
    }
}
