import SwiftUI

/// Apple-native port of Flet's `DraggableControl`.
@MainActor
public struct DraggableControl: View {
    @ObservedObject public var control: RufletControl
    @State private var dragging = false
    @State private var translation = CGSize.zero

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        if let content = control.buildWidget("content") {
            ZStack(alignment: .topLeading) {
                if dragging, let replacement = control.buildWidget("content_when_dragging") {
                    replacement
                } else {
                    content.modifier(RufletMouseCursorModifier(cursor: "grab"))
                }

                if dragging {
                    feedback(content)
                        .offset(translation)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
        } else {
            ErrorControl("Draggable.content must be visible")
        }
    }

    private func feedback(_ content: AnyView) -> some View {
        Group {
            if let feedback = control.buildWidget("content_feedback") {
                feedback
            } else {
                content.opacity(0.5)
            }
        }
        .modifier(RufletMouseCursorModifier(cursor: "grabbing"))
    }

    private var dragGesture: some Gesture {
        DragGesture(
            minimumDistance: control.disabled || maximumDrags == 0 ? .greatestFiniteMagnitude : 10,
            coordinateSpace: .global
        )
        .onChanged { value in
            guard affinityAllows(value.translation) else { return }
            if !dragging {
                dragging = true
                RufletDragSession.shared.begin(source: control, group: group)
            }
            translation = constrained(value.translation)
            RufletDragSession.shared.move(to: value.location)
        }
        .onEnded { value in
            _ = RufletDragSession.shared.end(at: value.location)
            dragging = false
            translation = .zero
        }
    }

    private func constrained(_ value: CGSize) -> CGSize {
        switch control.string("axis")?.lowercased() {
        case "horizontal": CGSize(width: value.width, height: 0)
        case "vertical": CGSize(width: 0, height: value.height)
        default: value
        }
    }

    /// Flutter's affinity selects the axis that wins gesture-arena
    /// arbitration. Start a native drag only after movement favors it.
    private func affinityAllows(_ value: CGSize) -> Bool {
        switch control.string("affinity")?.lowercased() {
        case "horizontal": abs(value.width) >= abs(value.height)
        case "vertical": abs(value.height) >= abs(value.width)
        default: true
        }
    }

    private var group: String { control.string("group", default: "default")! }
    private var maximumDrags: Int? { control.integer("max_simultaneous_drags") }
}
