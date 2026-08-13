import SwiftUI

enum RufletScrollMode: String, CaseIterable, RufletStringEnum {
    case none, auto, adaptive, always, hidden
}

@MainActor
struct ScrollableControl<Content: View>: View {
    @ObservedObject var control: RufletControl
    let child: Content
    let scrollDirection: Axis.Set
    let wrapIntoScrollableView: Bool

    init(
        control: RufletControl,
        scrollDirection: Axis.Set,
        wrapIntoScrollableView: Bool = false,
        @ViewBuilder child: () -> Content
    ) {
        self.control = control
        self.scrollDirection = scrollDirection
        self.wrapIntoScrollableView = wrapIntoScrollableView
        self.child = child()
    }

    @ViewBuilder
    var body: some View {
        let mode = parseEnum(RufletScrollMode.self, control.string("scroll"), RufletScrollMode.none)!
        if mode == .none || !wrapIntoScrollableView {
            child
        } else {
            ScrollView(scrollDirection, showsIndicators: mode != .hidden) {
                child
            }
        }
    }
}
