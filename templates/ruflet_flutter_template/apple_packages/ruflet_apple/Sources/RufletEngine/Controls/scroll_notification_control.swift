import RufletProtocol
import SwiftUI

@MainActor
struct ScrollNotificationControl<Content: View>: View {
    @ObservedObject var control: RufletControl
    let child: Content
    @State private var lastDispatch = ContinuousClock.now
    @State private var lastOffset = CGPoint.zero
    @State private var started = false
    @State private var endTask: Task<Void, Never>?

    init(control: RufletControl, @ViewBuilder child: () -> Content) {
        self.control = control
        self.child = child()
    }

    var body: some View {
        child
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: RufletScrollOffsetKey.self,
                        value: proxy.frame(in: .named("ruflet_scroll_\(control.id)")).origin
                    )
                }
            }
            .coordinateSpace(name: "ruflet_scroll_\(control.id)")
            .onPreferenceChange(RufletScrollOffsetKey.self, perform: offsetChanged)
            .onDisappear { endTask?.cancel() }
    }

    private func offsetChanged(_ origin: CGPoint) {
        let offset = CGPoint(x: -origin.x, y: -origin.y)
        guard offset != lastOffset else { return }
        if !started {
            started = true
            dispatch(type: "start", offset: offset, delta: nil)
        }
        let delta = CGPoint(x: offset.x - lastOffset.x, y: offset.y - lastOffset.y)
        let interval = Duration.milliseconds(control.integer("scroll_interval", default: 10) ?? 10)
        if lastDispatch.duration(to: .now) >= interval {
            dispatch(type: "update", offset: offset, delta: delta)
        }
        lastOffset = offset
        endTask?.cancel()
        endTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            dispatch(type: "end", offset: offset, delta: nil)
            started = false
        }
    }

    private func dispatch(type: String, offset: CGPoint, delta: CGPoint?) {
        lastDispatch = .now
        var data: [String: RufletValue] = [
            "event_type": .string(type),
            "pixels": .double(abs(offset.x) > abs(offset.y) ? offset.x : offset.y),
            "min_scroll_extent": .double(0),
            "max_scroll_extent": .double(0),
            "viewport_dimension": .double(0),
        ]
        if let delta {
            data["scroll_delta"] = .double(abs(delta.x) > abs(delta.y) ? delta.x : delta.y)
        }
        control.triggerEvent("scroll", data: .map(data))
    }
}

private struct RufletScrollOffsetKey: PreferenceKey {
    static let defaultValue = CGPoint.zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { value = nextValue() }
}
