import SwiftUI

@MainActor
public struct SafeAreaControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        guard let content = control.buildWidget("content") else {
            preconditionFailure("SafeArea.content must be provided and visible")
        }
        return AnyView(LayoutControl(control: control) {
            content
                .padding(parseEdgeInsets(control.dynamicValue("minimum_padding")) ?? EdgeInsets())
                .ignoresSafeArea(edges: ignoredEdges)
        })
    }

    private var ignoredEdges: Edge.Set {
        var edges: Edge.Set = []
        if !control.boolean("avoid_intrusions_left", default: true) { edges.insert(.leading) }
        if !control.boolean("avoid_intrusions_top", default: true) { edges.insert(.top) }
        if !control.boolean("avoid_intrusions_right", default: true) { edges.insert(.trailing) }
        if !control.boolean("avoid_intrusions_bottom", default: true) { edges.insert(.bottom) }
        return edges
    }
}
